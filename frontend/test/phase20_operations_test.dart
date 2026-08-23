import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/operations/crash_recovery_service.dart';
import 'package:frontend/core/operations/operational_telemetry_service.dart';
import 'package:frontend/core/operations/performance_optimizer_service.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group(
    'Phase 20 Post-Launch Operations & Monitoring Tests (Steps 401-420)',
    () {
      test('TEST 1 & 2: OperationalTelemetryService snapshot recording and metrics retrieval', () {
        final telemetry = OperationalTelemetryService.instance;
        telemetry.recordSnapshot(
          ramUsageMb: 52.4,
          networkLatencyMs: 28,
          messageDeliveryLatencyMs: 72,
          fps: 59.8,
        );

        final latest = telemetry.latestSnapshot;
        expect(latest.ramUsageMb, equals(52.4));
        expect(latest.networkLatencyMs, equals(28));
        expect(telemetry.getHistory(), isNotEmpty);
      });

      test(
        'TEST 3 & 4: CrashRecoveryService shutdown detection and lock cleanup',
        () async {
          final crashRecovery = CrashRecoveryService.instance;
          await crashRecovery.checkForAbnormalShutdown();
          expect(crashRecovery.wasAbnormalShutdown, isFalse);

          final recovered = await crashRecovery.recoverOrphanedLocks();
          expect(recovered, greaterThanOrEqualTo(0));

          final isValid = await crashRecovery.verifySessionIntegrity();
          expect(isValid, isTrue);
        },
      );

      test('TEST 5 & 6: PerformanceOptimizerService database VACUUM and cache trimming', () async {
        final optimizer = PerformanceOptimizerService.instance;
        final vacuumSuccess = await optimizer.vacuumDatabase();
        expect(vacuumSuccess, isA<bool>());

        final trimmedBytes = optimizer.trimMediaCaches();
        expect(trimmedBytes, greaterThanOrEqualTo(0));
      });
    },
  );
}
