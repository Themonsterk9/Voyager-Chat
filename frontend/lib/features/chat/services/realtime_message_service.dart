import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/socket_client.dart';
import '../models/message.dart';
import '../repositories/local_chat_repository.dart';

enum RealtimeEventType { insert, update, delete }

class RealtimeMessageEvent {
  const RealtimeMessageEvent({
    required this.type,
    required this.message,
    this.oldRecord,
  });

  final RealtimeEventType type;
  final Message message;
  final Map<String, dynamic>? oldRecord;
}

class RealtimeMessageService {
  RealtimeMessageService._();

  static final RealtimeMessageService instance = RealtimeMessageService._();

  SupabaseClient get _client => Supabase.instance.client;
  final LocalChatRepository _localRepo = LocalChatRepository.instance;

  final Map<String, RealtimeChannel> _activeChannels = {};
  final Map<String, List<void Function(RealtimeMessageEvent)>> _listeners = {};

  void startConversationSubscription(
    String conversationId, {
    required void Function(RealtimeMessageEvent event) onEvent,
  }) {
    if (_listeners.containsKey(conversationId)) {
      if (!_listeners[conversationId]!.contains(onEvent)) {
        _listeners[conversationId]!.add(onEvent);
      }
      return;
    }

    _listeners[conversationId] = [onEvent];

    // 1. Subscribe via Socket.IO
    SocketClient.instance.subscribeToMessages(conversationId, (data) async {
      try {
        final message = Message.fromMap(data);
        if (message.conversationId == conversationId) {
          await _localRepo.saveMessage(message);
          _notifyListeners(
            conversationId,
            RealtimeMessageEvent(
              type: RealtimeEventType.insert,
              message: message,
            ),
          );
        }
      } catch (_) {}
    });

    // 2. Subscribe via Supabase Realtime
    final channelName = 'public:messages:conversation_id=eq.$conversationId';
    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            await _handlePostgresPayload(conversationId, payload);
          },
        )
        .subscribe();

    _activeChannels[conversationId] = channel;
  }

  Future<void> _handlePostgresPayload(
    String conversationId,
    PostgresChangePayload payload,
  ) async {
    final eventType = payload.eventType;

    if (eventType == PostgresChangeEvent.insert) {
      final record = payload.newRecord;
      if (record.isEmpty) return;

      final message = Message.fromMap(record);
      if (message.conversationId != conversationId) return;

      await _localRepo.saveMessage(message);
      _notifyListeners(
        conversationId,
        RealtimeMessageEvent(type: RealtimeEventType.insert, message: message),
      );
    } else if (eventType == PostgresChangeEvent.update) {
      final record = payload.newRecord;
      if (record.isEmpty) return;

      final message = Message.fromMap(record);
      if (message.conversationId != conversationId) return;

      await _localRepo.saveMessage(message);
      _notifyListeners(
        conversationId,
        RealtimeMessageEvent(
          type: RealtimeEventType.update,
          message: message,
          oldRecord: payload.oldRecord,
        ),
      );
    } else if (eventType == PostgresChangeEvent.delete) {
      final oldRecord = payload.oldRecord;
      final messageId = oldRecord['id']?.toString() ?? '';

      final dummyDeletedMessage = Message(
        id: messageId,
        conversationId: conversationId,
        senderId: '',
        content: null,
        deletedAt: DateTime.now().toUtc(),
      );

      _notifyListeners(
        conversationId,
        RealtimeMessageEvent(
          type: RealtimeEventType.delete,
          message: dummyDeletedMessage,
          oldRecord: oldRecord,
        ),
      );
    }
  }

  void _notifyListeners(String conversationId, RealtimeMessageEvent event) {
    final list = _listeners[conversationId];
    if (list != null) {
      for (final listener in List.of(list)) {
        listener(event);
      }
    }
  }

  void stopConversationSubscription(
    String conversationId, {
    void Function(RealtimeMessageEvent event)? onEvent,
  }) {
    if (onEvent != null && _listeners.containsKey(conversationId)) {
      _listeners[conversationId]!.remove(onEvent);
      if (_listeners[conversationId]!.isNotEmpty) {
        return;
      }
    }

    _listeners.remove(conversationId);

    final channel = _activeChannels.remove(conversationId);
    if (channel != null) {
      _client.removeChannel(channel);
    }
  }

  void dispose() {
    for (final channel in _activeChannels.values) {
      _client.removeChannel(channel);
    }
    _activeChannels.clear();
    _listeners.clear();
  }
}
