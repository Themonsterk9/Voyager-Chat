import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:frontend/core/database/app_database.dart';
import 'package:frontend/features/chat/models/conversation.dart';
import 'package:frontend/features/chat/models/message.dart';
import 'package:frontend/features/chat/repositories/local_chat_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalChatRepository repository;

  setUp(() async {
    repository = LocalChatRepository.instance;
    await repository.clearAll();
  });

  tearDown(() async {
    await repository.clearAll();
  });

  tearDownAll(() async {
    await AppDatabase.instance.close();
  });

  test('saves and retrieves a conversation', () async {
    final conversation = Conversation(
      id: 'conversation-test-1',
      type: 'direct',
      name: 'Local Test Chat',
      createdBy: 'user-test-1',
      createdAt: DateTime.utc(2026, 8, 17, 10),
      updatedAt: DateTime.utc(2026, 8, 17, 10),
    );

    await repository.saveConversation(conversation);

    final conversations = await repository.getConversations();

    expect(conversations, hasLength(1));
    expect(conversations.first.id, 'conversation-test-1');
    expect(conversations.first.name, 'Local Test Chat');
  });

  test('saves and retrieves messages by conversation', () async {
    final message = Message(
      id: 'message-test-1',
      conversationId: 'conversation-test-1',
      senderId: 'user-test-1',
      content: 'Hello Voyager',
      messageType: 'text',
      createdAt: DateTime.utc(2026, 8, 17, 10),
    );

    await repository.saveMessage(message);

    final messages = await repository.getMessages('conversation-test-1');

    expect(messages, hasLength(1));
    expect(messages.first.id, 'message-test-1');
    expect(messages.first.content, 'Hello Voyager');
  });

  test('deletes a conversation and its messages', () async {
    final conversation = Conversation(
      id: 'conversation-test-2',
      type: 'direct',
      name: 'Delete Test',
      createdBy: 'user-test-1',
      createdAt: DateTime.utc(2026, 8, 17, 10),
      updatedAt: DateTime.utc(2026, 8, 17, 10),
    );

    final message = Message(
      id: 'message-test-2',
      conversationId: 'conversation-test-2',
      senderId: 'user-test-1',
      content: 'Delete me',
      messageType: 'text',
      createdAt: DateTime.utc(2026, 8, 17, 10),
    );

    await repository.saveConversation(conversation);
    await repository.saveMessage(message);

    await repository.deleteConversation('conversation-test-2');

    final conversations = await repository.getConversations();
    final messages = await repository.getMessages('conversation-test-2');
    final remaining = conversations.where((c) => c.id == 'conversation-test-2');
    expect(remaining, isEmpty);
    expect(messages, isEmpty);
  });
}
