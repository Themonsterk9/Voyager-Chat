import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../database/app_database.dart';
import 'enterprise_models.dart';

class EnterpriseAuditService {
  EnterpriseAuditService._();

  static final EnterpriseAuditService instance = EnterpriseAuditService._();

  static const String genesisHash =
      'GENESIS_HASH_00000000000000000000000000000000';

  String _lastHash = genesisHash;

  String _computeHash({
    required String id,
    required String eventType,
    required String userId,
    required String detailsJson,
    required String timestampStr,
    required String prevHash,
  }) {
    final payload =
        '$id:$eventType:$userId:$detailsJson:$timestampStr:$prevHash';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  Future<void> _ensureLastHashInitialized() async {
    if (_lastHash != genesisHash) return;
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'audit_logs',
        orderBy: 'rowid DESC',
        limit: 1,
      );
      if (rows.isNotEmpty) {
        _lastHash = rows.first['hash'] as String;
      }
    } catch (_) {}
  }

  Map<String, dynamic> _sanitizeDetails(Map<String, dynamic> details) {
    final sanitized = Map<String, dynamic>.from(details);
    final sensitiveKeys = [
      'password',
      'otp',
      'code',
      'token',
      'api_key',
      'secret',
      'client_secret',
      'bearer',
    ];
    for (final key in sensitiveKeys) {
      if (sanitized.containsKey(key)) {
        sanitized[key] = '[REDACTED]';
      }
    }
    return sanitized;
  }

  Future<AuditLogEntry> logEvent({
    required AuditEventType eventType,
    required String userId,
    required Map<String, dynamic> details,
  }) async {
    await _ensureLastHashInitialized();

    final id = 'audit_${DateTime.now().microsecondsSinceEpoch}';
    final timestamp = DateTime.now();
    final timestampStr = timestamp.toIso8601String();
    final sanitizedDetails = _sanitizeDetails(details);
    final detailsJson = json.encode(sanitizedDetails);

    final prevHash = _lastHash;
    final hash = _computeHash(
      id: id,
      eventType: eventType.name,
      userId: userId,
      detailsJson: detailsJson,
      timestampStr: timestampStr,
      prevHash: prevHash,
    );

    _lastHash = hash;

    final entry = AuditLogEntry(
      id: id,
      eventType: eventType,
      userId: userId,
      detailsJson: detailsJson,
      timestamp: timestamp,
      prevHash: prevHash,
      hash: hash,
    );

    try {
      final db = await AppDatabase.instance.database;
      await db.insert('audit_logs', {
        'id': entry.id,
        'event_type': entry.eventType.name,
        'user_id': entry.userId,
        'details_json': entry.detailsJson,
        'timestamp': timestampStr,
        'prev_hash': entry.prevHash,
        'hash': entry.hash,
      });
    } catch (_) {}

    return entry;
  }

  Future<List<AuditLogEntry>> getAuditLogs() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query('audit_logs', orderBy: 'rowid DESC');
      return rows.map((r) {
        final typeName = r['event_type'] as String;
        final eventType = AuditEventType.values.firstWhere(
          (e) => e.name == typeName,
          orElse: () => AuditEventType.userLogin,
        );
        return AuditLogEntry(
          id: r['id'] as String,
          eventType: eventType,
          userId: r['user_id'] as String,
          detailsJson: r['details_json'] as String,
          timestamp:
              DateTime.tryParse(r['timestamp'].toString()) ?? DateTime.now(),
          prevHash: r['prev_hash'] as String,
          hash: r['hash'] as String,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> verifyAuditChain() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query('audit_logs', orderBy: 'rowid ASC');
      if (rows.isEmpty) return true;

      String expectedPrev = rows.first['prev_hash'] as String;

      for (final r in rows) {
        final id = r['id'] as String;
        final eventType = r['event_type'] as String;
        final userId = r['user_id'] as String;
        final detailsJson = r['details_json'] as String;
        final timestampStr = r['timestamp'] as String;
        final prevHash = r['prev_hash'] as String;
        final storedHash = r['hash'] as String;

        if (prevHash != expectedPrev) {
          return false;
        }

        final calculated = _computeHash(
          id: id,
          eventType: eventType,
          userId: userId,
          detailsJson: detailsJson,
          timestampStr: timestampStr,
          prevHash: prevHash,
        );

        if (calculated != storedHash) {
          return false;
        }

        expectedPrev = storedHash;
      }
    } catch (_) {
      return false;
    }

    return true;
  }

  Future<int> getEligibleRetentionCount() async {
    try {
      final db = await AppDatabase.instance.database;
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 30))
          .toIso8601String();
      final rows = await db.query(
        'messages',
        columns: ['id'],
        where: 'created_at < ?',
        whereArgs: [cutoff],
      );
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> enforceRetentionPolicies() async {
    int deletedCount = 0;
    try {
      final db = await AppDatabase.instance.database;
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 30))
          .toIso8601String();
      deletedCount = await db.delete(
        'messages',
        where: 'created_at < ?',
        whereArgs: [cutoff],
      );
      await logEvent(
        eventType: AuditEventType.retentionPolicyUpdated,
        userId: 'system-retention',
        details: {'purged_messages': deletedCount, 'cutoff': cutoff},
      );
    } catch (_) {}
    return deletedCount;
  }

  Future<bool> executeRemoteWipe() async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('messages');
      await db.delete('conversations');
      await db.delete('conversation_members');
      await db.delete('message_attachments');
      await db.delete('meetings');
    } catch (_) {}

    await logEvent(
      eventType: AuditEventType.remoteWipeExecuted,
      userId: 'system-remote-wipe',
      details: {'action': 'complete_wipe', 'status': 'success'},
    );

    return true;
  }

  Future<void> resetForTesting() async {
    _lastHash = genesisHash;
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('audit_logs');
    } catch (_) {}
  }
}
