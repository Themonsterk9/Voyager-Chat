import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../auth/services/auth_service.dart';
import 'api_client.dart';

class SocketClient {
  SocketClient._();

  static final SocketClient instance = SocketClient._();

  io.Socket? _socket;
  bool _isConnected = false;
  String? _currentUserId;

  final Map<String, List<void Function(Map<String, dynamic>)>>
  _messageListeners = {};
  final Map<String, List<void Function(Map<String, dynamic>)>>
  _typingListeners = {};

  bool get isConnected => _isConnected;

  void init() {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      connect(user.id);
    }
  }

  void connect(String userId) {
    if (_socket != null && _currentUserId == userId && _socket!.connected) {
      return;
    }

    _currentUserId = userId;
    final serverUrl = ApiClient.baseUrl;

    if (_socket != null) {
      _socket!.dispose();
    }

    try {
      _socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(2000)
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        if (kDebugMode) {
          print('Socket.IO connected to $serverUrl');
        }
        _socket!.emit('authenticate', {'userId': userId});

        // Rejoin active conversation rooms if any
        for (final conversationId in _messageListeners.keys) {
          _socket!.emit('join_conversation', {
            'conversationId': conversationId,
            'userId': userId,
          });
        }
      });

      _socket!.onDisconnect((reason) {
        _isConnected = false;
        if (kDebugMode) {
          print('Socket.IO disconnected: $reason');
        }
      });

      _socket!.onConnectError((err) {
        _isConnected = false;
        if (kDebugMode) {
          print('Socket.IO connect error: $err');
        }
      });

      _socket!.on('new_message', (data) {
        if (data is Map<String, dynamic>) {
          _handleIncomingMessage(data);
        } else if (data is Map) {
          _handleIncomingMessage(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('user_typing', (data) {
        if (data is Map) {
          _handleTypingEvent(Map<String, dynamic>.from(data), isTyping: true);
        }
      });

      _socket!.on('user_stop_typing', (data) {
        if (data is Map) {
          _handleTypingEvent(Map<String, dynamic>.from(data), isTyping: false);
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Socket.IO init exception: $e');
      }
    }
  }

  void joinConversation(String conversationId) {
    final user = AuthService.instance.currentUser;
    final userId = user?.id ?? _currentUserId;

    if (userId != null && (_socket == null || !_socket!.connected)) {
      connect(userId);
    }

    if (_socket != null && _socket!.connected) {
      _socket!.emit('join_conversation', {
        'conversationId': conversationId,
        'userId': userId,
      });
    }
  }

  void leaveConversation(String conversationId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leave_conversation', {'conversationId': conversationId});
    }
  }

  void subscribeToMessages(
    String conversationId,
    void Function(Map<String, dynamic>) onMessage,
  ) {
    if (!_messageListeners.containsKey(conversationId)) {
      _messageListeners[conversationId] = [];
    }
    if (!_messageListeners[conversationId]!.contains(onMessage)) {
      _messageListeners[conversationId]!.add(onMessage);
    }
    joinConversation(conversationId);
  }

  void unsubscribeFromMessages(
    String conversationId,
    void Function(Map<String, dynamic>) onMessage,
  ) {
    if (_messageListeners.containsKey(conversationId)) {
      _messageListeners[conversationId]!.remove(onMessage);
      if (_messageListeners[conversationId]!.isEmpty) {
        _messageListeners.remove(conversationId);
        leaveConversation(conversationId);
      }
    }
  }

  Future<Map<String, dynamic>?> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String messageType = 'text',
    String? clientMessageId,
    String? replyToMessageId,
  }) async {
    final completer = Completer<Map<String, dynamic>?>();

    if (_socket == null || !_socket!.connected) {
      connect(senderId);
    }

    if (_socket != null && _socket!.connected) {
      _socket!.emitWithAck(
        'send_message',
        {
          'conversationId': conversationId,
          'senderId': senderId,
          'content': content,
          'messageType': messageType,
          'clientMessageId': clientMessageId,
          'replyToMessageId': replyToMessageId,
        },
        ack: (response) {
          if (response is Map && response['status'] == 'success') {
            final msg = response['message'];
            if (msg is Map<String, dynamic>) {
              completer.complete(msg);
            } else if (msg is Map) {
              completer.complete(Map<String, dynamic>.from(msg));
            } else {
              completer.complete(null);
            }
          } else {
            completer.complete(null);
          }
        },
      );

      // Add timeout fallback to avoid hanging if ack isn't received
      Timer(const Duration(seconds: 4), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });
    } else {
      completer.complete(null);
    }

    return completer.future;
  }

  void sendTypingStatus(String conversationId, bool isTyping) {
    if (_socket != null && _socket!.connected) {
      final user = AuthService.instance.currentUser;
      final event = isTyping ? 'typing_start' : 'typing_stop';
      _socket!.emit(event, {
        'conversationId': conversationId,
        'userId': user?.id,
        'displayName': user?.displayName,
      });
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final conversationId = data['conversation_id'] ?? data['conversationId'];
    if (conversationId != null &&
        _messageListeners.containsKey(conversationId)) {
      for (final listener in List.of(_messageListeners[conversationId]!)) {
        listener(data);
      }
    }
  }

  void _handleTypingEvent(
    Map<String, dynamic> data, {
    required bool isTyping,
  }) {
    final conversationId = data['conversationId'] ?? data['conversation_id'];
    if (conversationId != null &&
        _typingListeners.containsKey(conversationId)) {
      for (final listener in List.of(_typingListeners[conversationId]!)) {
        listener(data);
      }
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _currentUserId = null;
  }
}
