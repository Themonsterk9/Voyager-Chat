import 'package:flutter/material.dart';

import '../../../core/release/app_update_service.dart';
import '../../../core/release/release_config.dart';

class ReleaseInfoScreen extends StatefulWidget {
  const ReleaseInfoScreen({super.key});

  @override
  State<ReleaseInfoScreen> createState() => _ReleaseInfoScreenState();
}

class _ReleaseInfoScreenState extends State<ReleaseInfoScreen> {
  AppUpdateInfo? _updateInfo;
  bool _isChecking = false;

  Future<void> _checkUpdate() async {
    setState(() => _isChecking = true);
    final info = await AppUpdateService.instance.checkForUpdates();
    setState(() {
      _updateInfo = info;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final version = AppUpdateService.instance.currentVersion;
    final info = _updateInfo;

    return Scaffold(
      appBar: AppBar(title: const Text('App Version & Deployment Info')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.rocket_launch,
                  size: 64,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Voyager Chat Production',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  version.displayString,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'DEPLOYMENT & COMPLIANCE DISCLOSURES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.security, color: Colors.greenAccent),
            title: Text('End-to-End Encryption Compliance'),
            subtitle: Text(
              'Signal Protocol E2EE enabled by default for all private & group chats.',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip, color: Colors.amberAccent),
            title: Text('Privacy Policy & Data Safety'),
            subtitle: Text(
              'Zero metadata tracking. Decrypted messages strictly local in client SQLite.',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.verified, color: Colors.blueAccent),
            title: Text('Store Deployment Readiness'),
            subtitle: Text(
              'Prepared for Android AAB / APK, Windows EXE, and iOS App Store.',
            ),
          ),
          const SizedBox(height: 24),
          if (info != null)
            Card(
              color: Colors.grey.shade900,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Latest Release Manifest: ${info.latestVersion}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.releaseNotes,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: _isChecking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.system_update),
            label: Text(
              _isChecking ? 'Checking Server Manifest...' : 'Check for Updates',
            ),
            onPressed: _isChecking ? null : _checkUpdate,
          ),
        ],
      ),
    );
  }
}
