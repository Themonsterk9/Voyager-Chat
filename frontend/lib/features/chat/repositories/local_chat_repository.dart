import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../models/conversation.dart';
import '../models/conversation_member.dart';
import '../models/message.dart';
import '../models/message_reaction.dart';

class LocalChatRepository {
  LocalChatRepository._();

  static final LocalChatRepository instance = LocalChatRepository._();

  Future<void> saveConversation(Conversation conversation) async {
    final db = await AppDatabase.instance.database;

    await db.insert(
      'conversations',
      conversation.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveConversations(List<Conversation> conversations) async {
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      for (final conversation in conversations) {
        await txn.insert(
          'conversations',
          conversation.toDatabaseMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Conversation>> getConversations() async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query('conversations', orderBy: 'updated_at DESC');

    return rows.map(Conversation.fromMap).toList();
  }

  Future<void> saveDraftText(String conversationId, String draftText) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'conversations',
      {'draft_text': draftText.isEmpty ? null : draftText},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<String?> getDraftText(String conversationId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'conversations',
      columns: ['draft_text'],
      where: 'id = ?',
      whereArgs: [conversationId],
    );
    if (rows.isEmpty) return null;
    return rows.first['draft_text'] as String?;
  }

  Future<void> pinConversation(String conversationId) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'conversations',
      {'pinned_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> unpinConversation(String conversationId) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'conversations',
      {'pinned_at': null},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> archiveConversation(String conversationId) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'conversations',
      {'archived_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> unarchiveConversation(String conversationId) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'conversations',
      {'archived_at': null},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> saveMessage(Message message) async {
    final db = await AppDatabase.instance.database;

    await db.insert(
      'messages',
      message.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveMessages(List<Message> messages) async {
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      for (final message in messages) {
        await txn.insert(
          'messages',
          message.toDatabaseMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Message>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
      limit: limit,
      offset: offset,
    );

    return rows.map(Message.fromMap).toList();
  }

  Future<List<Message>> getMessagesPaginated(
    String conversationId, {
    required int limit,
    int offset = 0,
  }) async {
    return getMessages(conversationId, limit: limit, offset: offset);
  }

  Future<Message?> getLatestMessage(String conversationId) async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return Message.fromMap(rows.first);
  }

  Future<int> getUnreadCount(
    String conversationId,
    String currentUserId,
  ) async {
    final db = await AppDatabase.instance.database;

    final memberRows = await db.query(
      'conversation_members',
      where: 'conversation_id = ? AND user_id = ?',
      whereArgs: [conversationId, currentUserId],
    );

    String? lastReadAt;
    if (memberRows.isNotEmpty) {
      lastReadAt = memberRows.first['last_read_at'] as String?;
    }

    if (lastReadAt == null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM messages WHERE conversation_id = ? AND sender_id != ?',
        [conversationId, currentUserId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE conversation_id = ? AND sender_id != ? AND created_at > ?',
      [conversationId, currentUserId, lastReadAt],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> updateMessageContent(
    String messageId,
    String newContent,
    DateTime editedAt,
  ) async {
    final db = await AppDatabase.instance.database;

    await db.update(
      'messages',
      {'content': newContent, 'edited_at': editedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> softDeleteMessage(String messageId, DateTime deletedAt) async {
    final db = await AppDatabase.instance.database;

    await db.update(
      'messages',
      {'deleted_at': deletedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> saveReaction(MessageReaction reaction) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'message_reactions',
      reaction.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeReaction(String reactionId) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'message_reactions',
      where: 'id = ?',
      whereArgs: [reactionId],
    );
  }

  Future<List<MessageReaction>> getReactions(String messageId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'message_reactions',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
    return rows.map(MessageReaction.fromMap).toList();
  }

  Future<void> updateMemberRole(
    String conversationId,
    String userId,
    String role,
  ) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'conversation_members',
      {'role': role},
      where: 'conversation_id = ? AND user_id = ?',
      whereArgs: [conversationId, userId],
    );
  }

  Future<void> removeMember(String conversationId, String userId) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'conversation_members',
      where: 'conversation_id = ? AND user_id = ?',
      whereArgs: [conversationId, userId],
    );
  }

  Future<void> toggleMuteConversation(
    String conversationId,
    String userId,
    bool isMuted,
  ) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'conversation_members',
      {'is_muted': isMuted ? 1 : 0},
      where: 'conversation_id = ? AND user_id = ?',
      whereArgs: [conversationId, userId],
    );
  }

  Future<List<String>> getBlockedUserIds(String currentUserId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'blocks',
      where: 'blocker_id = ?',
      whereArgs: [currentUserId],
    );
    return rows.map((r) => r['blocked_id'] as String).toList();
  }

  Future<void> unblockUser(String blockerId, String blockedId) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'blocks',
      where: 'blocker_id = ? AND blocked_id = ?',
      whereArgs: [blockerId, blockedId],
    );
  }

  Future<void> blockUser(String blockerId, String blockedId) async {
    final db = await AppDatabase.instance.database;
    await db.insert('blocks', {
      'id': '$blockerId:$blockedId',
      'blocker_id': blockerId,
      'blocked_id': blockedId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> reportUser(
    String reporterId,
    String reportedId,
    String reason,
  ) async {
    final db = await AppDatabase.instance.database;
    await db.insert('reports', {
      'id': '$reporterId:$reportedId:${DateTime.now().millisecondsSinceEpoch}',
      'reporter_id': reporterId,
      'reported_id': reportedId,
      'reason': reason,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateConversationLastRead(
    String conversationId,
    String userId,
    DateTime lastReadAt,
  ) async {
    final db = await AppDatabase.instance.database;

    await db.update(
      'conversation_members',
      {'last_read_at': lastReadAt.toIso8601String()},
      where: 'conversation_id = ? AND user_id = ?',
      whereArgs: [conversationId, userId],
    );
  }

  Future<void> saveConversationMember(ConversationMember member) async {
    final db = await AppDatabase.instance.database;

    await db.insert(
      'conversation_members',
      member.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ConversationMember>> getConversationMembers(
    String conversationId,
  ) async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      'conversation_members',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );

    return rows.map(ConversationMember.fromMap).toList();
  }

  Future<void> saveMessageStatus({
    required String messageId,
    required String userId,
    String? deliveredAt,
    String? readAt,
  }) async {
    final db = await AppDatabase.instance.database;

    await db.insert('message_status', {
      'message_id': messageId,
      'user_id': userId,
      'delivered_at': deliveredAt,
      'read_at': readAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteConversation(String conversationId) async {
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      await txn.delete(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      );

      await txn.delete(
        'conversation_members',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      );

      await txn.delete(
        'conversations',
        where: 'id = ?',
        whereArgs: [conversationId],
      );
    });
  }

  Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      try {
        await txn.delete('reports');
      } catch (_) {}
      try {
        await txn.delete('blocks');
      } catch (_) {}
      try {
        await txn.delete('message_reactions');
      } catch (_) {}
      try {
        await txn.delete('message_status');
      } catch (_) {}
      try {
        await txn.delete('messages');
      } catch (_) {}
      try {
        await txn.delete('conversation_members');
      } catch (_) {}
      try {
        await txn.delete('conversations');
      } catch (_) {}
    });
  }

  Future<void> queueMessage(Message message) async {
    final db = await AppDatabase.instance.database;

    await db.insert('pending_messages', {
      'id': message.id,
      'conversation_id': message.conversationId,
      'sender_id': message.senderId,
      'content': message.content,
      'message_type': message.messageType,
      'client_message_id': message.clientMessageId,
      'created_at':
          message.createdAt?.toIso8601String() ??
          DateTime.now().toUtc().toIso8601String(),
      'queued_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Message>> getPendingMessages() async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query('pending_messages', orderBy: 'created_at ASC');

    return rows.map((row) {
      return Message.fromMap({
        'id': row['id'],
        'conversation_id': row['conversation_id'],
        'sender_id': row['sender_id'],
        'content': row['content'],
        'message_type': row['message_type'],
        'client_message_id': row['client_message_id'],
        'created_at': row['created_at'],
        'edited_at': null,
        'deleted_at': null,
      });
    }).toList();
  }

  Future<void> removePendingMessage(String messageId) async {
    final db = await AppDatabase.instance.database;

    await db.delete(
      'pending_messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }
}
