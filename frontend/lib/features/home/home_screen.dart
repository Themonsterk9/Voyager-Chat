import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/services/auth_service.dart';
import '../../core/services/notification_banner_service.dart';
import '../../core/widgets/responsive_layout.dart';
import '../chat/chat_screen.dart';
import '../chat/models/conversation.dart';
import '../chat/models/message.dart';
import '../chat/services/chat_data_service.dart';
import '../users/models/user_profile.dart';
import '../users/repositories/user_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ChatDataService _chatDataService = ChatDataService.instance;
  final UserRepository _userRepository = UserRepository.instance;

  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  List<Conversation> _conversations = [];
  List<Conversation> _filteredConversations = [];
  final Map<String, UserProfile> _peerProfiles = {};
  final Map<String, Message?> _latestMessages = {};
  final Map<String, int> _unreadCounts = {};

  bool _loading = true;
  String _searchQuery = '';
  String? _selectedConversationId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await _chatDataService.getConversations();

      if (!mounted) return;

      setState(() {
        _conversations = conversations;
        _loading = false;
      });

      await _loadDetailsForConversations(conversations);
      _filterAndSortConversations();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load conversations: $error')),
      );
    }
  }

  Future<void> _loadDetailsForConversations(
    List<Conversation> conversations,
  ) async {
    for (final conversation in conversations) {
      _chatDataService.subscribeToRealtimeMessages(
        conversation.id,
        onEvent: (event) {
          if (mounted) {
            _loadDetailsForSingleConversation(conversation.id);

            final msg = event.message;
            if (msg.senderId != _userRepository.currentUser?.id) {
              NotificationBannerService.instance.showNotificationBanner(
                context,
                title: _conversationTitle(conversation),
                body: msg.content ?? 'New message',
                onTap: () => context.push('/chat/${conversation.id}'),
              );
            }
          }
        },
      );

      await _loadDetailsForSingleConversation(conversation.id);
    }
  }

  Future<void> _loadDetailsForSingleConversation(String conversationId) async {
    final currentUserId = _userRepository.currentUser?.id ?? '';

    try {
      final latest = await _chatDataService.getLatestMessage(conversationId);
      final unread = await _chatDataService.getUnreadCount(
        conversationId,
        currentUserId,
      );

      final conversation = _conversations.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => Conversation(id: conversationId, type: 'direct'),
      );

      if (conversation.type == 'direct') {
        final members = await _chatDataService.getConversationMembers(
          conversationId,
        );
        final peerMember = members.firstWhere(
          (m) => m.userId != currentUserId,
          orElse: () => members.first,
        );

        if (peerMember.userId != currentUserId) {
          final profile = await _userRepository.getUserById(peerMember.userId);
          if (profile != null && mounted) {
            _peerProfiles[conversationId] = profile;
          }
        }
      }

      if (mounted) {
        setState(() {
          _latestMessages[conversationId] = latest;
          _unreadCounts[conversationId] = unread;
        });
        _filterAndSortConversations();
      }
    } catch (_) {}
  }

  void _filterAndSortConversations() {
    final query = _searchQuery.trim().toLowerCase();
    final isArchivedTab = _tabController.index == 1;

    List<Conversation> list = _conversations.where((c) {
      final isArchived = c.archivedAt != null;
      return isArchivedTab ? isArchived : !isArchived;
    }).toList();

    if (query.isNotEmpty) {
      list = list.where((c) {
        if (c.type == 'direct') {
          final peer = _peerProfiles[c.id];
          if (peer != null) {
            final nameMatch = peer.displayNameOrUsername.toLowerCase().contains(
              query,
            );
            final userMatch = (peer.username ?? '').toLowerCase().contains(
              query,
            );
            return nameMatch || userMatch;
          }
        }
        final name = (c.name ?? '').toLowerCase();
        return name.contains(query);
      }).toList();
    }

    list.sort((a, b) {
      if (a.pinnedAt != null && b.pinnedAt == null) return -1;
      if (a.pinnedAt == null && b.pinnedAt != null) return 1;

      final timeA =
          _latestMessages[a.id]?.createdAt ??
          a.updatedAt ??
          a.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final timeB =
          _latestMessages[b.id]?.createdAt ??
          b.updatedAt ??
          b.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return timeB.compareTo(timeA);
    });

    setState(() {
      _filteredConversations = list;
    });
  }

  Future<void> _togglePin(Conversation conversation) async {
    if (conversation.pinnedAt != null) {
      await _chatDataService.unpinConversation(conversation.id);
    } else {
      await _chatDataService.pinConversation(conversation.id);
    }
    _loadConversations();
  }

  Future<void> _toggleArchive(Conversation conversation) async {
    if (conversation.archivedAt != null) {
      await _chatDataService.unarchiveConversation(conversation.id);
    } else {
      await _chatDataService.archiveConversation(conversation.id);
    }
    _loadConversations();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
    });
    await _loadConversations();
  }

  void _openNewChatMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.blueAccent),
              title: const Text('New Direct Chat'),
              onTap: () {
                Navigator.pop(context);
                context.push('/new-chat');
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add, color: Colors.greenAccent),
              title: const Text('New Group Chat'),
              onTap: () {
                Navigator.pop(context);
                context.push('/create-group');
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.orangeAccent),
              title: const Text('Join Group with Invite Code'),
              onTap: () {
                Navigator.pop(context);
                _joinByInviteCodeDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinByInviteCodeDialog() async {
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter 8-character invite code...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (code != null && code.isNotEmpty) {
      final conversation = await _chatDataService.joinGroupByInviteCode(code);
      if (conversation != null && mounted) {
        context.push('/chat/${conversation.id}');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid or expired invite code.')),
        );
      }
    }
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text(
          'Are you sure you want to delete this conversation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _chatDataService.deleteConversation(conversation.id);
      if (mounted) {
        _loadConversations();
      }
    }
  }

  String _conversationTitle(Conversation conversation) {
    if (conversation.type == 'direct') {
      final peer = _peerProfiles[conversation.id];
      if (peer != null) {
        return peer.displayNameOrUsername;
      }
    }

    final name = conversation.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    return conversation.type == 'direct' ? 'Direct Message' : 'Group Chat';
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      final hour = local.hour > 12
          ? local.hour - 12
          : (local.hour == 0 ? 12 : local.hour);
      final minute = local.minute.toString().padLeft(2, '0');
      final period = local.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }

    return '${local.month}/${local.day}/${local.year.toString().substring(2)}';
  }

  Widget _buildAvatar(Conversation conversation) {
    if (conversation.type == 'direct') {
      final peer = _peerProfiles[conversation.id];
      if (peer != null) {
        final isOnline = peer.status == 'online';

        return Stack(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: peer.avatarUrl != null
                  ? NetworkImage(peer.avatarUrl!)
                  : null,
              child: peer.avatarUrl == null
                  ? Text(
                      peer.displayNameOrUsername.substring(0, 1).toUpperCase(),
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        );
      }
    }

    return CircleAvatar(
      radius: 22,
      backgroundImage: conversation.avatarUrl != null
          ? NetworkImage(conversation.avatarUrl!)
          : null,
      child: conversation.avatarUrl == null ? const Icon(Icons.group) : null,
    );
  }

  Widget _buildSubtitle(Conversation conversation) {
    final latest = _latestMessages[conversation.id];

    if (latest != null) {
      if (latest.deletedAt != null) {
        return const Text(
          'This message was deleted',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
      return Text(
        latest.content ?? '',
        style: const TextStyle(color: Colors.grey),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (conversation.type == 'direct') {
      final peer = _peerProfiles[conversation.id];
      if (peer != null && peer.secondaryName.isNotEmpty) {
        return Text(
          peer.secondaryName,
          style: const TextStyle(color: Colors.grey),
        );
      }
    }

    return Text(conversation.type, style: const TextStyle(color: Colors.grey));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService.instance.currentUser?.id;
    final isWide = ResponsiveBreakpoints.isWideScreen(context);

    final activeSelectedId =
        _selectedConversationId ??
        (_filteredConversations.isNotEmpty
            ? _filteredConversations.first.id
            : null);

    Widget buildListContent() {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                _searchQuery = val;
                _filterAndSortConversations();
              },
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = '';
                          _filterAndSortConversations();
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: _filteredConversations.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 140),
                              const Icon(
                                Icons.forum_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No conversations found'
                                      : (_tabController.index == 1
                                            ? 'No archived conversations'
                                            : 'No conversations yet'),
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Try a different search term'
                                      : 'Tap + to start a chat or group',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _filteredConversations.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final conversation =
                                  _filteredConversations[index];
                              final latestMsg =
                                  _latestMessages[conversation.id];
                              final unreadCount =
                                  _unreadCounts[conversation.id] ?? 0;
                              final isPinned = conversation.pinnedAt != null;
                              final isSelectedInWide =
                                  isWide && activeSelectedId == conversation.id;

                              return Dismissible(
                                key: Key(conversation.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: Colors.redAccent,
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                confirmDismiss: (dir) async {
                                  _deleteConversation(conversation);
                                  return false;
                                },
                                child: Container(
                                  color: isSelectedInWide
                                      ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: 0.3)
                                      : null,
                                  child: ListTile(
                                    leading: _buildAvatar(conversation),
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              if (isPinned)
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                    right: 6,
                                                  ),
                                                  child: Icon(
                                                    Icons.push_pin,
                                                    size: 16,
                                                    color: Colors.amberAccent,
                                                  ),
                                                ),
                                              Expanded(
                                                child: Text(
                                                  _conversationTitle(
                                                    conversation,
                                                  ),
                                                  style: TextStyle(
                                                    fontWeight: unreadCount > 0
                                                        ? FontWeight.bold
                                                        : FontWeight.w600,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (latestMsg != null)
                                          Text(
                                            _formatTimestamp(
                                              latestMsg.createdAt,
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: unreadCount > 0
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                  : Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Row(
                                      children: [
                                        Expanded(
                                          child: _buildSubtitle(conversation),
                                        ),
                                        if (unreadCount > 0)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              unreadCount > 99
                                                  ? '99+'
                                                  : '$unreadCount',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    onLongPress: () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (context) => SafeArea(
                                          child: Wrap(
                                            children: [
                                              ListTile(
                                                leading: Icon(
                                                  isPinned
                                                      ? Icons.push_pin_outlined
                                                      : Icons.push_pin,
                                                ),
                                                title: Text(
                                                  isPinned
                                                      ? 'Unpin Conversation'
                                                      : 'Pin Conversation',
                                                ),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _togglePin(conversation);
                                                },
                                              ),
                                              ListTile(
                                                leading: Icon(
                                                  conversation.archivedAt !=
                                                          null
                                                      ? Icons.unarchive
                                                      : Icons.archive,
                                                ),
                                                title: Text(
                                                  conversation.archivedAt !=
                                                          null
                                                      ? 'Unarchive Conversation'
                                                      : 'Archive Conversation',
                                                ),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _toggleArchive(conversation);
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.delete,
                                                  color: Colors.redAccent,
                                                ),
                                                title: const Text(
                                                  'Delete Conversation',
                                                  style: TextStyle(
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _deleteConversation(
                                                    conversation,
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    onTap: () async {
                                      if (isWide) {
                                        setState(() {
                                          _selectedConversationId =
                                              conversation.id;
                                        });
                                      } else {
                                        await context.push(
                                          '/chat/${conversation.id}',
                                        );
                                        if (mounted) {
                                          _loadConversations();
                                        }
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voyager Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              if (currentUserId != null) {
                context.push('/profile/$currentUserId');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Archived'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewChatMenu,
        child: const Icon(Icons.add),
      ),
      body: !isWide
          ? buildListContent()
          : Row(
              children: [
                SizedBox(width: 360, child: buildListContent()),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: activeSelectedId != null
                      ? KeyedSubtree(
                          key: ValueKey(activeSelectedId),
                          child: ChatScreen(conversationId: activeSelectedId),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Select a conversation to start messaging',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
