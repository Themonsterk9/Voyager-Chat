import 'package:flutter/material.dart';

import '../../chat/services/chat_data_service.dart';
import '../../users/models/user_profile.dart';
import '../../users/repositories/user_repository.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final ChatDataService _chatDataService = ChatDataService.instance;
  final UserRepository _userRepository = UserRepository.instance;

  List<UserProfile> _blockedProfiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final blockedIds = await _chatDataService.getBlockedUserIds();
      final profiles = <UserProfile>[];

      for (final id in blockedIds) {
        final profile = await _userRepository.getUserById(id);
        if (profile != null) {
          profiles.add(profile);
        }
      }

      if (mounted) {
        setState(() {
          _blockedProfiles = profiles;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _unblockUser(UserProfile profile) async {
    await _chatDataService.unblockUser(profile.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${profile.displayNameOrUsername} has been unblocked.'),
        ),
      );
      _loadBlockedUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Users')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blockedProfiles.isEmpty
          ? const Center(
              child: Text(
                'No blocked users',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.separated(
              itemCount: _blockedProfiles.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = _blockedProfiles[index];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.avatarUrl != null
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: user.avatarUrl == null
                        ? Text(
                            user.displayNameOrUsername
                                .substring(0, 1)
                                .toUpperCase(),
                          )
                        : null,
                  ),
                  title: Text(user.displayNameOrUsername),
                  subtitle: user.secondaryName.isNotEmpty
                      ? Text(user.secondaryName)
                      : null,
                  trailing: TextButton(
                    onPressed: () => _unblockUser(user),
                    child: const Text(
                      'Unblock',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
