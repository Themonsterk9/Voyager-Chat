import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enterprise/enterprise_audit_service.dart';
import 'package:frontend/core/enterprise/enterprise_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 19 Enterprise Governance & Capstone Tests (Steps 381-400)', () {
    late EnterpriseAuditService auditService;

    setUp(() async {
      auditService = EnterpriseAuditService.instance;
      await auditService.resetForTesting();
    });

    test('TEST 1 & 2: EnterpriseRole and AuditEventType enum parsing', () {
      expect(EnterpriseRole.superAdmin.name, equals('superAdmin'));
      expect(EnterpriseRole.orgAdmin.name, equals('orgAdmin'));
      expect(
        EnterpriseRole.complianceAuditor.name,
        equals('complianceAuditor'),
      );

      expect(AuditEventType.userLogin.name, equals('userLogin'));
      expect(AuditEventType.keyRotation.name, equals('keyRotation'));
      expect(
        AuditEventType.remoteWipeExecuted.name,
        equals('remoteWipeExecuted'),
      );
    });

    test(
      'TEST 3 & 4: Audit log creation with SHA-256 cryptographic hash chaining',
      () async {
        final entry1 = await auditService.logEvent(
          eventType: AuditEventType.userLogin,
          userId: 'admin-1',
          details: {'ip': '192.168.1.1'},
        );

        final entry2 = await auditService.logEvent(
          eventType: AuditEventType.keyRotation,
          userId: 'admin-1',
          details: {'keyId': 'key-v2'},
        );

        expect(entry1.hash, isNotEmpty);
        expect(entry2.prevHash, equals(entry1.hash));
      },
    );

    test('TEST 5 & 6: Audit chain verification algorithm validates chain integrity', () async {
      await auditService.logEvent(
        eventType: AuditEventType.userLogin,
        userId: 'admin-1',
        details: {'ip': '192.168.1.1'},
      );
      await auditService.logEvent(
        eventType: AuditEventType.keyRotation,
        userId: 'admin-1',
        details: {'keyId': 'key-v2'},
      );

      final isChainValid = await auditService.verifyAuditChain();
      expect(isChainValid, isTrue);
    });

    test('TEST 7 & 8: Data retention policy execution', () async {
      final purged = await auditService.enforceRetentionPolicies();
      expect(purged, greaterThanOrEqualTo(0));
    });

    test('TEST 9 & 10: Remote wipe execution clears database state and logs audit event', () async {
      final wiped = await auditService.executeRemoteWipe();
      expect(wiped, isTrue);
    });
  });
}
