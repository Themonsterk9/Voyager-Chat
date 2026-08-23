enum AppEnvironment { production, staging, development }

class AppVersionInfo {
  const AppVersionInfo({
    required this.versionName,
    required this.buildNumber,
    required this.environment,
  });

  final String versionName;
  final int buildNumber;
  final AppEnvironment environment;

  String get displayString =>
      '$versionName ($buildNumber) [${environment.name.toUpperCase()}]';
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.isUpdateAvailable,
    required this.isForceUpdateRequired,
    required this.latestVersion,
    required this.releaseNotes,
    this.maintenanceBanner,
  });

  final bool isUpdateAvailable;
  final bool isForceUpdateRequired;
  final String latestVersion;
  final String releaseNotes;
  final String? maintenanceBanner;
}
