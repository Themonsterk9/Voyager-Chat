import 'package:flutter/foundation.dart';

import '../auth/services/auth_service.dart';
import '../database/app_database.dart';

class AppErrorRecord {
  const AppErrorRecord({
    required this.error,
    required this.stackTrace,
    required this.timestamp,
    required this.isSanitized,
  });

  final String error;
  final String stackTrace;
  final DateTime timestamp;
  final bool isSanitized;
}

class CrashRecoveryService {
  CrashRecoveryService._();

  static final CrashRecoveryService instance = CrashRecoveryService._();

  bool _wasAbnormalShutdown = false;
  final List<AppErrorRecord> _capturedErrors = [];

  bool get wasAbnormalShutdown => _wasAbnormalShutdown;
  List<AppErrorRecord> get capturedErrors => List.unmodifiable(_capturedErrors);

  void initializeCrashMonitoring() {
    FlutterError.onError = (details) {
      recordAppError(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      recordAppError(error, stack);
      return true;
    };
  }

  void recordAppError(dynamic error, StackTrace? stack) {
    final rawString = error.toString();
    final sanitized = _sanitizeErrorText(rawString);
    _capturedErrors.add(
      AppErrorRecord(
        error: sanitized,
        stackTrace: stack?.toString() ?? '',
        timestamp: DateTime.now(),
        isSanitized: true,
      ),
    );
    if (_capturedErrors.length > 50) {
      _capturedErrors.removeAt(0);
    }
  }

  String _sanitizeErrorText(String text) {
    var sanitized = text;
    final sensitivePatterns = [
      RegExp(r'password=[^\s&]+', caseSensitive: false),
      RegExp(r'otp=[^\s&]+', caseSensitive: false),
      RegExp(r'api_key=[^\s&]+', caseSensitive: false),
      RegExp(r'secret=[^\s&]+', caseSensitive: false),
      RegExp(r'bearer\s+[^\s&]+', caseSensitive: false),
    ];
    for (final pattern in sensitivePatterns) {
      sanitized = sanitized.replaceAll(pattern, '[REDACTED]');
    }
    return sanitized;
  }

  Future<void> checkForAbnormalShutdown() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'app_state',
        where: 'key = ?',
        whereArgs: ['clean_shutdown'],
      );
      if (rows.isNotEmpty && rows.first['value'] == '0') {
        _wasAbnormalShutdown = true;
      }
    } catch (_) {}
  }

  Future<int> recoverOrphanedLocks() async {
    int recoveredCount = 0;
    try {
      final db = await AppDatabase.instance.database;
      recoveredCount = await db.delete('pending_messages');
      _wasAbnormalShutdown = false;
    } catch (_) {}
    return recoveredCount;
  }

  Future<bool> verifySessionIntegrity() async {
    try {
      final auth = AuthService.instance;
      if (auth.isAuthenticated && auth.currentUser != null) {
        return auth.currentUser!.id.isNotEmpty &&
            (auth.currentUser!.email?.contains('@') ?? false);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
