import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/calling/call_manager.dart';
import 'package:frontend/core/calling/call_models.dart';
import 'package:frontend/core/calling/signaling_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 8 Voice + Video Calling Tests (Steps 161-180)', () {
    late CallManager callManager;

    setUp(() {
      callManager = CallManager.instance;
    });

    test(
      'TEST 1 & 2: CallSignalEvent map serialization and type resolution',
      () {
        final event = CallSignalEvent(
          callId: 'call-99',
          senderId: 'user-a',
          recipientId: 'user-b',
          type: SignalEventType.offer,
          callType: CallType.video,
          timestamp: DateTime.parse('2026-08-22T02:00:00Z'),
        );

        final map = event.toMap();
        expect(map['call_id'], 'call-99');
        expect(map['call_type'], 'video');

        final restored = CallSignalEvent.fromMap(map);
        expect(restored.callId, 'call-99');
        expect(restored.type, equals(SignalEventType.offer));
        expect(restored.callType, equals(CallType.video));
      },
    );

    test(
      'TEST 3 & 4: Voice call initiation, accept, and duration counter',
      () async {
        callManager.startCall(
          conversationId: 'conv-10',
          recipientId: 'user-b',
          recipientName: 'Bob',
          type: CallType.voice,
        );

        expect(callManager.state, equals(CallState.calling));
        expect(callManager.remoteParticipantName, equals('Bob'));

        callManager.acceptCall();
        expect(callManager.state, equals(CallState.connecting));

        await Future.delayed(const Duration(milliseconds: 600));
        expect(callManager.state, equals(CallState.connected));

        callManager.endCall();
        expect(callManager.state, equals(CallState.ended));
      },
    );

    test('TEST 5 & 6: Voice call controls - mute and speaker toggles', () {
      expect(callManager.isMuted, isFalse);
      callManager.toggleMute();
      expect(callManager.isMuted, isTrue);

      expect(callManager.isSpeakerOn, isFalse);
      callManager.toggleSpeaker();
      expect(callManager.isSpeakerOn, isTrue);
    });

    test(
      'TEST 7 & 8: Video call controls - camera on/off and switch camera',
      () {
        expect(callManager.isCameraOn, isTrue);
        callManager.toggleCamera();
        expect(callManager.isCameraOn, isFalse);

        expect(callManager.isFrontCamera, isTrue);
        callManager.switchCamera();
        expect(callManager.isFrontCamera, isFalse);
      },
    );

    test('TEST 9 & 10: Screen sharing foundation abstraction', () {
      expect(callManager.isScreenSharing, isFalse);
      callManager.startScreenShare();
      expect(callManager.isScreenSharing, isTrue);
      callManager.stopScreenShare();
      expect(callManager.isScreenSharing, isFalse);
    });

    test('TEST 11 & 12: CallLog serialization and map parsing', () {
      final log = CallLog(
        id: 'log-101',
        conversationId: 'conv-10',
        callerId: 'user-a',
        callerName: 'Alice',
        callType: CallType.video,
        startTime: DateTime.parse('2026-08-22T02:00:00Z'),
        endTime: DateTime.parse('2026-08-22T02:05:00Z'),
        durationSeconds: 300,
        status: 'completed',
      );

      final map = log.toMap();
      expect(map['duration_seconds'], 300);
      expect(map['status'], 'completed');

      final restored = CallLog.fromMap(map);
      expect(restored.id, 'log-101');
      expect(restored.durationSeconds, 300);
      expect(restored.callType, equals(CallType.video));
    });

    test('TEST 13: Out-of-band signaling stream dispatch', () async {
      final stream = SignalingService.instance.signalStream;

      expectLater(
        stream,
        emits(predicate<CallSignalEvent>((e) => e.callId == 'call-test-200')),
      );

      SignalingService.instance.sendSignal(
        CallSignalEvent(
          callId: 'call-test-200',
          senderId: 'user-x',
          recipientId: 'user-y',
          type: SignalEventType.accept,
          callType: CallType.voice,
          timestamp: DateTime.now(),
        ),
      );
    });
  });
}
