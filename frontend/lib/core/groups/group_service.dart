import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import 'group_models.dart';

class GroupService {
  GroupService._();

  static final GroupService instance = GroupService._();

  Future<void> createPoll({
    required String conversationId,
    required String question,
    required List<String> optionTexts,
  }) async {
    final db = await AppDatabase.instance.database;
    final pollId = 'poll_${DateTime.now().millisecondsSinceEpoch}';

    final options = optionTexts
        .asMap()
        .entries
        .map(
          (e) => GroupPollOption(
            id: 'opt_${e.key}',
            text: e.value,
            votes: 0,
          ).toMap(),
        )
        .toList();

    await db.insert('group_polls', {
      'id': pollId,
      'conversation_id': conversationId,
      'question': question,
      'options_json': json.encode(options),
      'voters_json': json.encode(<String>[]),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> voteInPoll({
    required String pollId,
    required String optionId,
    required String userId,
  }) async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      'group_polls',
      where: 'id = ?',
      whereArgs: [pollId],
    );
    if (rows.isEmpty) return;

    final row = rows.first;
    final List voters = json.decode(row['voters_json'] as String) as List;

    // Single vote deduplication rule
    if (voters.contains(userId)) return;

    final List rawOptions = json.decode(row['options_json'] as String) as List;
    final updatedOptions = rawOptions.map((opt) {
      final m = Map<String, dynamic>.from(opt as Map);
      if (m['id'] == optionId) {
        m['votes'] = ((m['votes'] as num?)?.toInt() ?? 0) + 1;
      }
      return m;
    }).toList();

    voters.add(userId);

    await db.update(
      'group_polls',
      {
        'options_json': json.encode(updatedOptions),
        'voters_json': json.encode(voters),
      },
      where: 'id = ?',
      whereArgs: [pollId],
    );
  }

  Future<List<GroupPoll>> getPolls(String conversationId) async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      'group_polls',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );

    return rows.map((r) {
      final List rawOptions = json.decode(r['options_json'] as String) as List;
      final List rawVoters = json.decode(r['voters_json'] as String) as List;

      return GroupPoll(
        id: r['id'] as String,
        conversationId: r['conversation_id'] as String,
        question: r['question'] as String,
        options: rawOptions
            .map(
              (o) =>
                  GroupPollOption.fromMap(Map<String, dynamic>.from(o as Map)),
            )
            .toList(),
        voterUserIds: rawVoters.cast<String>(),
      );
    }).toList();
  }

  Future<void> createEvent({
    required String conversationId,
    required String title,
    String? description,
    required DateTime eventDate,
    String? locationName,
    required String creatorId,
  }) async {
    final db = await AppDatabase.instance.database;
    final eventId = 'evt_${DateTime.now().millisecondsSinceEpoch}';

    await db.insert('group_events', {
      'id': eventId,
      'conversation_id': conversationId,
      'title': title,
      'description': description,
      'event_date': eventDate.toIso8601String(),
      'location_name': locationName,
      'creator_id': creatorId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<GroupEvent>> getEvents(String conversationId) async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      'group_events',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'event_date ASC',
    );

    return rows.map((r) {
      return GroupEvent(
        id: r['id'] as String,
        conversationId: r['conversation_id'] as String,
        title: r['title'] as String,
        description: r['description'] as String?,
        eventDate:
            DateTime.tryParse(r['event_date'].toString()) ?? DateTime.now(),
        locationName: r['location_name'] as String?,
        creatorId: r['creator_id'] as String,
      );
    }).toList();
  }

  Future<void> postAnnouncement({
    required String conversationId,
    required String title,
    required String content,
    required String authorName,
  }) async {
    final db = await AppDatabase.instance.database;
    final id = 'anc_${DateTime.now().millisecondsSinceEpoch}';

    await db.insert('group_announcements', {
      'id': id,
      'conversation_id': conversationId,
      'title': title,
      'content': content,
      'author_name': authorName,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<GroupAnnouncement>> getAnnouncements(
    String conversationId,
  ) async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      'group_announcements',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at DESC',
    );

    return rows.map((r) {
      return GroupAnnouncement(
        id: r['id'] as String,
        conversationId: r['conversation_id'] as String,
        title: r['title'] as String,
        content: r['content'] as String,
        authorName: r['author_name'] as String,
        createdAt:
            DateTime.tryParse(r['created_at'].toString()) ?? DateTime.now(),
      );
    }).toList();
  }
}
