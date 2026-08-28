import 'dart:async';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/models/auth_user.dart';
import '../../core/auth/services/auth_service.dart';
import '../../core/media/media_models.dart';
import '../../core/media/media_service.dart';
import '../../core/permissions/permission_helper.dart';
import '../../core/network/services/storage_service.dart';
import '../users/models/user_profile.dart';
import '../users/repositories/user_repository.dart';
import 'models/message.dart';
import 'models/message_reaction.dart';
import 'repositories/chat_repository.dart';
import 'services/ai_assistant_service.dart';
import 'services/chat_data_service.dart';
import 'services/realtime_message_service.dart';
import 'services/typing_indicator_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatDataService _chatDataService = ChatDataService.instance;
  final UserRepository _userRepository = UserRepository.instance;
  final ChatRepository _chatRepository = ChatRepository.instance;
  final TypingIndicatorService _typingService = TypingIndicatorService.instance;
  final AiAssistantService _aiService = AiAssistantService.instance;

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  Uint8List? _selectedAttachmentBytes;
  String? _selectedAttachmentName;
  String? _selectedAttachmentMimeType;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<Message> _messages = [];
  final Map<String, List<MessageReaction>> _messageReactions = {};
  UserProfile? _peerProfile;
  List<UserProfile> _groupMembersProfiles = [];
  Message? _replyingToMessage;

  bool _loading = true;
  bool _sending = false;
  bool _isOffline = false;
  bool _isSearchingInChat = false;
  String _peerTypingUser = '';

  // Mention autocomplete popover state
  bool _showMentionList = false;
  List<UserProfile> _mentionCandidates = [];

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  AuthUser? get _currentUser => AuthService.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadChatDetails();
    _subscribeToRealtime();
    _listenConnectivity();
    _markRead();
    _subscribeTyping();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final draft = await _chatDataService.getDraftText(widget.conversationId);
    if (draft != null && draft.isNotEmpty && mounted) {
      _messageController.text = draft;
    }
  }

  void _subscribeTyping() {
    _typingService.subscribeToTyping(
      widget.conversationId,
      onTypingChanged: (userId, isTyping) {
        if (!mounted) return;
        setState(() {
          _peerTypingUser = isTyping ? 'Peer is typing...' : '';
        });
      },
    );
  }

  void _listenConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final isOffline = results.every((r) => r == ConnectivityResult.none);
      if (mounted) {
        setState(() {
          _isOffline = isOffline;
        });
      }
    });
  }

  void _markRead() {
    _chatDataService.markConversationAsRead(widget.conversationId);
  }

  void _subscribeToRealtime() {
    _chatDataService.subscribeToRealtimeMessages(
      widget.conversationId,
      onEvent: _handleRealtimeEvent,
    );
  }

  void _handleRealtimeEvent(RealtimeMessageEvent event) {
    if (!mounted) return;

    final incomingMsg = event.message;

    if (event.type == RealtimeEventType.insert) {
      final existingIndex = _messages.indexWhere(
        (m) =>
            m.id == incomingMsg.id ||
            (incomingMsg.clientMessageId != null &&
                m.clientMessageId == incomingMsg.clientMessageId),
      );

      setState(() {
        if (existingIndex != -1) {
          _messages[existingIndex] = incomingMsg;
        } else {
          _messages.add(incomingMsg);
        }
      });

      _loadReactionsForMessage(incomingMsg.id);
      _scrollToBottom();

      if (incomingMsg.senderId != _currentUser?.id) {
        _chatRepository.markMessageAsRead(messageId: incomingMsg.id);
        _markRead();
      }
    } else if (event.type == RealtimeEventType.update) {
      final existingIndex = _messages.indexWhere((m) => m.id == incomingMsg.id);

      if (existingIndex != -1) {
        setState(() {
          _messages[existingIndex] = incomingMsg;
        });
      }
    } else if (event.type == RealtimeEventType.delete) {
      final existingIndex = _messages.indexWhere((m) => m.id == incomingMsg.id);

      if (existingIndex != -1) {
        setState(() {
          _messages[existingIndex] = _messages[existingIndex].copyWith(
            deletedAt: DateTime.now().toUtc(),
          );
        });
      }
    }
  }

  Future<void> _loadChatDetails() async {
    await Future.wait([_loadMessages(), _loadPeerProfile()]);
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatDataService.getMessages(
        widget.conversationId,
      );

      if (!mounted) return;

      setState(() {
        _messages = messages;
        _loading = false;
      });

      for (final m in messages) {
        _loadReactionsForMessage(m.id);
      }

      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load messages: $error')),
      );
    }
  }

  Future<void> _loadReactionsForMessage(String messageId) async {
    try {
      final reactions = await _chatDataService.getReactions(messageId);
      if (mounted && reactions.isNotEmpty) {
        setState(() {
          _messageReactions[messageId] = reactions;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPeerProfile() async {
    try {
      final members = await _chatDataService.getConversationMembers(
        widget.conversationId,
      );

      final currentUserId = _currentUser?.id;
      final profiles = <UserProfile>[];

      for (final m in members) {
        final p = await _userRepository.getUserById(m.userId);
        if (p != null) profiles.add(p);
      }

      final peerMember = members.firstWhere(
        (m) => m.userId != currentUserId,
        orElse: () => members.first,
      );

      if (peerMember.userId != currentUserId) {
        final profile = await _userRepository.getUserById(peerMember.userId);
        if (profile != null && mounted) {
          setState(() {
            _peerProfile = profile;
            _groupMembersProfiles = profiles;
          });
        }
      } else if (mounted) {
        setState(() {
          _groupMembersProfiles = profiles;
        });
      }
    } catch (_) {}
  }

  void _onComposerTextChanged(String value) {
    if (value.isNotEmpty) {
      _typingService.sendTypingState(widget.conversationId, true);
    }

    _chatDataService.saveDraftText(widget.conversationId, value);

    // Mention triggers on `@`
    final lastAt = value.lastIndexOf('@');
    if (lastAt != -1 && (lastAt == 0 || value[lastAt - 1] == ' ')) {
      final query = value.substring(lastAt + 1).toLowerCase();
      final candidates = _groupMembersProfiles.where((p) {
        final uname = (p.username ?? '').toLowerCase();
        final dname = p.displayNameOrUsername.toLowerCase();
        return uname.contains(query) || dname.contains(query);
      }).toList();

      setState(() {
        _showMentionList = candidates.isNotEmpty;
        _mentionCandidates = candidates;
      });
    } else {
      if (_showMentionList) {
        setState(() {
          _showMentionList = false;
        });
      }
    }
  }

  void _insertMention(UserProfile user) {
    final value = _messageController.text;
    final lastAt = value.lastIndexOf('@');
    if (lastAt != -1) {
      final prefix = value.substring(0, lastAt);
      final mentionText = '@${user.username ?? user.displayNameOrUsername} ';
      _messageController.text = '$prefix$mentionText';
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    }
    setState(() {
      _showMentionList = false;
    });
  }

  Future<void> _pickImageAttachment() async {
    final hasPermission = await PermissionHelper.instance.ensureMediaPermission(
      context,
      title: 'Photos & Media Permission Required',
      rationale:
          'Voyager Chat requires permission to access your photos and media to attach images to chat messages.',
    );
    if (!hasPermission) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File exceeds maximum limit of 10 MB.')),
        );
        return;
      }

      final ext = picked.name.split('.').last.toLowerCase();
      final mimeType = ext == 'png'
          ? 'image/png'
          : (ext == 'gif' ? 'image/gif' : 'image/jpeg');

      setState(() {
        _selectedAttachmentBytes = bytes;
        _selectedAttachmentName = picked.name;
        _selectedAttachmentMimeType = mimeType;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
    }
  }

  Future<void> _pickFileAttachment() async {
    final hasPermission = await PermissionHelper.instance.ensureMediaPermission(
      context,
      title: 'Photos & Media Permission Required',
      rationale:
          'Voyager Chat requires permission to access media files to attach them to chat messages.',
    );
    if (!hasPermission) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickMedia();
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File exceeds maximum limit of 10 MB.')),
        );
        return;
      }

      final ext = picked.name.split('.').last.toLowerCase();
      final isImage = ['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext);
      final mimeType = isImage ? 'image/$ext' : 'application/octet-stream';

      setState(() {
        _selectedAttachmentBytes = bytes;
        _selectedAttachmentName = picked.name;
        _selectedAttachmentMimeType = mimeType;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not pick file: $e')));
    }
  }

  Future<void> _sendMessage({
    String messageType = 'text',
    String? customContent,
    DateTime? scheduledAt,
  }) async {
    if (_selectedAttachmentBytes != null) {
      final bytes = _selectedAttachmentBytes!;
      final name =
          _selectedAttachmentName ??
          'attachment_${DateTime.now().millisecondsSinceEpoch}.png';
      final mimeType = _selectedAttachmentMimeType ?? 'image/png';
      final isImage = mimeType.startsWith('image/');

      setState(() {
        _sending = true;
        _selectedAttachmentBytes = null;
        _selectedAttachmentName = null;
        _selectedAttachmentMimeType = null;
      });

      _messageController.clear();

      try {
        final storageUrl = await StorageService.instance.uploadChatAttachment(
          conversationId: widget.conversationId,
          fileBytes: bytes,
          fileName: name,
        );

        final finalContent = storageUrl ?? 'Image Attachment (Offline)';
        final finalType = isImage ? 'image' : 'file';

        final message = await _chatDataService.sendMessage(
          conversationId: widget.conversationId,
          content: finalContent,
          messageType: finalType,
          replyToMessageId: _replyingToMessage?.id,
          scheduledAt: scheduledAt,
        );

        await MediaService.instance.saveAttachment(
          MediaAttachment(
            id: const Uuid().v4(),
            messageId: message.id,
            fileName: name,
            fileSize: bytes.length,
            mimeType: mimeType,
            storageUrl: storageUrl,
            isEncrypted: true,
          ),
        );

        if (!mounted) return;
        setState(() {
          _messages.add(message);
          _sending = false;
        });
        _scrollToBottom();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _sending = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Attachment upload failed: $e')));
      }
      return;
    }

    final content = customContent ?? _messageController.text.trim();

    if (content.isEmpty || _sending) return;

    if (customContent == null) {
      _messageController.clear();
      _typingService.sendTypingState(widget.conversationId, false);
      _chatDataService.saveDraftText(widget.conversationId, '');
    }

    final replyId = _replyingToMessage?.id;

    setState(() {
      _sending = true;
      _replyingToMessage = null;
      _showMentionList = false;
    });

    try {
      final message = await _chatDataService.sendMessage(
        conversationId: widget.conversationId,
        content: content,
        messageType: messageType,
        replyToMessageId: replyId,
        scheduledAt: scheduledAt,
      );

      if (!mounted) return;

      final existingIndex = _messages.indexWhere(
        (m) =>
            m.id == message.id ||
            (message.clientMessageId != null &&
                m.clientMessageId == message.clientMessageId),
      );

      setState(() {
        if (existingIndex != -1) {
          _messages[existingIndex] = message;
        } else {
          _messages.add(message);
        }
        _sending = false;
      });

      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _sending = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to send message: $error')));
    }
  }

  Future<void> _sendAttachment() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Colors.blueAccent),
              title: const Text('Pick Image from Gallery'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file,
                color: Colors.orangeAccent,
              ),
              title: const Text('Pick Document / File'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.mic, color: Colors.greenAccent),
              title: const Text('Send Voice Note (Demo)'),
              onTap: () => Navigator.pop(context, 'voice'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.purpleAccent),
              title: const Text('Schedule Message'),
              onTap: () => Navigator.pop(context, 'schedule'),
            ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    if (action == 'image') {
      await _pickImageAttachment();
    } else if (action == 'file') {
      await _pickFileAttachment();
    } else if (action == 'voice') {
      final hasMic = await PermissionHelper.instance.ensurePermission(
        context,
        Permission.microphone,
        title: 'Microphone Permission Required',
        rationale:
            'Voyager Chat requires microphone access to record and send voice notes.',
      );
      if (hasMic) {
        _sendMessage(
          messageType: 'voice',
          customContent: 'Voice note (0:15)',
        );
      }
    } else if (action == 'schedule') {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(hours: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 30)),
      );
      if (pickedDate != null && mounted) {
        final text = _messageController.text.trim();
        if (text.isNotEmpty) {
          _sendMessage(scheduledAt: pickedDate);
        }
      }
    }
  }

  Future<void> _toggleReaction(Message message, String emoji) async {
    final messageId = message.id;
    final currentUserId = _currentUser?.id ?? '';
    final existingReactions = _messageReactions[messageId] ?? [];

    final myExisting = existingReactions.firstWhere(
      (r) => r.userId == currentUserId && r.emoji == emoji,
      orElse: () =>
          const MessageReaction(id: '', messageId: '', userId: '', emoji: ''),
    );

    if (myExisting.id.isNotEmpty) {
      await _chatDataService.removeReaction(reactionId: myExisting.id);
      setState(() {
        _messageReactions[messageId] = existingReactions
            .where((r) => r.id != myExisting.id)
            .toList();
      });
    } else {
      final newReaction = await _chatDataService.addReaction(
        messageId: messageId,
        emoji: emoji,
      );

      setState(() {
        _messageReactions[messageId] = [...existingReactions, newReaction];
      });
    }
  }

  Future<void> _editMessage(Message message) async {
    final controller = TextEditingController(text: message.content ?? '');

    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Edit your message...'),
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

    if (newText != null && newText.isNotEmpty && newText != message.content) {
      try {
        final updated = await _chatDataService.editMessage(
          messageId: message.id,
          newContent: newText,
        );

        if (!mounted) return;

        final idx = _messages.indexWhere((m) => m.id == message.id);
        if (idx != -1) {
          setState(() {
            _messages[idx] = updated;
          });
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to edit message: $error')),
        );
      }
    }
  }

  Future<void> _deleteMessage(Message message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
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
      try {
        await _chatDataService.deleteMessage(message.id);

        if (!mounted) return;

        final idx = _messages.indexWhere((m) => m.id == message.id);
        if (idx != -1) {
          setState(() {
            _messages[idx] = _messages[idx].copyWith(
              deletedAt: DateTime.now().toUtc(),
            );
          });
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $error')),
        );
      }
    }
  }

  void _showOptions(Message message) {
    final isMe = message.senderId == _currentUser?.id;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                  return IconButton(
                    icon: Text(emoji, style: const TextStyle(fontSize: 24)),
                    onPressed: () {
                      Navigator.pop(context);
                      _toggleReaction(message, emoji);
                    },
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _replyingToMessage = message;
                });
                _focusNode.requestFocus();
              },
            ),
            if (isMe && message.deletedAt == null) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Message'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text(
                  'Delete Message',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _chatDataService.unsubscribeFromRealtimeMessages(
      widget.conversationId,
      onEvent: _handleRealtimeEvent,
    );
    _typingService.unsubscribeFromTyping(widget.conversationId);
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Widget _buildAppBarTitle() {
    if (_peerProfile != null) {
      final isOnline = _peerProfile!.status == 'online';

      return GestureDetector(
        onTap: () => context.push('/chat-details/${widget.conversationId}'),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: _peerProfile!.avatarUrl != null
                      ? NetworkImage(_peerProfile!.avatarUrl!)
                      : null,
                  child: _peerProfile!.avatarUrl == null
                      ? Text(
                          _peerProfile!.displayNameOrUsername
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(fontSize: 14),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _peerProfile!.displayNameOrUsername,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _peerTypingUser.isNotEmpty
                        ? 'typing...'
                        : (isOnline ? 'Online' : 'Offline'),
                    style: TextStyle(
                      fontSize: 12,
                      color: _peerTypingUser.isNotEmpty || isOnline
                          ? Colors.greenAccent
                          : Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Text(_peerProfile?.displayNameOrUsername ?? 'Voyager Chat');
  }

  Widget _buildReplyPreviewBubble(String replyId) {
    final parent = _messages.firstWhere(
      (m) => m.id == replyId,
      orElse: () => Message(
        id: replyId,
        conversationId: '',
        senderId: '',
        content: 'Original message',
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Colors.blueAccent, width: 3),
        ),
      ),
      child: Text(
        parent.content ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Colors.white70),
      ),
    );
  }

  Widget _buildFormattedText(String text, bool isMe) {
    final words = text.split(' ');
    final spans = <InlineSpan>[];

    for (final word in words) {
      if (word.startsWith('@') && word.length > 1) {
        spans.add(
          TextSpan(
            text: '$word ',
            style: const TextStyle(
              color: Colors.lightBlueAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '$word ',
            style: TextStyle(
              color: isMe
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildMessageContent(Message message, bool isMe) {
    if (message.deletedAt != null) {
      return const Text(
        'This message was deleted',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    final isEdited = message.editedAt != null;

    if (message.messageType == 'image' && message.content != null) {
      final isPending = message.content == 'Image Attachment (Offline)';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (!isPending) {
                context.push(
                  '/media/view',
                  extra: MediaAttachment(
                    id: message.id,
                    messageId: message.id,
                    fileName: 'Image Attachment',
                    fileSize: 1024,
                    mimeType: 'image/png',
                    storageUrl: message.content,
                  ),
                );
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isPending
                  ? Container(
                      width: 200,
                      height: 140,
                      color: Colors.black38,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.cloud_upload_outlined,
                            color: Colors.amberAccent,
                            size: 36,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Upload Pending',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Image.network(
                      message.content!,
                      width: 220,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 220,
                          height: 140,
                          color: Colors.black26,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 220,
                        height: 120,
                        color: Colors.black38,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 36,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          if (isEdited)
            const Text(
              '(edited)',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
        ],
      );
    }

    if (message.messageType == 'file') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, color: Colors.orangeAccent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message.content ?? 'Attachment File',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isMe ? Colors.white : Colors.white70),
            ),
          ),
        ],
      );
    }

    if (message.messageType == 'voice') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow,
            color: isMe ? Colors.white : Colors.greenAccent,
          ),
          const SizedBox(width: 8),
          Container(width: 80, height: 4, color: Colors.white38),
          const SizedBox(width: 8),
          const Text('0:15', style: TextStyle(fontSize: 12)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.replyToMessageId != null)
          _buildReplyPreviewBubble(message.replyToMessageId!),
        _buildFormattedText(message.content ?? '', isMe),
        if (isEdited) ...[
          const SizedBox(height: 2),
          Text(
            '(edited)',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: isMe ? Colors.white70 : Colors.grey,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReactionsRow(String messageId) {
    final reactions = _messageReactions[messageId] ?? [];
    if (reactions.isEmpty) return const SizedBox.shrink();

    final Map<String, int> counts = {};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }

    return Wrap(
      spacing: 4,
      children: counts.entries.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 0.5),
          ),
          child: Text(
            '${e.key} ${e.value}',
            style: const TextStyle(fontSize: 11),
          ),
        );
      }).toList(),
    );
  }

  bool _shouldShowDateHeader(int index) {
    if (index == 0) return true;
    final cur = _messages[index].createdAt;
    final prev = _messages[index - 1].createdAt;
    if (cur == null || prev == null) return false;

    final curLocal = cur.toLocal();
    final prevLocal = prev.toLocal();
    return curLocal.year != prevLocal.year ||
        curLocal.month != prevLocal.month ||
        curLocal.day != prevLocal.day;
  }

  String _formatDateHeader(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return 'Yesterday';
    }

    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUser?.id;

    final displayedMessages =
        _isSearchingInChat && _searchController.text.trim().isNotEmpty
        ? _messages
              .where(
                (m) => (m.content ?? '').toLowerCase().contains(
                  _searchController.text.trim().toLowerCase(),
                ),
              )
              .toList()
        : _messages;

    final smartReplies = _aiService.generateSmartReplies(
      _messages.isNotEmpty ? _messages.last : null,
    );

    return Scaffold(
      appBar: AppBar(
        title: _isSearchingInChat
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search messages...',
                  border: InputBorder.none,
                ),
              )
            : _buildAppBarTitle(),
        actions: [
          IconButton(
            icon: Icon(_isSearchingInChat ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchingInChat = !_isSearchingInChat;
                if (!_isSearchingInChat) {
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () =>
                context.push('/chat-details/${widget.conversationId}'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isOffline)
            Container(
              width: double.infinity,
              color: Colors.orange.shade800,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              child: const Text(
                'You are offline. Messages will sync when reconnected.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : displayedMessages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages found 👋\nSay hello to start chatting!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: displayedMessages.length,
                    itemBuilder: (context, index) {
                      final message = displayedMessages[index];
                      final isMe = message.senderId == currentUserId;
                      final showDateHeader = _shouldShowDateHeader(index);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDateHeader && message.createdAt != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatDateHeader(message.createdAt!),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          GestureDetector(
                            onLongPress: () => _showOptions(message),
                            child: Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                          0.75,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 2),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                          : Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: isMe
                                            ? const Radius.circular(16)
                                            : const Radius.circular(4),
                                        bottomRight: isMe
                                            ? const Radius.circular(4)
                                            : const Radius.circular(16),
                                      ),
                                    ),
                                    child: _buildMessageContent(message, isMe),
                                  ),
                                  _buildReactionsRow(message.id),
                                  const SizedBox(height: 6),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Mention autocomplete popover list
          if (_showMentionList)
            Container(
              height: 120,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ListView.builder(
                itemCount: _mentionCandidates.length,
                itemBuilder: (context, index) {
                  final candidate = _mentionCandidates[index];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundImage: candidate.avatarUrl != null
                          ? NetworkImage(candidate.avatarUrl!)
                          : null,
                      child: candidate.avatarUrl == null
                          ? Text(
                              candidate.displayNameOrUsername.substring(0, 1),
                            )
                          : null,
                    ),
                    title: Text(candidate.displayNameOrUsername),
                    subtitle: Text(
                      '@${candidate.username ?? candidate.displayNameOrUsername}',
                    ),
                    onTap: () => _insertMention(candidate),
                  );
                },
              ),
            ),

          // Smart reply chips
          if (smartReplies.isNotEmpty && !_showMentionList)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: smartReplies.map((reply) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(reply, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _sendMessage(customContent: reply);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

          if (_replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 20, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to: ${_replyingToMessage!.content ?? 'Attachment'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _replyingToMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          _buildAttachmentPreviewBar(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _sendAttachment,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      onChanged: _onComposerTextChanged,
                      onSubmitted: (_) {
                        if (!_sending) {
                          _sendMessage();
                        }
                      },
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : () => _sendMessage(),
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreviewBar() {
    if (_selectedAttachmentBytes == null) return const SizedBox.shrink();

    final isImage = _selectedAttachmentMimeType?.startsWith('image/') ?? false;
    final sizeMb = (_selectedAttachmentBytes!.length / (1024 * 1024))
        .toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                _selectedAttachmentBytes!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            )
          else
            const Icon(
              Icons.insert_drive_file,
              color: Colors.orangeAccent,
              size: 36,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedAttachmentName ?? 'Attachment',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$sizeMb MB • Ready to send',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _selectedAttachmentBytes = null;
                _selectedAttachmentName = null;
                _selectedAttachmentMimeType = null;
              });
            },
          ),
        ],
      ),
    );
  }
}
