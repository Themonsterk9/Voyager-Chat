import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/services/auth_service.dart';
import '../../users/models/user_profile.dart';
import '../../users/repositories/user_repository.dart';
import '../models/conversation.dart';
import '../models/conversation_member.dart';
import '../models/message.dart';
import '../services/chat_data_service.dart';

class ConversationDetailsScreen extends StatefulWidget {
  const ConversationDetailsScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ConversationDetailsScreen> createState() =>
      _ConversationDetailsScreenState();
}

class _ConversationDetailsScreenState extends State<ConversationDetailsScreen>
    with SingleTickerProviderStateMixin {
  final ChatDataService _chatDataService = ChatDataService.instance;
  final UserRepository _userRepository = UserRepository.instance;

  late final TabController _tabController;

  Conversation? _conversation;
  List<ConversationMember> _members = [];
  Map<String, UserProfile> _memberProfiles = {};
  List<Message> _sharedMedia = [];
  List<Message> _sharedFiles = [];

  bool _loading = true;
  bool _isMuted = false;

  String? get _currentUserId => AuthService.instance.currentUser?.id;

  ConversationMember? get _myMember => _members.firstWhere(
    (m) => m.userId == _currentUserId,
    orElse: () => const ConversationMember(conversationId: '', userId: ''),
  );

  bool get _isOwnerOrAdmin =>
      _myMember?.role == 'owner' || _myMember?.role == 'admin';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllDetails();
  }

  Future<void> _loadAllDetails() async {
    try {
      final conversations = await _chatDataService.getConversations();
      final conv = conversations.firstWhere(
        (c) => c.id == widget.conversationId,
        orElse: () => Conversation(id: widget.conversationId, type: 'group'),
      );

      final members = await _chatDataService.getConversationMembers(
        widget.conversationId,
      );
      final profiles = <String, UserProfile>{};

      for (final m in members) {
        final p = await _userRepository.getUserById(m.userId);
        if (p != null) {
          profiles[m.userId] = p;
        }
      }

      final messages = await _chatDataService.getMessages(
        widget.conversationId,
      );
      final media = messages
          .where((m) => m.messageType == 'image' && m.content != null)
          .toList();
      final files = messages
          .where((m) => m.messageType == 'file' && m.content != null)
          .toList();

      final myMember = members.firstWhere(
        (m) => m.userId == _currentUserId,
        orElse: () => const ConversationMember(conversationId: '', userId: ''),
      );

      if (mounted) {
        setState(() {
          _conversation = conv;
          _members = members;
          _memberProfiles = profiles;
          _sharedMedia = media;
          _sharedFiles = files;
          _isMuted = myMember.isMuted;
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

  Future<void> _toggleMute(bool value) async {
    setState(() {
      _isMuted = value;
    });
    await _chatDataService.toggleMuteConversation(widget.conversationId, value);
  }

  Future<void> _copyInviteCode() async {
    final code = _conversation?.inviteCode;
    if (code != null) {
      await Clipboard.setData(ClipboardData(text: code));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Invite code copied: $code')));
      }
    }
  }

  Future<void> _addMemberDialog() async {
    final allUsers = await _userRepository.getRegisteredUsers();
    final existingIds = _members.map((m) => m.userId).toSet();
    final eligible = allUsers
        .where((u) => !existingIds.contains(u.id))
        .toList();

    if (!mounted) return;

    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All registered users are already members.'),
        ),
      );
      return;
    }

    final selectedUser = await showDialog<UserProfile>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add Member'),
        children: eligible.map((user) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, user),
            child: Row(
              children: [
                CircleAvatar(
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
                const SizedBox(width: 12),
                Expanded(child: Text(user.displayNameOrUsername)),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selectedUser != null) {
      await _chatDataService.addMemberToGroup(
        widget.conversationId,
        selectedUser.id,
      );
      _loadAllDetails();
    }
  }

  Future<void> _showMemberOptions(ConversationMember member) async {
    if (!_isOwnerOrAdmin || member.userId == _currentUserId) return;

    final profile = _memberProfiles[member.userId];

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (member.role != 'admin')
              ListTile(
                leading: const Icon(Icons.security, color: Colors.blueAccent),
                title: const Text('Make Admin'),
                onTap: () async {
                  Navigator.pop(context);
                  await _chatDataService.updateMemberRole(
                    widget.conversationId,
                    member.userId,
                    'admin',
                  );
                  _loadAllDetails();
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.redAccent),
              title: Text(
                'Remove ${profile?.displayNameOrUsername ?? 'Member'}',
                style: const TextStyle(color: Colors.redAccent),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _chatDataService.removeMember(
                  widget.conversationId,
                  member.userId,
                );
                _loadAllDetails();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true && _currentUserId != null) {
      await _chatDataService.removeMember(
        widget.conversationId,
        _currentUserId!,
      );
      if (mounted) {
        context.go('/home');
      }
    }
  }

  Future<void> _blockUser() async {
    final peerMember = _members.firstWhere(
      (m) => m.userId != _currentUserId,
      orElse: () => _members.first,
    );
    final peerProfile = _memberProfiles[peerMember.userId];
    if (peerProfile == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block ${peerProfile.displayNameOrUsername}?'),
        content: const Text('They will no longer be able to message you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _chatDataService.blockUser(peerProfile.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${peerProfile.displayNameOrUsername} has been blocked.',
            ),
          ),
        );
        context.go('/home');
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGroup = _conversation?.type == 'group';
    final peerMember = _members.firstWhere(
      (m) => m.userId != _currentUserId,
      orElse: () => const ConversationMember(conversationId: '', userId: ''),
    );
    final peerProfile = _memberProfiles[peerMember.userId];

    final title = isGroup
        ? (_conversation?.name ?? 'Group Chat')
        : (peerProfile?.displayNameOrUsername ?? 'Voyager User');

    final avatarUrl = isGroup
        ? _conversation?.avatarUrl
        : peerProfile?.avatarUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Details'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Media'),
            Tab(text: 'Files'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Details Tab
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(
                                title.substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontSize: 32),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isGroup)
                      Center(
                        child: Text(
                          '${_members.length} members',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    else if (peerProfile?.secondaryName.isNotEmpty == true)
                      Center(
                        child: Text(
                          peerProfile!.secondaryName,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Mute Notifications'),
                      value: _isMuted,
                      onChanged: _toggleMute,
                    ),
                    if (isGroup && _conversation?.inviteCode != null)
                      ListTile(
                        leading: const Icon(Icons.link),
                        title: const Text('Group Invite Code'),
                        subtitle: Text(_conversation!.inviteCode!),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: _copyInviteCode,
                        ),
                      ),
                    if (isGroup)
                      ListTile(
                        leading: const Icon(
                          Icons.groups,
                          color: Colors.indigoAccent,
                        ),
                        title: const Text('Group Polls & Social Features'),
                        subtitle: const Text('Polls, Events, Announcements'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '/group-details/${widget.conversationId}',
                        ),
                      ),
                    const Divider(),
                    if (isGroup) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'MEMBERS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            if (_isOwnerOrAdmin)
                              TextButton.icon(
                                icon: const Icon(Icons.person_add, size: 18),
                                label: const Text('Add Member'),
                                onPressed: _addMemberDialog,
                              ),
                          ],
                        ),
                      ),
                      ..._members.map((m) {
                        final prof = _memberProfiles[m.userId];
                        final isMe = m.userId == _currentUserId;

                        return ListTile(
                          onTap: () => _showMemberOptions(m),
                          leading: CircleAvatar(
                            backgroundImage: prof?.avatarUrl != null
                                ? NetworkImage(prof!.avatarUrl!)
                                : null,
                            child: prof?.avatarUrl == null
                                ? Text(
                                    prof?.displayNameOrUsername
                                            .substring(0, 1)
                                            .toUpperCase() ??
                                        'U',
                                  )
                                : null,
                          ),
                          title: Text(
                            isMe
                                ? '${prof?.displayNameOrUsername ?? 'User'} (You)'
                                : (prof?.displayNameOrUsername ?? 'User'),
                          ),
                          subtitle: prof?.secondaryName.isNotEmpty == true
                              ? Text(prof!.secondaryName)
                              : null,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: m.role == 'owner'
                                  ? Colors.amber.withValues(alpha: 0.2)
                                  : (m.role == 'admin'
                                        ? Colors.blue.withValues(alpha: 0.2)
                                        : Colors.grey.withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              m.role.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: m.role == 'owner'
                                    ? Colors.amberAccent
                                    : (m.role == 'admin'
                                          ? Colors.blueAccent
                                          : Colors.grey),
                              ),
                            ),
                          ),
                        );
                      }),
                      const Divider(),
                      ListTile(
                        leading: const Icon(
                          Icons.exit_to_app,
                          color: Colors.redAccent,
                        ),
                        title: const Text(
                          'Leave Group',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: _leaveGroup,
                      ),
                    ] else ...[
                      ListTile(
                        leading: const Icon(
                          Icons.block,
                          color: Colors.redAccent,
                        ),
                        title: const Text(
                          'Block User',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        onTap: _blockUser,
                      ),
                    ],
                  ],
                ),

                // Shared Media Tab
                _sharedMedia.isEmpty
                    ? const Center(child: Text('No shared media yet'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: _sharedMedia.length,
                        itemBuilder: (context, index) {
                          final msg = _sharedMedia[index];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              msg.content!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey.shade800,
                                    child: const Icon(Icons.broken_image),
                                  ),
                            ),
                          );
                        },
                      ),

                // Shared Files Tab
                _sharedFiles.isEmpty
                    ? const Center(child: Text('No shared files yet'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _sharedFiles.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final msg = _sharedFiles[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.insert_drive_file,
                              color: Colors.orangeAccent,
                            ),
                            title: Text(
                              msg.content ?? 'File',
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              msg.createdAt?.toLocal().toString().substring(
                                    0,
                                    16,
                                  ) ??
                                  '',
                            ),
                          );
                        },
                      ),
              ],
            ),
    );
  }
}
