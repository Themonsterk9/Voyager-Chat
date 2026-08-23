import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/search/search_models.dart';
import '../../../core/search/search_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SearchService _searchService = SearchService.instance;
  final TextEditingController _queryController = TextEditingController();

  SearchType _selectedType = SearchType.all;
  List<SearchResult> _results = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String queryText) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final text = _queryController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final searchQuery = SearchQuery(keyword: text, type: _selectedType);

    final res = await _searchService.executeSearch(searchQuery);

    if (mounted) {
      setState(() {
        _results = res;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentQueries = _searchService.recentQueries;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _queryController,
          autofocus: true,
          onChanged: _onQueryChanged,
          decoration: const InputDecoration(
            hintText: 'Search messages, chats, calls...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_queryController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _queryController.clear();
                _performSearch();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All', SearchType.all),
                const SizedBox(width: 8),
                _buildFilterChip('Messages', SearchType.messages),
                const SizedBox(width: 8),
                _buildFilterChip('Conversations', SearchType.conversations),
                const SizedBox(width: 8),
                _buildFilterChip('Calls', SearchType.calls),
              ],
            ),
          ),
          const Divider(height: 1),
          // Body List
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : (_queryController.text.isEmpty
                      ? _buildRecentSearchesView(recentQueries)
                      : _buildSearchResultsView()),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, SearchType type) {
    final isSelected = _selectedType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedType = type;
          });
          _performSearch();
        }
      },
    );
  }

  Widget _buildRecentSearchesView(List<String> recentQueries) {
    if (recentQueries.isEmpty) {
      return const Center(
        child: Text(
          'Type a keyword to search local decrypted messages, chats, and call logs.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'RECENT SEARCHES',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            TextButton(
              onPressed: () async {
                await _searchService.clearRecentQueries();
                setState(() {});
              },
              child: const Text('Clear All'),
            ),
          ],
        ),
        ...recentQueries.map(
          (q) => ListTile(
            leading: const Icon(Icons.history, size: 20),
            title: Text(q),
            onTap: () {
              _queryController.text = q;
              _performSearch();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsView() {
    if (_results.isEmpty) {
      return const Center(child: Text('No results found.'));
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _results[index];
        return ListTile(
          leading: Icon(
            result.type == SearchType.messages
                ? Icons.chat_bubble_outline
                : (result.type == SearchType.conversations
                      ? Icons.group
                      : Icons.phone),
            color: Colors.blueAccent,
          ),
          title: Text(
            result.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            result.snippet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(result.deepLinkRoute),
        );
      },
    );
  }
}
