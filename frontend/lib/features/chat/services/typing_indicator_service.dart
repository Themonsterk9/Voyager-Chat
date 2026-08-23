import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/services/auth_service.dart';

class TypingIndicatorService {
  TypingIndicatorService._();

  static final TypingIndicatorService instance = TypingIndicatorService._();

  SupabaseClient get _client => Supabase.instance.client;

  final Map<String, RealtimeChannel> _typingChannels = {};
  final Map<String, List<void Function(String userId, bool isTyping)>>
  _listeners = {};
  final Map<String, Timer> _typingDebouncers = {};

  void subscribeToTyping(
    String conversationId, {
    required void Function(String userId, bool isTyping) onTypingChanged,
  }) {
    if (_listeners.containsKey(conversationId)) {
      if (!_listeners[conversationId]!.contains(onTypingChanged)) {
        _listeners[conversationId]!.add(onTypingChanged);
      }
      return;
    }

    _listeners[conversationId] = [onTypingChanged];

    try {
      final channelName = 'typing:$conversationId';
      final channel = _client.channel(channelName);

      channel
          .onBroadcast(
            event: 'typing',
            callback: (payload) {
              final userId = payload['user_id']?.toString() ?? '';
              final isTyping = payload['is_typing'] == true;
              final currentUserId = AuthService.instance.currentUser?.id;

              if (userId.isNotEmpty && userId != currentUserId) {
                final list = _listeners[conversationId];
                if (list != null) {
                  for (final callback in List.of(list)) {
                    callback(userId, isTyping);
                  }
                }
              }
            },
          )
          .subscribe();

      _typingChannels[conversationId] = channel;
    } catch (_) {
      // Ignore initialization errors
    }
  }

  void sendTypingState(String conversationId, bool isTyping) {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    _typingDebouncers[conversationId]?.cancel();

    final channel = _typingChannels[conversationId];
    if (channel != null) {
      try {
        channel.sendBroadcastMessage(
          event: 'typing',
          payload: {'user_id': user.id, 'is_typing': isTyping},
        );
      } catch (_) {}
    }

    if (isTyping) {
      _typingDebouncers[conversationId] = Timer(const Duration(seconds: 3), () {
        sendTypingState(conversationId, false);
      });
    }
  }

  void unsubscribeFromTyping(
    String conversationId, {
    void Function(String userId, bool isTyping)? onTypingChanged,
  }) {
    if (onTypingChanged != null && _listeners.containsKey(conversationId)) {
      _listeners[conversationId]!.remove(onTypingChanged);
      if (_listeners[conversationId]!.isNotEmpty) {
        return;
      }
    }

    _listeners.remove(conversationId);
    _typingDebouncers.remove(conversationId)?.cancel();

    final channel = _typingChannels.remove(conversationId);
    if (channel != null) {
      try {
        _client.removeChannel(channel);
      } catch (_) {}
    }
  }
}
