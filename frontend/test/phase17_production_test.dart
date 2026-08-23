import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/production/production_health_service.dart';
import 'package:frontend/core/production/security_hardening_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 17 Production Hardening & Health Diagnostics Tests (Steps 341-360)', () {
    late ProductionHealthService healthService;
    late SecurityHardeningService securityService;

    setUp(() {
      healthService = ProductionHealthService.instance;
      securityService = SecurityHardeningService.instance;
    });

    test('TEST 1 & 2: ProductionHealthService executes SQLite PRAGMA integrity check cleanly', () async {
      final report = await healthService.runHealthCheck();
      expect(report.isDbIntegrityClean, isTrue);
      expect(
        report.statusSummary,
        contains('SQLite integrity verified cleanly'),
      );
    });

    test(
      'TEST 3 & 4: Database size and RSS RAM memory footprint metrics',
      () async {
        final report = await healthService.runHealthCheck();
        expect(report.dbSizeMb, greaterThanOrEqualTo(0.0));
        expect(report.memoryUsageMb, greaterThan(0.0));
      },
    );

    test(
      'TEST 5 & 6: Key obfuscation prevents revealing sensitive API keys',
      () {
        final obfuscated = securityService.obfuscateKey(
          'sk_live_1234567890abcdef',
        );
        expect(obfuscated, equals('sk****ef'));
        expect(obfuscated, isNot(contains('1234567890')));
      },
    );

    test('TEST 7 & 8: Security log sanitization redacts Bearer tokens and passwords', () {
      const rawLog =
          'Authorization: Bearer secret_jwt_token_123, password: mysecretpassword';
      final sanitized = securityService.sanitizeLogMessage(rawLog);

      expect(sanitized, contains('Bearer [REDACTED]'));
      expect(sanitized, contains('password: [REDACTED]'));
      expect(sanitized, isNot(contains('secret_jwt_token_123')));
      expect(sanitized, isNot(contains('mysecretpassword')));
    });

    test('TEST 9 & 10: Device root/jailbreak detection status check', () {
      final isRooted = securityService.isDeviceJailbrokenOrRooted();
      expect(isRooted, isFalse);
    });
  });
}
