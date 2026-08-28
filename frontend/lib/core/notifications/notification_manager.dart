import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import 'notification_models.dart';

class NotificationPayload {
  const NotificationPayload({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.deepLinkRoute,
    this.conversationId,
    required this.timestamp,
    this.isEncrypted = false,
  });

  final String id;
  final NotificationCategory category;
  final String title;
  final String body;
  final String deepLinkRoute;
  final String? conversationId;
  final DateTime timestamp;
  final bool isEncrypted;
}

class NotificationManager {
  NotificationManager._();

  static final NotificationManager instance = NotificationManager._();

  final NotificationSettings settings = NotificationSettings();
  NotificationPermissionState _permissionState =
      NotificationPermissionState.granted;

  final Set<String> _mutedConversationIds = {};
  final Set<String> _processedEventIds = {};

  final _notificationStreamController =
      StreamController<NotificationPayload>.broadcast();

  Stream<NotificationPayload> get notificationStream =>
      _notificationStreamController.stream;
  NotificationPermissionState get permissionState => _permissionState;

  Future<void> initialize() async {
    await _loadMutedConversations();
  }

  Future<void> _loadMutedConversations() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'notification_preferences',
        where: 'is_muted = 1',
      );
      _mutedConversationIds.clear();
      for (final r in rows) {
        _mutedConversationIds.add(r['conversation_id'] as String);
      }
    } catch (_) {}
  }

  Future<void> setConversationMuted(String conversationId, bool isMuted) async {
    if (isMuted) {
      _mutedConversationIds.add(conversationId);
    } else {
      _mutedConversationIds.remove(conversationId);
    }

    try {
      final db = await AppDatabase.instance.database;
      await db.insert('notification_preferences', {
        'conversation_id': conversationId,
        'is_muted': isMuted ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  bool isConversationMuted(String conversationId) {
    return _mutedConversationIds.contains(conversationId);
  }

  Future<NotificationPermissionState> requestPermission() async {
    if (kIsWeb) {
      _permissionState = NotificationPermissionState.granted;
      return _permissionState;
    }

    final status = await Permission.notification.request();
    if (status.isGranted || status.isLimited) {
      _permissionState = NotificationPermissionState.granted;
    } else if (status.isPermanentlyDenied || status.isRestricted) {
      _permissionState = NotificationPermissionState.denied;
    } else {
      _permissionState = NotificationPermissionState.denied;
    }
    return _permissionState;
  }

  bool shouldNotify({
    required NotificationCategory category,
    String? conversationId,
  }) {
    if (_permissionState != NotificationPermissionState.granted) return false;

    // Check quiet hours
    final isQuiet = settings.quietHours.isTimeWithinQuietHours(DateTime.now());
    if (isQuiet) {
      if (category == NotificationCategory.emergency &&
          settings.quietHours.allowEmergencyCalls) {
        return true;
      }
      return false; // Suppress non-emergency notifications during Quiet Hours
    }

    // Check global category toggles
    switch (category) {
      case NotificationCategory.message:
        if (!settings.enableMessages) return false;
        break;
      case NotificationCategory.mention:
        if (!settings.enableMentions) return false;
        break;
      case NotificationCategory.reaction:
        if (!settings.enableReactions) return false;
        break;
      case NotificationCategory.callVoice:
      case NotificationCategory.callVideo:
        if (!settings.enableCalls) return false;
        break;
      case NotificationCategory.location:
      case NotificationCategory.emergency:
        if (!settings.enableLocation) return false;
        break;
    }

    // Check per-conversation mute overrides
    if (conversationId != null && isConversationMuted(conversationId)) {
      return false;
    }

    return true;
  }

  void dispatchNotification({
    required String eventId,
    required NotificationCategory category,
    required String senderName,
    required String content,
    required String deepLinkRoute,
    String? conversationId,
    bool isEncrypted = false,
  }) {
    // Deduplication check
    if (_processedEventIds.contains(eventId)) return;
    _processedEventIds.add(eventId);

    if (!shouldNotify(category: category, conversationId: conversationId)) {
      return;
    }

    // Strict E2EE Privacy Rule: Strip E2EE plaintext from notification payload
    final safeBody = isEncrypted
        ? 'New encrypted message'
        : (category == NotificationCategory.location
              ? 'Shared location'
              : content);

    final payload = NotificationPayload(
      id: eventId,
      category: category,
      title: senderName,
      body: safeBody,
      deepLinkRoute: deepLinkRoute,
      conversationId: conversationId,
      timestamp: DateTime.now(),
      isEncrypted: isEncrypted,
    );

    _notificationStreamController.add(payload);
  }

  void dispose() {
    _notificationStreamController.close();
  }
}
