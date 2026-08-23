import '../repositories/chat_repository.dart';
import '../repositories/local_chat_repository.dart';

class PendingMessageSyncService {
  PendingMessageSyncService._();

  static final PendingMessageSyncService instance =
      PendingMessageSyncService._();

  final ChatRepository _remote = ChatRepository.instance;

  final LocalChatRepository _local = LocalChatRepository.instance;

  Future<void> syncPendingMessages() async {
    final pendingMessages = await _local.getPendingMessages();

    for (final message in pendingMessages) {
      try {
        final remoteMessage = await _remote.sendMessage(
          conversationId: message.conversationId,
          content: message.content ?? '',
          messageType: message.messageType,
          clientMessageId: message.clientMessageId,
        );

        await _local.saveMessage(remoteMessage);

        await _local.removePendingMessage(message.id);
      } catch (_) {
        // Keep the message queued.
        // It will be retried during the next sync.
      }
    }
  }
}
