import 'package:uuid/uuid.dart';

import '../../../core/auth/services/auth_service.dart';
import '../../../core/services/rate_limiter_service.dart';
import '../models/conversation.dart';
import '../models/conversation_member.dart';
import '../models/message.dart';
import '../models/message_reaction.dart';
import '../repositories/chat_repository.dart';
import '../repositories/local_chat_repository.dart';
import 'realtime_message_service.dart';

class ChatDataService {
  ChatDataService._();

  static final ChatDataService instance = ChatDataService._();

  final ChatRepository _remote = ChatRepository.instance;
  final LocalChatRepository _local = LocalChatRepository.instance;
  final RateLimiterService _rateLimiter = RateLimiterService.instance;

  final Uuid _uuid = const Uuid();

  Future<List<Conversation>> getConversations() async {
    try {
      final conversations = await _remote.getConversations();
      await _local.saveConversations(conversations);
      return conversations;
    } catch (_) {
      return _local.getConversations();
    }
  }

  Future<void> saveDraftText(String conversationId, String draftText) async {
    await _local.saveDraftText(conversationId, draftText);
  }

  Future<String?> getDraftText(String conversationId) async {
    return _local.getDraftText(conversationId);
  }

  Future<void> pinConversation(String conversationId) async {
    await _local.pinConversation(conversationId);
  }

  Future<void> unpinConversation(String conversationId) async {
    await _local.unpinConversation(conversationId);
  }

  Future<void> archiveConversation(String conversationId) async {
    await _local.archiveConversation(conversationId);
  }

  Future<void> unarchiveConversation(String conversationId) async {
    await _local.unarchiveConversation(conversationId);
  }

  Future<List<Message>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final messages = await _remote.getMessages(conversationId);

      await _local.saveMessages(messages);

      return messages;
    } catch (_) {
      return _local.getMessages(conversationId, limit: limit, offset: offset);
    }
  }

  Future<Message?> getLatestMessage(String conversationId) async {
    return _local.getLatestMessage(conversationId);
  }

  Future<int> getUnreadCount(
    String conversationId,
    String currentUserId,
  ) async {
    return _local.getUnreadCount(conversationId, currentUserId);
  }

  Future<List<ConversationMember>> getConversationMembers(
    String conversationId,
  ) async {
    try {
      final members = await _remote.getConversationMembers(conversationId);

      for (final member in members) {
        await _local.saveConversationMember(member);
      }

      return members;
    } catch (_) {
      return _local.getConversationMembers(conversationId);
    }
  }

  Future<Conversation> createConversation({
    required String type,
    String? name,
    String? avatarUrl,
  }) async {
    final conversation = await _remote.createConversation(
      type: type,
      name: name,
      avatarUrl: avatarUrl,
    );

    await _local.saveConversations([conversation]);

    return conversation;
  }

  Future<Conversation> createGroupConversation({
    required String name,
    required List<String> memberUserIds,
    String? avatarUrl,
  }) async {
    final conversation = await _remote.createGroupConversation(
      name: name,
      memberUserIds: memberUserIds,
      avatarUrl: avatarUrl,
    );

    await _local.saveConversations([conversation]);

    return conversation;
  }

  Future<void> addMemberToGroup(String conversationId, String userId) async {
    await _remote.addConversationMember(
      conversationId: conversationId,
      userId: userId,
    );
    await _local.saveConversationMember(
      ConversationMember(conversationId: conversationId, userId: userId),
    );
  }

  Future<void> updateMemberRole(
    String conversationId,
    String userId,
    String newRole,
  ) async {
    await _local.updateMemberRole(conversationId, userId, newRole);
    await _remote.updateMemberRole(
      conversationId: conversationId,
      userId: userId,
      newRole: newRole,
    );
  }

  Future<void> removeMember(String conversationId, String userId) async {
    await _local.removeMember(conversationId, userId);
    await _remote.removeMemberFromConversation(
      conversationId: conversationId,
      userId: userId,
    );
  }

  Future<Conversation?> joinGroupByInviteCode(String inviteCode) async {
    final conversation = await _remote.joinConversationByInviteCode(inviteCode);
    if (conversation != null) {
      await _local.saveConversations([conversation]);
    }
    return conversation;
  }

  Future<void> toggleMuteConversation(
    String conversationId,
    bool isMuted,
  ) async {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      await _local.toggleMuteConversation(conversationId, user.id, isMuted);
    }
  }

  Future<Message> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    String? replyToMessageId,
    DateTime? scheduledAt,
  }) async {
    if (!_rateLimiter.checkCanSendMessage()) {
      throw Exception(
        'Rate limit exceeded. Please wait a moment before sending again.',
      );
    }

    final user = AuthService.instance.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to send a message.');
    }

    final clientMessageId = _uuid.v4();

    final localMessage = Message(
      id: clientMessageId,
      conversationId: conversationId,
      senderId: user.id,
      content: content,
      messageType: messageType,
      clientMessageId: clientMessageId,
      replyToMessageId: replyToMessageId,
      createdAt: DateTime.now().toUtc(),
      scheduledAt: scheduledAt,
    );

    try {
      final remoteMessage = await _remote.sendMessage(
        conversationId: conversationId,
        content: content,
        messageType: messageType,
        clientMessageId: clientMessageId,
        replyToMessageId: replyToMessageId,
      );

      await _local.saveMessage(remoteMessage);
      await _local.saveDraftText(conversationId, '');

      return remoteMessage;
    } catch (_) {
      await _local.saveMessage(localMessage);
      await _local.queueMessage(localMessage);
      await _local.saveDraftText(conversationId, '');

      return localMessage;
    }
  }

  Future<Message> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    final editedAt = DateTime.now().toUtc();

    await _local.updateMessageContent(messageId, newContent, editedAt);

    try {
      final updatedMessage = await _remote.editMessage(
        messageId: messageId,
        newContent: newContent,
      );

      await _local.saveMessage(updatedMessage);

      return updatedMessage;
    } catch (_) {
      return Message(
        id: messageId,
        conversationId: '',
        senderId: '',
        content: newContent,
        editedAt: editedAt,
      );
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final deletedAt = DateTime.now().toUtc();

    await _local.softDeleteMessage(messageId, deletedAt);

    try {
      await _remote.deleteMessage(messageId: messageId);
    } catch (_) {}
  }

  Future<MessageReaction> addReaction({
    required String messageId,
    required String emoji,
  }) async {
    final reaction = await _remote.addReaction(
      messageId: messageId,
      emoji: emoji,
    );

    await _local.saveReaction(reaction);

    return reaction;
  }

  Future<void> removeReaction({required String reactionId}) async {
    await _local.removeReaction(reactionId);
    await _remote.removeReaction(reactionId);
  }

  Future<List<MessageReaction>> getReactions(String messageId) async {
    try {
      final reactions = await _remote.getReactions(messageId);
      for (final r in reactions) {
        await _local.saveReaction(r);
      }
      return reactions;
    } catch (_) {
      return _local.getReactions(messageId);
    }
  }

  Future<List<String>> getBlockedUserIds() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return [];
    try {
      return await _remote.getBlockedUserIds();
    } catch (_) {
      return _local.getBlockedUserIds(user.id);
    }
  }

  Future<void> unblockUser(String blockedUserId) async {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      await _local.unblockUser(user.id, blockedUserId);
      await _remote.unblockUser(blockedUserId);
    }
  }

  Future<void> blockUser(String blockedUserId) async {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      await _local.blockUser(user.id, blockedUserId);
      await _remote.blockUser(blockedUserId);
    }
  }

  Future<void> reportUser(String reportedUserId, String reason) async {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      await _local.reportUser(user.id, reportedUserId, reason);
      await _remote.reportUser(reportedUserId, reason);
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final user = AuthService.instance.currentUser;

    if (user == null) return;

    final now = DateTime.now().toUtc();

    await _local.updateConversationLastRead(conversationId, user.id, now);

    try {
      await _remote.markConversationAsRead(conversationId: conversationId);
    } catch (_) {}
  }

  Future<void> deleteConversation(String conversationId) async {
    await _local.deleteConversation(conversationId);

    try {
      await _remote.deleteConversation(conversationId);
    } catch (_) {}
  }

  Future<Conversation> createDirectConversation({
    required String otherUserId,
  }) async {
    final conversation = await _remote.createDirectConversation(
      otherUserId: otherUserId,
    );

    await _local.saveConversations([conversation]);

    return conversation;
  }

  void subscribeToRealtimeMessages(
    String conversationId, {
    required void Function(RealtimeMessageEvent event) onEvent,
  }) {
    RealtimeMessageService.instance.startConversationSubscription(
      conversationId,
      onEvent: onEvent,
    );
  }

  void unsubscribeFromRealtimeMessages(
    String conversationId, {
    void Function(RealtimeMessageEvent event)? onEvent,
  }) {
    RealtimeMessageService.instance.stopConversationSubscription(
      conversationId,
      onEvent: onEvent,
    );
  }
}
