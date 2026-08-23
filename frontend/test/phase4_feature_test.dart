import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/diagnostics_service.dart';
import 'package:frontend/core/services/rate_limiter_service.dart';
import 'package:frontend/features/chat/models/conversation.dart';
import 'package:frontend/features/chat/models/message.dart';
import 'package:frontend/features/chat/services/ai_assistant_service.dart';

void main() {
  group('Phase 4 Feature Tests (Steps 81-100)', () {
    test('Message handles scheduledAt', () {
      final scheduled = DateTime.now().add(const Duration(hours: 2));
      final msg = Message.fromMap({
        'id': 'msg-sched',
        'conversation_id': 'conv-1',
        'sender_id': 'user-1',
        'content': 'Scheduled message',
        'scheduled_at': scheduled.toIso8601String(),
      });

      expect(msg.scheduledAt, isNotNull);
      final map = msg.toMap();
      expect(map['scheduled_at'], isNotNull);
    });

    test('Conversation handles draftText', () {
      final conv = Conversation(
        id: 'conv-1',
        type: 'direct',
        draftText: 'Unsent draft text...',
      );

      expect(conv.draftText, 'Unsent draft text...');

      final updated = conv.copyWith(draftText: 'Updated draft');
      expect(updated.draftText, 'Updated draft');

      final cleared = conv.copyWith(clearDraftText: true);
      expect(cleared.draftText, isNull);
    });

    test(
      'RateLimiterService allows normal sending and blocks rapid bursts',
      () {
        final limiter = RateLimiterService.instance;
        bool canSend = true;

        for (int i = 0; i < 5; i++) {
          canSend = limiter.checkCanSendMessage();
          expect(canSend, isTrue);
        }

        final burstBlock = limiter.checkCanSendMessage();
        expect(burstBlock, isFalse);
      },
    );

    test('AiAssistantService generates smart replies and summaries', () {
      final ai = AiAssistantService.instance;

      final msg = Message(
        id: 'm1',
        conversationId: 'c1',
        senderId: 'u1',
        content: 'Hello, how are you?',
      );

      final replies = ai.generateSmartReplies(msg);
      expect(replies, isNotEmpty);

      final summary = ai.summarizeConversation([msg]);
      expect(summary, contains('Summary:'));
    });

    test('SystemDiagnostics formats export report correctly', () {
      const diag = SystemDiagnostics(
        conversationCount: 10,
        messageCount: 150,
        pendingMessageCount: 0,
        reactionCount: 25,
        isAuthenticated: true,
        currentUserEmail: 'test@voyager.com',
        dbVersion: 5,
      );

      final report = diag.exportReport();
      expect(report, contains('VOYAGER CHAT SYSTEM DIAGNOSTICS REPORT'));
      expect(report, contains('test@voyager.com'));
      expect(report, contains('SQLite DB Version     : 5'));
    });
  });
}
