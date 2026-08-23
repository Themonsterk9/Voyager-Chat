import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/release/app_update_service.dart';
import 'package:frontend/core/release/release_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 18 Release Packaging & Deployment Readiness Tests (Steps 361-380)', () {
    late AppUpdateService updateService;

    setUp(() {
      updateService = AppUpdateService.instance;
    });

    test(
      'TEST 1 & 2: AppEnvironment enum parsing and version info display string',
      () {
        expect(AppEnvironment.production.name, equals('production'));
        expect(AppEnvironment.staging.name, equals('staging'));
        expect(AppEnvironment.development.name, equals('development'));

        const info = AppVersionInfo(
          versionName: '1.0.0',
          buildNumber: 1,
          environment: AppEnvironment.production,
        );

        expect(info.displayString, equals('1.0.0 (1) [PRODUCTION]'));
      },
    );

    test('TEST 3 & 4: Semantic version comparison engine evaluates minimum supported versions correctly', () {
      expect(updateService.isVersionOutdated('1.0.0', '1.1.0'), isTrue);
      expect(updateService.isVersionOutdated('1.0.0', '1.0.1'), isTrue);
      expect(updateService.isVersionOutdated('1.0.0', '1.0.0'), isFalse);
      expect(updateService.isVersionOutdated('1.2.0', '1.1.0'), isFalse);
    });

    test(
      'TEST 5 & 6: AppUpdateService update check manifest retrieval',
      () async {
        final updateInfo = await updateService.checkForUpdates();
        expect(updateInfo.latestVersion, equals('1.0.0'));
        expect(updateInfo.isForceUpdateRequired, isFalse);
        expect(
          updateInfo.releaseNotes,
          contains('Voyager Chat Production Release'),
        );
      },
    );
  });
}
