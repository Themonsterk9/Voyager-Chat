import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/meetings/meeting_models.dart';
import 'package:frontend/core/meetings/meeting_service.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 15 Calls, Meetings & Real-Time Collaboration Tests (Steps 301-320)', () {
    late MeetingService meetingService;

    setUp(() {
      meetingService = MeetingService.instance;
    });

    test('TEST 1 & 2: MeetingRole and MeetingStatus enum parsing', () {
      expect(MeetingRole.host.name, equals('host'));
      expect(MeetingRole.coHost.name, equals('coHost'));
      expect(MeetingRole.participant.name, equals('participant'));

      expect(MeetingStatus.scheduled.name, equals('scheduled'));
      expect(MeetingStatus.waiting.name, equals('waiting'));
      expect(MeetingStatus.active.name, equals('active'));
    });

    test(
      'TEST 3 & 4: Create meeting session and host participant initialization',
      () async {
        final scheduledDate = DateTime.now().add(const Duration(hours: 3));
        final session = await meetingService.createMeeting(
          conversationId: 'conv-mtg-101',
          title: 'Voyager Architecture Standup',
          description: 'Reviewing Phase 15 WebRTC meeting stack',
          hostId: 'user-host-alpha',
          scheduledTime: scheduledDate,
        );

        expect(session.id, startsWith('mtg_'));
        expect(session.title, equals('Voyager Architecture Standup'));
        expect(session.hostId, equals('user-host-alpha'));

        final participants = meetingService.getParticipants(session.id);
        expect(participants, isNotEmpty);
        expect(participants.first.role, equals(MeetingRole.host));
        expect(participants.first.isAdmitted, isTrue);
      },
    );

    test('TEST 5 & 6: Waiting room admission workflow', () async {
      const mtgId = 'mtg-test-505';

      await meetingService.joinMeetingLobby(
        meetingId: mtgId,
        userId: 'user-guest-bob',
        displayName: 'Bob Guest',
      );

      var list = meetingService.getParticipants(mtgId);
      final guest = list.firstWhere((p) => p.userId == 'user-guest-bob');
      expect(guest.isAdmitted, isFalse); // Placed in waiting room by default

      // Host admits Bob
      meetingService.admitParticipant(mtgId, 'user-guest-bob');
      list = meetingService.getParticipants(mtgId);
      final admittedGuest = list.firstWhere(
        (p) => p.userId == 'user-guest-bob',
      );
      expect(admittedGuest.isAdmitted, isTrue);
    });

    test('TEST 7 & 8: Participant hand raise toggling', () async {
      const mtgId = 'mtg-test-606';

      await meetingService.joinMeetingLobby(
        meetingId: mtgId,
        userId: 'user-charlie',
        displayName: 'Charlie',
      );

      meetingService.toggleHandRaise(mtgId, 'user-charlie');
      var list = meetingService.getParticipants(mtgId);
      var charlie = list.firstWhere((p) => p.userId == 'user-charlie');
      expect(charlie.isHandRaised, isTrue);

      meetingService.toggleHandRaise(mtgId, 'user-charlie');
      list = meetingService.getParticipants(mtgId);
      charlie = list.firstWhere((p) => p.userId == 'user-charlie');
      expect(charlie.isHandRaised, isFalse);
    });
  });
}
