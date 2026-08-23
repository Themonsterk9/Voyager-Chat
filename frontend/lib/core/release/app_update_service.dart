import 'release_config.dart';

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  AppVersionInfo currentVersion = const AppVersionInfo(
    versionName: '1.0.0',
    buildNumber: 1,
    environment: AppEnvironment.production,
  );

  Future<AppUpdateInfo> checkForUpdates() async {
    // Simulates update service evaluation against release manifests
    return const AppUpdateInfo(
      isUpdateAvailable: false,
      isForceUpdateRequired: false,
      latestVersion: '1.0.0',
      releaseNotes:
          'Voyager Chat Production Release v1.0.0. All systems operational.',
      maintenanceBanner: null,
    );
  }

  bool isVersionOutdated(String current, String minimumRequired) {
    final curParts = current.split('.').map(int.parse).toList();
    final minParts = minimumRequired.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final c = i < curParts.length ? curParts[i] : 0;
      final m = i < minParts.length ? minParts[i] : 0;
      if (c < m) return true;
      if (c > m) return false;
    }
    return false;
  }
}
