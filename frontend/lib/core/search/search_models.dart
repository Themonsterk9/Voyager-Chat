enum SearchType {
  all,
  messages,
  users,
  conversations,
  attachments,
  locations,
  calls,
}

class SearchQuery {
  const SearchQuery({
    required this.keyword,
    this.type = SearchType.all,
    this.conversationId,
    this.senderId,
    this.dateStart,
    this.dateEnd,
    this.hasAttachment = false,
    this.limit = 20,
    this.offset = 0,
  });

  final String keyword;
  final SearchType type;
  final String? conversationId;
  final String? senderId;
  final DateTime? dateStart;
  final DateTime? dateEnd;
  final bool hasAttachment;
  final int limit;
  final int offset;
}

class SearchHighlightRange {
  const SearchHighlightRange({required this.start, required this.end});

  final int start;
  final int end;
}

class SearchResult {
  const SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.snippet,
    required this.deepLinkRoute,
    required this.timestamp,
    this.highlights = const [],
    this.metadata = const {},
  });

  final String id;
  final SearchType type;
  final String title;
  final String snippet;
  final String deepLinkRoute;
  final DateTime timestamp;
  final List<SearchHighlightRange> highlights;
  final Map<String, dynamic> metadata;

  static List<SearchHighlightRange> computeHighlights(
    String text,
    String keyword,
  ) {
    if (text.isEmpty || keyword.isEmpty) return [];

    final lowerText = text.toLowerCase();
    final lowerKw = keyword.toLowerCase();
    final ranges = <SearchHighlightRange>[];

    int startIndex = 0;
    while (true) {
      final index = lowerText.indexOf(lowerKw, startIndex);
      if (index == -1) break;
      ranges.add(
        SearchHighlightRange(start: index, end: index + keyword.length),
      );
      startIndex = index + keyword.length;
    }

    return ranges;
  }
}
