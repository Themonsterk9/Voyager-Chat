import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/models/message.dart';
import 'package:frontend/features/chat/services/realtime_message_service.dart';

void main() {
  group('RealtimeMessageEvent tests', () {
    test('creates RealtimeMessageEvent correctly for INSERT', () {
      final message = Message(
        id: 'msg-1',
        conversationId: 'conv-1',
        senderId: 'user-1',
        content: 'Realtime test',
      );

      final event = RealtimeMessageEvent(
        type: RealtimeEventType.insert,
        message: message,
      );

      expect(event.type, RealtimeEventType.insert);
      expect(event.message.id, 'msg-1');
      expect(event.message.content, 'Realtime test');
    });

    test('creates RealtimeMessageEvent correctly for UPDATE', () {
      final message = Message(
        id: 'msg-1',
        conversationId: 'conv-1',
        senderId: 'user-1',
        content: 'Updated content',
      );

      final event = RealtimeMessageEvent(
        type: RealtimeEventType.update,
        message: message,
        oldRecord: {'id': 'msg-1', 'content': 'Original content'},
      );

      expect(event.type, RealtimeEventType.update);
      expect(event.message.content, 'Updated content');
      expect(event.oldRecord?['content'], 'Original content');
    });

    test('creates RealtimeMessageEvent correctly for DELETE', () {
      final message = Message(
        id: 'msg-1',
        conversationId: 'conv-1',
        senderId: 'user-1',
      );

      final event = RealtimeMessageEvent(
        type: RealtimeEventType.delete,
        message: message,
      );

      expect(event.type, RealtimeEventType.delete);
      expect(event.message.id, 'msg-1');
    });
  });
}
