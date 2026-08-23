import 'dart:convert';

import '../database/app_database.dart';
import 'settings_models.dart';

class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  final ChatSettings chatSettings = ChatSettings();
  final PrivacySettings privacySettings = PrivacySettings();

  final List<DeviceSession> _sessions = [
    DeviceSession(
      deviceId: 'device-local-1',
      deviceName: 'Voyager Windows Station',
      deviceOs: 'Windows 11 Desktop',
      lastActive: DateTime.now(),
      isCurrentDevice: true,
      isVerified: true,
    ),
    DeviceSession(
      deviceId: 'device-mobile-mobile-2',
      deviceName: 'Voyager Mobile Companion',
      deviceOs: 'Android 14',
      lastActive: DateTime.now().subtract(const Duration(hours: 2)),
      isCurrentDevice: false,
      isVerified: true,
    ),
  ];

  List<DeviceSession> get activeSessions => List.unmodifiable(_sessions);

  Future<void> revokeDevice(String deviceId) async {
    _sessions.removeWhere((s) => s.deviceId == deviceId && !s.isCurrentDevice);
  }

  Future<String> exportUserDataJson({required String userId}) async {
    int convsCount = 0;
    int msgsCount = 0;
    int callsCount = 0;
    int locationsCount = 0;

    try {
      final db = await AppDatabase.instance.database;
      final convs = await db.query('conversations');
      final msgs = await db.query('messages', columns: ['id']);
      final calls = await db.query('call_logs');
      final locations = await db.query('shared_locations');

      convsCount = convs.length;
      msgsCount = msgs.length;
      callsCount = calls.length;
      locationsCount = locations.length;
    } catch (_) {}

    final exportData = {
      'export_version': '1.0.0',
      'user_id': userId,
      'exported_at': DateTime.now().toIso8601String(),
      'chat_settings': chatSettings.toMap(),
      'privacy_settings': privacySettings.toMap(),
      'conversations_count': convsCount,
      'messages_metadata_count': msgsCount,
      'call_logs_count': callsCount,
      'shared_locations_count': locationsCount,
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  Future<void> deleteAccount({required String userId}) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('messages');
      await db.delete('conversations');
      await db.delete('conversation_members');
      await db.delete('shared_locations');
      await db.delete('call_logs');
      await db.delete('notification_preferences');
      await db.delete('app_settings');
    } catch (_) {}
  }
}
