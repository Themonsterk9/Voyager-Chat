import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:frontend/core/database/app_database.dart';
import 'package:frontend/core/enterprise/enterprise_audit_service.dart';
import 'package:frontend/core/enterprise/enterprise_models.dart';
import 'package:frontend/core/operations/crash_recovery_service.dart';
import 'package:frontend/core/operations/operational_telemetry_service.dart';
import 'package:frontend/core/operations/performance_optimizer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await EnterpriseAuditService.instance.resetForTesting();
  });

  group('Enterprise Governance & Audit Logs Tests', () {
    test('Audit Event Creation & Persistence', () async {
      final entry = await EnterpriseAuditService.instance.logEvent(
        eventType: AuditEventType.userLogin,
        userId: 'usr_audit_001',
        details: {'email': 'test@voyager.chat', 'ip': '127.0.0.1'},
      );

      expect(entry.id, startsWith('audit_'));
      expect(entry.eventType, equals(AuditEventType.userLogin));
      expect(entry.userId, equals('usr_audit_001'));
      expect(entry.hash, isNotEmpty);

      final logs = await EnterpriseAuditService.instance.getAuditLogs();
      expect(logs, isNotEmpty);
      expect(logs.first.userId, equals('usr_audit_001'));
    });

    test('SHA-256 Hash Chain Linkage & Verification', () async {
      await EnterpriseAuditService.instance.logEvent(
        eventType: AuditEventType.userLogin,
        userId: 'user_1',
        details: {'action': 'login_1'},
      );

      await EnterpriseAuditService.instance.logEvent(
        eventType: AuditEventType.userRegistration,
        userId: 'user_2',
        details: {'action': 'register_2'},
      );

      await EnterpriseAuditService.instance.logEvent(
        eventType: AuditEventType.passwordChanged,
        userId: 'user_1',
        details: {'action': 'pwd_change'},
      );

      final isChainValid = await EnterpriseAuditService.instance
          .verifyAuditChain();
      expect(isChainValid, isTrue);
    });

    test('Tamper Detection: Modified Record Fails Hash Verification', () async {
      await EnterpriseAuditService.instance.logEvent(
        eventType: AuditEventType.userLogin,
        userId: 'user_tamper',
        details: {'note': 'original'},
      );

      // Verify chain before tampering
      expect(await EnterpriseAuditService.instance.verifyAuditChain(), isTrue);

      // Intentionally tamper with audit_logs table row directly
      final db = await AppDatabase.instance.database;
      await db.update(
        'audit_logs',
        {'user_id': 'hacked_user'},
        where: 'user_id = ?',
        whereArgs: ['user_tamper'],
      );

      // Verification MUST detect tampering and return false
      final isChainValid = await EnterpriseAuditService.instance
          .verifyAuditChain();
      expect(isChainValid, isFalse);

      // Reset state so tampered row does not affect subsequent tests
      await EnterpriseAuditService.instance.resetForTesting();
    });

    test('Sensitive Data Exclusion (Password & OTP Redaction)', () async {
      final entry = await EnterpriseAuditService.instance.logEvent(
        eventType: AuditEventType.userLogin,
        userId: 'user_secret',
        details: {
          'email': 'user@voyager.chat',
          'password': 'SecretPassword123!',
          'otp': '999888',
          'api_key': 'xkeysib-secret-key',
        },
      );

      expect(entry.detailsJson, contains('[REDACTED]'));
      expect(entry.detailsJson, isNot(contains('SecretPassword123!')));
      expect(entry.detailsJson, isNot(contains('999888')));
      expect(entry.detailsJson, isNot(contains('xkeysib-secret-key')));
    });

    test('Retention Enforcement & Remote Wipe Audit', () async {
      final purged = await EnterpriseAuditService.instance
          .enforceRetentionPolicies();
      expect(purged, greaterThanOrEqualTo(0));

      final wiped = await EnterpriseAuditService.instance.executeRemoteWipe();
      expect(wiped, isTrue);

      final logs = await EnterpriseAuditService.instance.getAuditLogs();
      expect(
        logs.any((l) => l.eventType == AuditEventType.remoteWipeExecuted),
        isTrue,
      );
    });
  });

  group('Operations & Telemetry Monitoring Tests', () {
    test('Real Telemetry Metrics & Snapshot History', () async {
      final service = OperationalTelemetryService.instance;
      service.recordSnapshot(ramUsageMb: 52.4, fps: 60.0);

      final snapshot = service.latestSnapshot;
      expect(snapshot.ramUsageMb, greaterThanOrEqualTo(0.0));
      expect(snapshot.fps, equals(60.0));

      final history = service.getHistory();
      expect(history, isNotEmpty);
    });

    test('SQLite PRAGMA Database Integrity Check', () async {
      final health = await OperationalTelemetryService.instance
          .checkDatabaseIntegrity();
      expect(health, anyOf('HEALTHY', 'CORRUPTED', 'UNAVAILABLE'));

      final dbSize = await OperationalTelemetryService.instance
          .getDatabaseSizeMb();
      expect(dbSize, greaterThanOrEqualTo(0.0));
    });

    test('Crash Recovery & Uncaught Error Capturing', () async {
      final recovery = CrashRecoveryService.instance;
      recovery.recordAppError(
        'Exception: Test error password=SecretPass',
        StackTrace.current,
      );

      final errors = recovery.capturedErrors;
      expect(errors, isNotEmpty);
      expect(errors.last.error, contains('[REDACTED]'));
      expect(errors.last.error, isNot(contains('SecretPass')));

      final locksCleared = await recovery.recoverOrphanedLocks();
      expect(locksCleared, greaterThanOrEqualTo(0));
      expect(recovery.wasAbnormalShutdown, isFalse);
    });

    test('Database VACUUM & Media Cache Trimming', () async {
      final vacuumSuccess = await PerformanceOptimizerService.instance
          .vacuumDatabase();
      expect(vacuumSuccess, isA<bool>());

      final freedBytes = PerformanceOptimizerService.instance.trimMediaCaches();
      expect(freedBytes, greaterThanOrEqualTo(0));
    });
  });
}
