import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/models/conversation.dart';
import 'package:frontend/features/chat/models/message.dart';
import 'package:frontend/features/chat/models/message_reaction.dart';
import 'package:frontend/features/chat/services/typing_indicator_service.dart';

void main() {
  group('Phase 2 Feature Tests (Steps 41-60)', () {
    test('MessageReaction creates from map and converts to map correctly', () {
      final reaction = MessageReaction.fromMap({
        'id': 'react-1',
        'message_id': 'msg-1',
        'user_id': 'user-1',
        'emoji': '👍',
        'created_at': '2026-08-22T10:00:00.000Z',
      });

      expect(reaction.id, 'react-1');
      expect(reaction.messageId, 'msg-1');
      expect(reaction.userId, 'user-1');
      expect(reaction.emoji, '👍');
      expect(reaction.createdAt, isNotNull);

      final map = reaction.toMap();
      expect(map['emoji'], '👍');
    });

    test('Message supports replyToMessageId', () {
      final message = Message.fromMap({
        'id': 'msg-2',
        'conversation_id': 'conv-1',
        'sender_id': 'user-1',
        'content': 'Replying to previous message',
        'message_type': 'text',
        'reply_to_message_id': 'msg-1',
      });

      expect(message.replyToMessageId, 'msg-1');

      final copy = message.copyWith(replyToMessageId: 'msg-0');
      expect(copy.replyToMessageId, 'msg-0');
    });

    test('Conversation handles pinnedAt and archivedAt', () {
      final now = DateTime.now().toUtc();
      final conv = Conversation(id: 'conv-1', type: 'direct', pinnedAt: now);

      expect(conv.pinnedAt, now);
      expect(conv.archivedAt, isNull);

      final archived = conv.copyWith(archivedAt: now, clearPinnedAt: true);
      expect(archived.pinnedAt, isNull);
      expect(archived.archivedAt, now);
    });

    test('TypingIndicatorService instance exists', () {
      final service = TypingIndicatorService.instance;
      expect(service, isNotNull);
    });
  });
}
