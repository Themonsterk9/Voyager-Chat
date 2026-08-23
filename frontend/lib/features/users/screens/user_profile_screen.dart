import 'package:flutter/material.dart';

import '../../../core/auth/services/auth_service.dart';
import '../models/user_profile.dart';
import '../repositories/user_repository.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserRepository _userRepository = UserRepository.instance;

  UserProfile? _profile;
  bool _loading = true;

  bool get _isSelf => widget.userId == AuthService.instance.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      var profile = await _userRepository.getUserById(widget.userId);
      if (profile == null && _isSelf) {
        final current = AuthService.instance.currentUser;
        if (current != null) {
          profile = await _userRepository.ensureProfileExists(current);
        }
      }
      if (mounted) {
        setState(() {
          _profile = profile;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        final current = AuthService.instance.currentUser;
        setState(() {
          _profile ??= (_isSelf && current != null)
              ? UserProfile(
                  id: current.id,
                  email: current.email,
                  displayName: current.displayName,
                )
              : null;
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateDisplayName() async {
    if (!_isSelf || _profile == null) return;

    final controller = TextEditingController(text: _profile!.displayName ?? '');

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new display name...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      try {
        final updated = await UserRepository.instance.updateDisplayName(
          newName,
        );
        if (mounted) {
          setState(() {
            _profile = updated;
          });
        }
        _loadProfile();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update name: $error')),
        );
      }
    }
  }

  Future<void> _updateUsername() async {
    if (!_isSelf || _profile == null) return;

    final current = _profile!.username ?? '';
    final hasUsername = current.isNotEmpty;

    showDialog<void>(
      context: context,
      builder: (context) {
        return _UsernameEditDialog(
          initialUsername: current,
          hasExistingUsername: hasUsername,
          onSuccess: (updatedProfile) {
            if (mounted) {
              setState(() {
                _profile = updatedProfile;
              });
              _loadProfile();
            }
          },
        );
      },
    );
  }

  Future<void> _uploadAvatar() async {
    if (!_isSelf) return;

    final controller = TextEditingController();

    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Avatar URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter image URL (https://...)...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (url != null && url.isNotEmpty) {
      try {
        final updated = await UserRepository.instance.updateAvatarUrl(url);
        if (mounted) {
          setState(() {
            _profile = updated;
          });
        }
        _loadProfile();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update avatar: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelf ? 'My Profile' : 'User Profile'),
        actions: [
          if (_isSelf && _profile != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _updateDisplayName,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
          ? const Center(child: Text('Profile not found'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundImage: _profile!.avatarUrl != null
                            ? NetworkImage(_profile!.avatarUrl!)
                            : null,
                        child: _profile!.avatarUrl == null
                            ? Text(
                                _profile!.displayNameOrUsername
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(fontSize: 36),
                              )
                            : null,
                      ),
                      if (_isSelf)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary,
                            child: IconButton(
                              iconSize: 18,
                              icon: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                              ),
                              onPressed: _uploadAvatar,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _profile!.displayNameOrUsername,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_profile!.secondaryName.isNotEmpty)
                  Center(
                    child: Text(
                      _profile!.secondaryName,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _profile!.status == 'online'
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _profile!.status == 'online' ? '● Online' : '○ Offline',
                      style: TextStyle(
                        color: _profile!.status == 'online'
                            ? Colors.greenAccent
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Display Name'),
                        subtitle: Text(_profile!.displayNameOrUsername),
                        trailing: _isSelf
                            ? const Icon(Icons.edit, size: 20)
                            : null,
                        onTap: _isSelf ? _updateDisplayName : null,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.alternate_email,
                          color: Colors.blueAccent,
                        ),
                        title: const Text('Username'),
                        subtitle: Text(
                          _profile!.username != null &&
                                  _profile!.username!.isNotEmpty
                              ? '@${_profile!.username}'
                              : 'Not set',
                          style: TextStyle(
                            color:
                                _profile!.username != null &&
                                    _profile!.username!.isNotEmpty
                                ? Colors.blueAccent
                                : Colors.grey,
                            fontWeight:
                                _profile!.username != null &&
                                    _profile!.username!.isNotEmpty
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: _isSelf
                            ? const Icon(Icons.edit, size: 20)
                            : null,
                        onTap: _isSelf ? _updateUsername : null,
                      ),
                      const Divider(height: 1),
                      if (_profile!.email != null &&
                          _profile!.email!.isNotEmpty) ...[
                        ListTile(
                          leading: const Icon(Icons.email),
                          title: const Text('Email'),
                          subtitle: Text(_profile!.email!),
                        ),
                        const Divider(height: 1),
                      ],
                      ListTile(
                        leading: const Icon(Icons.badge),
                        title: const Text('User ID'),
                        subtitle: Text(
                          _profile!.id,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (_profile!.authProvider != null &&
                          _profile!.authProvider!.isNotEmpty) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.security),
                          title: const Text('Auth Method'),
                          subtitle: Text(
                            _profile!.authProvider!.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _UsernameEditDialog extends StatefulWidget {
  const _UsernameEditDialog({
    required this.initialUsername,
    required this.hasExistingUsername,
    required this.onSuccess,
  });

  final String initialUsername;
  final bool hasExistingUsername;
  final void Function(UserProfile profile) onSuccess;

  @override
  State<_UsernameEditDialog> createState() => _UsernameEditDialogState();
}

class _UsernameEditDialogState extends State<_UsernameEditDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUsername);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final text = _controller.text.trim();
    final clientError = UserRepository.validateUsername(text);
    if (clientError != null) {
      setState(() {
        _errorMessage = clientError;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updated = await UserRepository.instance.updateUsername(text);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to update username: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.alternate_email, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.hasExistingUsername ? 'Edit Username' : 'Set Username',
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.hasExistingUsername) ...[
              Text(
                'Current username: @${widget.initialUsername}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Usernames must be 3–30 characters using letters, numbers, and underscores.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              enabled: !_isSaving,
              maxLength: 30,
              decoration: InputDecoration(
                prefixText: '@ ',
                prefixStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
                hintText: 'e.g. johndoe',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _errorMessage,
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() {
                    _errorMessage = null;
                  });
                }
              },
              onSubmitted: (_) => _isSaving ? null : _handleSave(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
