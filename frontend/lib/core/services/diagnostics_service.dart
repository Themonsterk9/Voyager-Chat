import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../auth/services/auth_service.dart';
import '../database/app_database.dart';

class StartupCrashRecord {
  const StartupCrashRecord({
    required this.diagnosticId,
    required this.timestamp,
    required this.appVersion,
    required this.platformInfo,
    required this.startupStage,
    required this.exceptionType,
    required this.sanitizedDetails,
  });

  final String diagnosticId;
  final String timestamp;
  final String appVersion;
  final String platformInfo;
  final String startupStage;
  final String exceptionType;
  final String sanitizedDetails;

  static String sanitize(String input) {
    var clean = input;
    // Redact email addresses
    clean = clean.replaceAll(
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      '[REDACTED_EMAIL]',
    );
    // Redact sensitive keys, passwords, OTPs, tokens
    clean = clean.replaceAll(
      RegExp(
        r'(password|token|apikey|secret|otp|auth_key|jwt)=\S+',
        caseSensitive: false,
      ),
      r'\1=[REDACTED]',
    );
    clean = clean.replaceAll(
      RegExp(r'sb-[a-zA-Z0-9_-]+'),
      '[REDACTED_SUPABASE_KEY]',
    );
    return clean;
  }

  Map<String, dynamic> toJson() => {
    'diagnosticId': diagnosticId,
    'timestamp': timestamp,
    'appVersion': appVersion,
    'platformInfo': platformInfo,
    'startupStage': startupStage,
    'exceptionType': exceptionType,
    'sanitizedDetails': sanitizedDetails,
  };

  factory StartupCrashRecord.fromJson(Map<String, dynamic> json) =>
      StartupCrashRecord(
        diagnosticId: json['diagnosticId'] as String? ?? 'DIAG-UNKNOWN',
        timestamp: json['timestamp'] as String? ?? '',
        appVersion: json['appVersion'] as String? ?? '1.0.0',
        platformInfo: json['platformInfo'] as String? ?? 'Unknown',
        startupStage: json['startupStage'] as String? ?? 'general',
        exceptionType: json['exceptionType'] as String? ?? 'Exception',
        sanitizedDetails: json['sanitizedDetails'] as String? ?? '',
      );

  String exportFormattedReport() {
    return '''
==================================================
VOYAGER CHAT STARTUP DIAGNOSTIC REPORT
Diagnostic ID : $diagnosticId
Timestamp     : $timestamp
App Version   : $appVersion
Platform      : $platformInfo
Startup Stage : $startupStage
Exception     : $exceptionType
==================================================
Sanitized Error Details:
$sanitizedDetails
==================================================
''';
  }
}

class SystemDiagnostics {
  const SystemDiagnostics({
    required this.conversationCount,
    required this.messageCount,
    required this.pendingMessageCount,
    required this.reactionCount,
    required this.isAuthenticated,
    required this.currentUserEmail,
    required this.dbVersion,
  });

  final int conversationCount;
  final int messageCount;
  final int pendingMessageCount;
  final int reactionCount;
  final bool isAuthenticated;
  final String? currentUserEmail;
  final int dbVersion;

  String exportReport() {
    return '''
==================================================
VOYAGER CHAT SYSTEM DIAGNOSTICS REPORT
Timestamp: ${DateTime.now().toUtc().toIso8601String()}
==================================================
Authentication Status : ${isAuthenticated ? 'Authenticated' : 'Not Authenticated'}
Current User Email    : ${currentUserEmail ?? 'N/A'}
SQLite DB Version     : $dbVersion
Conversations Count   : $conversationCount
Messages Count        : $messageCount
Pending Messages      : $pendingMessageCount
Message Reactions     : $reactionCount
Status                : HEALTHY
==================================================
''';
  }
}

class DiagnosticsService {
  DiagnosticsService._();

  static final DiagnosticsService instance = DiagnosticsService._();
  static const String _crashKey = 'voyager_last_startup_crash';

  Future<void> recordStartupError({
    required String stage,
    required Object error,
    StackTrace? stack,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idSuffix = DateTime.now().millisecondsSinceEpoch
          .toRadixString(36)
          .toUpperCase();
      final diagnosticId = 'DIAG-$idSuffix';

      final rawDetails = '$error\n${stack ?? ""}';
      final sanitizedDetails = StartupCrashRecord.sanitize(rawDetails);

      String platform = 'Web/Desktop';
      try {
        if (kIsWeb) {
          platform = 'Web';
        } else if (Platform.isAndroid) {
          platform = 'Android API ${Platform.operatingSystemVersion}';
        } else if (Platform.isIOS) {
          platform = 'iOS ${Platform.operatingSystemVersion}';
        }
      } catch (_) {}

      final record = StartupCrashRecord(
        diagnosticId: diagnosticId,
        timestamp: DateTime.now().toUtc().toIso8601String(),
        appVersion: '1.0.0',
        platformInfo: platform,
        startupStage: stage,
        exceptionType: error.runtimeType.toString(),
        sanitizedDetails: sanitizedDetails,
      );

      await prefs.setString(_crashKey, jsonEncode(record.toJson()));
      debugPrint('Recorded sanitized startup crash [$diagnosticId]');
    } catch (e) {
      debugPrint('Failed to persist startup crash record: $e');
    }
  }

  Future<StartupCrashRecord?> getLatestCrashRecord() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_crashKey);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return StartupCrashRecord.fromJson(map);
    } catch (e) {
      debugPrint('Failed to read crash record: $e');
      return null;
    }
  }

  Future<void> clearCrashRecord() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_crashKey);
    } catch (e) {
      debugPrint('Failed to clear crash record: $e');
    }
  }

  Future<SystemDiagnostics> runDiagnostics() async {
    final db = await AppDatabase.instance.database;

    final convRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM conversations',
    );
    final msgRes = await db.rawQuery('SELECT COUNT(*) as count FROM messages');
    final pendingRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pending_messages',
    );
    final reactRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM message_reactions',
    );

    final conversationCount = Sqflite.firstIntValue(convRes) ?? 0;
    final messageCount = Sqflite.firstIntValue(msgRes) ?? 0;
    final pendingMessageCount = Sqflite.firstIntValue(pendingRes) ?? 0;
    final reactionCount = Sqflite.firstIntValue(reactRes) ?? 0;

    final user = AuthService.instance.currentUser;

    return SystemDiagnostics(
      conversationCount: conversationCount,
      messageCount: messageCount,
      pendingMessageCount: pendingMessageCount,
      reactionCount: reactionCount,
      isAuthenticated: user != null,
      currentUserEmail: user?.email,
      dbVersion: 5,
    );
  }
}
