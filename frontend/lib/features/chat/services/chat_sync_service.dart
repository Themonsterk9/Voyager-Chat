import '../repositories/chat_repository.dart';
import '../repositories/local_chat_repository.dart';

class ChatSyncService {
  ChatSyncService._();

  static final ChatSyncService instance = ChatSyncService._();

  final ChatRepository _remote = ChatRepository.instance;
  final LocalChatRepository _local = LocalChatRepository.instance;

  Future<void> syncConversations() async {
    final conversations = await _remote.getConversations();

    await _local.saveConversations(conversations);

    for (final conversation in conversations) {
      final messages = await _remote.getMessages(conversation.id);

      await _local.saveMessages(messages);
    }
  }
}
