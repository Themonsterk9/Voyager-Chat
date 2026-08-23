import '../database/app_database.dart';
import 'search_models.dart';

class SearchService {
  SearchService._();

  static final SearchService instance = SearchService._();

  final List<String> _recentQueries = [];

  List<String> get recentQueries => List.unmodifiable(_recentQueries);

  Future<void> addRecentQuery(String queryText) async {
    if (queryText.trim().isEmpty) return;

    _recentQueries.remove(queryText);
    _recentQueries.insert(0, queryText);

    if (_recentQueries.length > 20) {
      _recentQueries.removeLast();
    }

    try {
      final db = await AppDatabase.instance.database;
      final id = 'search_${DateTime.now().millisecondsSinceEpoch}';
      await db.insert('recent_searches', {
        'id': id,
        'query_text': queryText,
        'searched_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> clearRecentQueries() async {
    _recentQueries.clear();
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('recent_searches');
    } catch (_) {}
  }

  Future<List<SearchResult>> executeSearch(SearchQuery query) async {
    if (query.keyword.trim().isNotEmpty) {
      await addRecentQuery(query.keyword.trim());
    }

    final results = <SearchResult>[];

    try {
      final db = await AppDatabase.instance.database;

      // 1. Search Messages (Local E2EE Search over decrypted content)
      if (query.type == SearchType.all || query.type == SearchType.messages) {
        final rows = await db.query(
          'messages',
          where: 'content LIKE ?',
          whereArgs: ['%${query.keyword}%'],
          limit: query.limit,
          offset: query.offset,
        );

        for (final r in rows) {
          final text = (r['content'] as String?) ?? '';
          final msgId = r['id'] as String;
          final convId = r['conversation_id'] as String;
          final highlights = SearchResult.computeHighlights(
            text,
            query.keyword,
          );

          results.add(
            SearchResult(
              id: msgId,
              type: SearchType.messages,
              title: 'Message',
              snippet: text,
              deepLinkRoute: '/chat/$convId',
              timestamp:
                  DateTime.tryParse(r['created_at'].toString()) ??
                  DateTime.now(),
              highlights: highlights,
              metadata: {'conversation_id': convId},
            ),
          );
        }
      }

      // 2. Search Conversations
      if (query.type == SearchType.all ||
          query.type == SearchType.conversations) {
        final rows = await db.query(
          'conversations',
          where: 'name LIKE ?',
          whereArgs: ['%${query.keyword}%'],
          limit: query.limit,
        );

        for (final r in rows) {
          final name = (r['name'] as String?) ?? 'Chat';
          final convId = r['id'] as String;
          final highlights = SearchResult.computeHighlights(
            name,
            query.keyword,
          );

          results.add(
            SearchResult(
              id: convId,
              type: SearchType.conversations,
              title: name,
              snippet: 'Conversation • ${r['type']}',
              deepLinkRoute: '/chat/$convId',
              timestamp:
                  DateTime.tryParse(r['updated_at'].toString()) ??
                  DateTime.now(),
              highlights: highlights,
            ),
          );
        }
      }

      // 3. Search Call Logs
      if (query.type == SearchType.all || query.type == SearchType.calls) {
        final rows = await db.query(
          'call_logs',
          where: 'caller_name LIKE ? OR call_type LIKE ?',
          whereArgs: ['%${query.keyword}%', '%${query.keyword}%'],
          limit: query.limit,
        );

        for (final r in rows) {
          final caller = r['caller_name'] as String;
          final callType = r['call_type'] as String;
          final callId = r['id'] as String;

          results.add(
            SearchResult(
              id: callId,
              type: SearchType.calls,
              title: '$callType Call with $caller',
              snippet:
                  'Status: ${r['status']} • Duration: ${r['duration_seconds']}s',
              deepLinkRoute: '/settings/call-history',
              timestamp:
                  DateTime.tryParse(r['start_time'].toString()) ??
                  DateTime.now(),
              highlights: SearchResult.computeHighlights(caller, query.keyword),
            ),
          );
        }
      }
    } catch (_) {}

    return results;
  }
}
