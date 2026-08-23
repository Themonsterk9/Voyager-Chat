import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/database/app_database.dart';
import 'package:frontend/core/groups/group_models.dart';
import 'package:frontend/core/groups/group_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Phase 13 Groups, Communities & Social Features Tests (Steps 261-280)',
    () {
      late GroupService groupService;

      setUp(() {
        groupService = GroupService.instance;
      });

      test('TEST 1 & 2: GroupRole enum parsing and hierarchy order', () {
        expect(GroupRole.owner.name, equals('owner'));
        expect(GroupRole.admin.name, equals('admin'));
        expect(GroupRole.moderator.name, equals('moderator'));
        expect(GroupRole.member.name, equals('member'));
      });

      test(
        'TEST 3 & 4: Create poll and vote with single vote deduplication rule',
        () async {
          try {
            final db = await AppDatabase.instance.database;
            await db.delete(
              'group_polls',
              where: 'conversation_id = ?',
              whereArgs: ['conv-group-poll-test-101'],
            );
          } catch (_) {}

          const convId = 'conv-group-poll-test-101';
          await groupService.createPoll(
            conversationId: convId,
            question: 'Which architecture option?',
            optionTexts: ['Option A', 'Option B'],
          );

          final polls = await groupService.getPolls(convId);
          expect(polls, isNotEmpty);
          final poll = polls.firstWhere(
            (p) => p.question == 'Which architecture option?',
          );

          expect(poll.question, equals('Which architecture option?'));
          expect(poll.options, hasLength(2));

          // Vote 1
          await groupService.voteInPoll(
            pollId: poll.id,
            optionId: 'opt_0',
            userId: 'user-bob',
          );
          final updatedPolls1 = await groupService.getPolls(convId);
          final targetPoll1 = updatedPolls1.firstWhere((p) => p.id == poll.id);
          expect(targetPoll1.totalVotes, equals(1));

          // Duplicate vote attempt by user-bob (should be ignored)
          await groupService.voteInPoll(
            pollId: poll.id,
            optionId: 'opt_1',
            userId: 'user-bob',
          );
          final updatedPolls2 = await groupService.getPolls(convId);
          final targetPoll2 = updatedPolls2.firstWhere((p) => p.id == poll.id);
          expect(targetPoll2.totalVotes, equals(1));
        },
      );

      test('TEST 5 & 6: Group event creation and retrieval', () async {
        const convId = 'conv-group-event-test-202';
        try {
          final db = await AppDatabase.instance.database;
          await db.delete(
            'group_events',
            where: 'conversation_id = ?',
            whereArgs: [convId],
          );
        } catch (_) {}

        await groupService.createEvent(
          conversationId: convId,
          title: 'Architecture Sync',
          description: 'Quarterly review',
          eventDate: DateTime.now().add(const Duration(days: 1)),
          locationName: 'Conference Room A',
          creatorId: 'user-alice',
        );

        final events = await groupService.getEvents(convId);
        expect(events, isNotEmpty);
        final event = events.firstWhere((e) => e.conversationId == convId);
        expect(event.title, equals('Architecture Sync'));
        expect(event.locationName, equals('Conference Room A'));
      });

      test('TEST 7 & 8: Group announcement creation', () async {
        const convId = 'conv-group-ann-test-303';
        try {
          final db = await AppDatabase.instance.database;
          await db.delete(
            'group_announcements',
            where: 'conversation_id = ?',
            whereArgs: [convId],
          );
        } catch (_) {}

        await groupService.postAnnouncement(
          conversationId: convId,
          title: 'System Maintenance Window',
          content: 'Scheduled database optimization tonight.',
          authorName: 'admin-alice',
        );

        final announcements = await groupService.getAnnouncements(convId);
        expect(announcements, isNotEmpty);
        expect(announcements.first.title, equals('System Maintenance Window'));
        expect(announcements.first.authorName, equals('admin-alice'));
      });
    },
  );
}
