import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/chat/models/conversation.dart';
import 'package:frontend/features/chat/models/conversation_member.dart';
import 'package:frontend/features/chat/models/message.dart';

void main() {
  group('Conversation model', () {
    test('creates conversation from map', () {
      final conversation = Conversation.fromMap({
        'id': 'conversation-1',
        'type': 'direct',
        'name': 'Test Chat',
        'created_by': 'user-1',
        'created_at': '2026-08-17T10:00:00Z',
        'updated_at': '2026-08-17T10:00:00Z',
      });

      expect(conversation.id, 'conversation-1');
      expect(conversation.type, 'direct');
      expect(conversation.name, 'Test Chat');
      expect(conversation.createdBy, 'user-1');
    });
  });

  group('Message model', () {
    test('creates message from map', () {
      final message = Message.fromMap({
        'id': 'message-1',
        'conversation_id': 'conversation-1',
        'sender_id': 'user-1',
        'content': 'Hello Voyager',
        'message_type': 'text',
        'client_message_id': null,
        'created_at': '2026-08-17T10:00:00Z',
        'edited_at': null,
        'deleted_at': null,
      });

      expect(message.id, 'message-1');
      expect(message.conversationId, 'conversation-1');
      expect(message.senderId, 'user-1');
      expect(message.content, 'Hello Voyager');
      expect(message.messageType, 'text');
    });
  });

  group('ConversationMember model', () {
    test('creates member from map', () {
      final member = ConversationMember.fromMap({
        'conversation_id': 'conversation-1',
        'user_id': 'user-1',
        'joined_at': '2026-08-17T10:00:00Z',
        'last_read_at': null,
      });

      expect(member.conversationId, 'conversation-1');
      expect(member.userId, 'user-1');
      expect(member.joinedAt, isNotNull);
      expect(member.lastReadAt, isNull);
    });
  });
}
