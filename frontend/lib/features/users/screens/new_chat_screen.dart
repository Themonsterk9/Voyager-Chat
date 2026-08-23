import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../chat/services/chat_data_service.dart';
import '../models/user_profile.dart';
import '../repositories/user_repository.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();

  final UserRepository _userRepository = UserRepository.instance;
  final ChatDataService _chatDataService = ChatDataService.instance;

  Timer? _debounce;
  List<UserProfile> _users = [];
  bool _isSearching = false;
  bool _isCreating = false;
  String? _selectedUserId;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _users = [];
        _error = null;
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _searchUsers(query);
    });
  }

  Future<void> _searchUsers(String query) async {
    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final users = await _userRepository.searchUsers(query);

      if (!mounted) return;

      setState(() {
        _users = users;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _users = [];
        _isSearching = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _startConversation(UserProfile user) async {
    if (_isCreating) return;

    setState(() {
      _isCreating = true;
      _selectedUserId = user.id;
      _error = null;
    });

    try {
      final conversation = await _chatDataService.createDirectConversation(
        otherUserId: user.id,
      );

      if (!mounted) return;

      context.pushReplacement('/chat/${conversation.id}');
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isCreating = false;
        _selectedUserId = null;
        _error = error.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start conversation: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or username',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _users = [];
                            _error = null;
                          });
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return const Center(
        child: Text(
          'Search for a Voyager user to start chatting.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        child: Text('No users found.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _users.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = _users[index];
        final isThisSelected = _isCreating && _selectedUserId == user.id;

        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundImage: user.avatarUrl == null
                ? null
                : NetworkImage(user.avatarUrl!),
            child: user.avatarUrl == null
                ? Text(
                    user.displayNameOrUsername.isEmpty
                        ? 'V'
                        : user.displayNameOrUsername
                              .substring(0, 1)
                              .toUpperCase(),
                  )
                : null,
          ),
          title: Text(
            user.displayNameOrUsername,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: user.secondaryName.isEmpty
              ? null
              : Text(
                  user.secondaryName,
                  style: const TextStyle(color: Colors.grey),
                ),
          trailing: isThisSelected
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _isCreating ? null : () => _startConversation(user),
        );
      },
    );
  }
}
