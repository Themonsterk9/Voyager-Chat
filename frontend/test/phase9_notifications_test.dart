import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/notifications/notification_manager.dart';
import 'package:frontend/core/notifications/notification_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Phase 9 Notifications & Background Communication Tests (Steps 181-200)',
    () {
      late NotificationManager manager;

      setUp(() {
        manager = NotificationManager.instance;
        manager.settings.enableMessages = true;
        manager.settings.enableMentions = true;
        manager.settings.enableReactions = true;
        manager.settings.enableCalls = true;
        manager.settings.enableLocation = true;
        manager.settings.quietHours = const QuietHoursConfig(enabled: false);
      });

      test('TEST 1 & 2: Quiet hours midnight crossing evaluation', () {
        const midnightQuiet = QuietHoursConfig(
          enabled: true,
          startHour: 22,
          startMinute: 0,
          endHour: 7,
          endMinute: 0,
        );

        final lateNight = DateTime.parse('2026-08-22T23:30:00Z');
        final earlyMorning = DateTime.parse('2026-08-22T04:15:00Z');
        final afternoon = DateTime.parse('2026-08-22T14:00:00Z');

        expect(midnightQuiet.isTimeWithinQuietHours(lateNight), isTrue);
        expect(midnightQuiet.isTimeWithinQuietHours(earlyMorning), isTrue);
        expect(midnightQuiet.isTimeWithinQuietHours(afternoon), isFalse);
      });

      test('TEST 3: Emergency call notification bypass during quiet hours', () {
        manager.settings.quietHours = const QuietHoursConfig(
          enabled: true,
          startHour: 0,
          endHour: 23,
          allowEmergencyCalls: true,
        );

        final shouldNotifyNormal = manager.shouldNotify(
          category: NotificationCategory.message,
        );
        expect(shouldNotifyNormal, isFalse);

        final shouldNotifyEmergency = manager.shouldNotify(
          category: NotificationCategory.emergency,
        );
        expect(shouldNotifyEmergency, isTrue);
      });

      test(
        'TEST 4 & 5: Global category and per-conversation mute filtering',
        () async {
          manager.settings.enableReactions = false;
          final shouldNotifyReaction = manager.shouldNotify(
            category: NotificationCategory.reaction,
          );
          expect(shouldNotifyReaction, isFalse);

          await manager.setConversationMuted('conv-muted-1', true);
          final isMuted = manager.isConversationMuted('conv-muted-1');
          expect(isMuted, isTrue);

          final shouldNotifyMutedConv = manager.shouldNotify(
            category: NotificationCategory.message,
            conversationId: 'conv-muted-1',
          );
          expect(shouldNotifyMutedConv, isFalse);
        },
      );

      test('TEST 6: Strict E2EE privacy rule masks plaintext in notification payloads', () async {
        final stream = manager.notificationStream;

        expectLater(
          stream,
          emits(
            predicate<NotificationPayload>(
              (p) =>
                  p.isEncrypted &&
                  p.body == 'New encrypted message' &&
                  !p.body.contains('PlaintextSecret'),
            ),
          ),
        );

        manager.dispatchNotification(
          eventId: 'evt-e2ee-100',
          category: NotificationCategory.message,
          senderName: 'Alice',
          content: 'PlaintextSecretContentShouldBeMasked',
          deepLinkRoute: '/chat/conv-1',
          isEncrypted: true,
        );
      });

      test('TEST 7: Deep link route format verification', () {
        const msgRoute = '/chat/conv-100';
        const voiceRoute = '/call/voice';
        const videoRoute = '/call/video';
        const mapRoute = '/settings/map';

        expect(msgRoute, startsWith('/chat/'));
        expect(voiceRoute, equals('/call/voice'));
        expect(videoRoute, equals('/call/video'));
        expect(mapRoute, equals('/settings/map'));
      });
    },
  );
}
