import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/search/search_models.dart';
import 'package:frontend/core/search/search_service.dart';
import 'package:frontend/features/chat/models/message.dart';
import 'package:frontend/features/chat/repositories/local_chat_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 12 Search, Discovery & Advanced Chat Tests (Steps 241-260)', () {
    late SearchService searchService;

    setUp(() {
      searchService = SearchService.instance;
    });

    test(
      'TEST 1 & 2: SearchHighlightRange calculation finds exact match spans',
      () {
        const text = 'Meeting tomorrow at 10 AM regarding project architecture';
        final ranges = SearchResult.computeHighlights(text, 'project');

        expect(ranges, hasLength(1));
        expect(ranges.first.start, equals(36));
        expect(ranges.first.end, equals(43));
      },
    );

    test(
      'TEST 3 & 4: Local E2EE message search finds matching decrypted messages',
      () async {
        final msg = Message(
          id: 'msg-search-101',
          conversationId: 'conv-search-10',
          senderId: 'user-alice',
          content: 'Top secret alpha project update',
          createdAt: DateTime.now(),
        );

        await LocalChatRepository.instance.saveMessage(msg);

        const query = SearchQuery(keyword: 'secret', type: SearchType.messages);
        final results = await searchService.executeSearch(query);

        expect(results, isNotEmpty);
        expect(results.any((r) => r.snippet.contains('secret')), isTrue);
      },
    );

    test('TEST 5 & 6: Recent search queries storage and clearing', () async {
      await searchService.addRecentQuery('alpha');
      await searchService.addRecentQuery('beta');

      expect(searchService.recentQueries, contains('beta'));

      await searchService.clearRecentQueries();
      expect(searchService.recentQueries, isEmpty);
    });
  });
}
