import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:uuid/uuid.dart';

import '../../../core/auth/models/auth_user.dart';
import '../../../core/auth/services/auth_service.dart';
import '../models/conversation.dart';
import '../models/conversation_member.dart';
import '../models/message.dart';
import '../models/message_reaction.dart';

class ChatRepository {
  ChatRepository._();

  static final ChatRepository instance = ChatRepository._();

  SupabaseClient get _client => Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  AuthUser? get currentUser => AuthService.instance.currentUser;

  Future<List<Conversation>> getConversations() async {
    final user = currentUser;

    if (user == null) {
      return [];
    }

    final response = await _client
        .from('conversation_members')
        .select('''
          conversation_id,
          user_id,
          joined_at,
          last_read_at,
          role,
          is_muted,
          conversations (
            id,
            type,
            name,
            created_by,
            created_at,
            updated_at,
            avatar_url,
            invite_code
          )
        ''')
        .eq('user_id', user.id);

    final conversations = <Conversation>[];

    for (final row in response) {
      final conversationData = row['conversations'];

      if (conversationData is Map<String, dynamic>) {
        conversations.add(Conversation.fromMap(conversationData));
      }
    }

    return conversations;
  }

  Future<Conversation> createConversation({
    required String type,
    String? name,
    String? avatarUrl,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw const AuthException(
        'You must be logged in to create a conversation.',
      );
    }

    final inviteCode = _uuid.v4().substring(0, 8);

    final response = await _client
        .from('conversations')
        .insert({
          'type': type,
          'name': name,
          'created_by': user.id,
          'avatar_url': avatarUrl,
          'invite_code': inviteCode,
        })
        .select()
        .single();

    final conversation = Conversation.fromMap(response);

    await _client.from('conversation_members').insert({
      'conversation_id': conversation.id,
      'user_id': user.id,
      'role': 'owner',
    });

    return conversation;
  }

  Future<Conversation> createGroupConversation({
    required String name,
    required List<String> memberUserIds,
    String? avatarUrl,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw const AuthException('You must be logged in to create a group.');
    }

    final inviteCode = _uuid.v4().substring(0, 8);

    final response = await _client
        .from('conversations')
        .insert({
          'type': 'group',
          'name': name,
          'created_by': user.id,
          'avatar_url': avatarUrl,
          'invite_code': inviteCode,
        })
        .select()
        .single();

    final conversation = Conversation.fromMap(response);

    final membersToInsert = <Map<String, dynamic>>[
      {'conversation_id': conversation.id, 'user_id': user.id, 'role': 'owner'},
    ];

    for (final memberId in memberUserIds) {
      if (memberId != user.id) {
        membersToInsert.add({
          'conversation_id': conversation.id,
          'user_id': memberId,
          'role': 'member',
        });
      }
    }

    await _client.from('conversation_members').upsert(membersToInsert);

    return conversation;
  }

  Future<List<Message>> getMessages(String conversationId) async {
    final response = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return (response as List)
        .map<Message>((row) => Message.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Message> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    String? clientMessageId,
    String? replyToMessageId,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw const AuthException('You must be logged in to send a message.');
    }

    final response = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': user.id,
          'content': content,
          'message_type': messageType,
          'client_message_id': clientMessageId,
          'reply_to_message_id': replyToMessageId,
        })
        .select()
        .single();

    return Message.fromMap(response);
  }

  Future<Message> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw const AuthException('You must be logged in to edit a message.');
    }

    final editedAt = DateTime.now().toUtc().toIso8601String();

    final response = await _client
        .from('messages')
        .update({'content': newContent, 'edited_at': editedAt})
        .eq('id', messageId)
        .eq('sender_id', user.id)
        .select()
        .single();

    return Message.fromMap(response);
  }

  Future<void> deleteMessage({required String messageId}) async {
    final user = currentUser;

    if (user == null) {
      throw const AuthException('You must be logged in to delete a message.');
    }

    final deletedAt = DateTime.now().toUtc().toIso8601String();

    await _client
        .from('messages')
        .update({'deleted_at': deletedAt})
        .eq('id', messageId)
        .eq('sender_id', user.id);
  }

  Future<MessageReaction> addReaction({
    required String messageId,
    required String emoji,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw const AuthException('You must be logged in to react to a message.');
    }

    final reactionId = _uuid.v4();

    try {
      final response = await _client
          .from('message_reactions')
          .insert({
            'id': reactionId,
            'message_id': messageId,
            'user_id': user.id,
            'emoji': emoji,
          })
          .select()
          .single();

      return MessageReaction.fromMap(response);
    } catch (_) {
      return MessageReaction(
        id: reactionId,
        messageId: messageId,
        userId: user.id,
        emoji: emoji,
        createdAt: DateTime.now().toUtc(),
      );
    }
  }

  Future<void> removeReaction(String reactionId) async {
    try {
      await _client.from('message_reactions').delete().eq('id', reactionId);
    } catch (_) {}
  }

  Future<List<MessageReaction>> getReactions(String messageId) async {
    try {
      final response = await _client
          .from('message_reactions')
          .select()
          .eq('message_id', messageId);

      return (response as List)
          .map<MessageReaction>(
            (row) => MessageReaction.fromMap(row as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> updateMemberRole({
    required String conversationId,
    required String userId,
    required String newRole,
  }) async {
    try {
      await _client
          .from('conversation_members')
          .update({'role': newRole})
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);
    } catch (_) {}
  }

  Future<void> removeMemberFromConversation({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _client
          .from('conversation_members')
          .delete()
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);
    } catch (_) {}
  }

  Future<Conversation?> joinConversationByInviteCode(String inviteCode) async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('conversations')
          .select()
          .eq('invite_code', inviteCode)
          .single();

      final conversation = Conversation.fromMap(response);

      await _client.from('conversation_members').upsert({
        'conversation_id': conversation.id,
        'user_id': user.id,
        'role': 'member',
      });

      return conversation;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> getBlockedUserIds() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', user.id);

      return (response as List)
          .map<String>((r) => r['blocked_id'] as String)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> unblockUser(String blockedUserId) async {
    final user = currentUser;
    if (user == null) return;

    try {
      await _client
          .from('blocks')
          .delete()
          .eq('blocker_id', user.id)
          .eq('blocked_id', blockedUserId);
    } catch (_) {}
  }

  Future<void> blockUser(String blockedUserId) async {
    final user = currentUser;
    if (user == null) return;

    try {
      await _client.from('blocks').insert({
        'id': '${user.id}:$blockedUserId',
        'blocker_id': user.id,
        'blocked_id': blockedUserId,
      });
    } catch (_) {}
  }

  Future<void> reportUser(String reportedUserId, String reason) async {
    final user = currentUser;
    if (user == null) return;

    try {
      await _client.from('reports').insert({
        'reporter_id': user.id,
        'reported_id': reportedUserId,
        'reason': reason,
      });
    } catch (_) {}
  }

  Future<void> markMessageAsRead({required String messageId}) async {
    final user = currentUser;

    if (user == null) {
      throw const AuthException(
        'You must be logged in to update message status.',
      );
    }

    await _client.from('message_status').upsert({
      'message_id': messageId,
      'user_id': user.id,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> markConversationAsRead({required String conversationId}) async {
    final user = currentUser;

    if (user == null) return;

    final now = DateTime.now().toUtc().toIso8601String();

    try {
      await _client
          .from('conversation_members')
          .update({'last_read_at': now})
          .eq('conversation_id', conversationId)
          .eq('user_id', user.id);
    } catch (_) {}
  }

  Future<void> deleteConversation(String conversationId) async {
    final user = currentUser;

    if (user == null) return;

    try {
      await _client
          .from('conversation_members')
          .delete()
          .eq('conversation_id', conversationId)
          .eq('user_id', user.id);
    } catch (_) {}
  }

  Future<void> addConversationMember({
    required String conversationId,
    required String userId,
    String role = 'member',
  }) async {
    await _client.from('conversation_members').upsert({
      'conversation_id': conversationId,
      'user_id': userId,
      'role': role,
    });
  }

  Future<List<ConversationMember>> getConversationMembers(
    String conversationId,
  ) async {
    final response = await _client
        .from('conversation_members')
        .select()
        .eq('conversation_id', conversationId);

    return (response as List)
        .map<ConversationMember>(
          (row) => ConversationMember.fromMap(row as Map<String, dynamic>),
        )
        .toList();
  }

  Future<Conversation?> findDirectConversation(String otherUserId) async {
    final user = currentUser;

    if (user == null) return null;

    try {
      final myMemberships = await _client
          .from('conversation_members')
          .select('''
            conversation_id,
            conversations!inner (
              id,
              type,
              name,
              created_by,
              created_at,
              updated_at,
              avatar_url,
              invite_code
            )
          ''')
          .eq('user_id', user.id)
          .eq('conversations.type', 'direct');

      for (final row in myMemberships) {
        final convId = row['conversation_id'] as String;

        final otherMembers = await _client
            .from('conversation_members')
            .select('user_id')
            .eq('conversation_id', convId)
            .eq('user_id', otherUserId);

        if ((otherMembers as List).isNotEmpty) {
          final convData = row['conversations'];

          if (convData is Map<String, dynamic>) {
            return Conversation.fromMap(convData);
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<Conversation> createDirectConversation({
    required String otherUserId,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw const AuthException(
        'You must be logged in to create a conversation.',
      );
    }

    if (user.id == otherUserId) {
      throw const AuthException(
        'You cannot start a conversation with yourself.',
      );
    }

    final existing = await findDirectConversation(otherUserId);

    if (existing != null) {
      return existing;
    }

    final response = await _client
        .from('conversations')
        .insert({'type': 'direct', 'name': null, 'created_by': user.id})
        .select()
        .single();

    final conversation = Conversation.fromMap(response);

    await _client.from('conversation_members').upsert([
      {'conversation_id': conversation.id, 'user_id': user.id, 'role': 'owner'},
      {
        'conversation_id': conversation.id,
        'user_id': otherUserId,
        'role': 'member',
      },
    ]);

    return conversation;
  }
}
