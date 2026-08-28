import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/permissions/permission_helper.dart';

class PermissionOnboardingScreen extends StatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  State<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends State<PermissionOnboardingScreen> {
  bool _notificationGranted = false;
  bool _cameraMicGranted = false;
  bool _locationGranted = false;
  bool _nearbyGranted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkInitialStatuses();
  }

  Future<void> _checkInitialStatuses() async {
    if (kIsWeb || Platform.isWindows) {
      if (mounted) {
        setState(() {
          _notificationGranted = true;
          _cameraMicGranted = true;
          _locationGranted = true;
          _nearbyGranted = true;
          _checking = false;
        });
      }
      return;
    }

    final notif = await Permission.notification.status;
    final cam = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    final loc = await Permission.location.status;
    final btScan = await Permission.bluetoothScan.status;

    if (mounted) {
      setState(() {
        _notificationGranted = notif.isGranted || notif.isLimited;
        _cameraMicGranted =
            (cam.isGranted || cam.isLimited) && (mic.isGranted || mic.isLimited);
        _locationGranted = loc.isGranted || loc.isLimited;
        _nearbyGranted = btScan.isGranted || btScan.isLimited;
        _checking = false;
      });
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (kIsWeb || Platform.isWindows) return;
    await Permission.notification.request();
    await _checkInitialStatuses();
  }

  Future<void> _requestCameraMicPermission() async {
    if (kIsWeb || Platform.isWindows) return;
    await Permission.camera.request();
    await Permission.microphone.request();
    await _checkInitialStatuses();
  }

  Future<void> _requestLocationPermission() async {
    if (kIsWeb || Platform.isWindows) return;
    await Permission.location.request();
    await _checkInitialStatuses();
  }

  Future<void> _requestNearbyPermission() async {
    if (kIsWeb || Platform.isWindows) return;
    await PermissionHelper.instance.ensureNearbyPermissions(context);
    await _checkInitialStatuses();
  }

  Future<void> _finishOnboarding() async {
    await PermissionHelper.instance.setOnboardingCompleted(completed: true);
    if (!mounted) return;
    context.go('/home');
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isGranted
                    ? Colors.green.withValues(alpha: 0.15)
                    : Theme.of(context).primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isGranted
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isGranted)
                        const Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green, size: 18),
                            SizedBox(width: 4),
                            Text(
                              'Allowed',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.75),
                    ),
                  ),
                  if (!isGranted && !kIsWeb && !Platform.isWindows) ...[
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: onRequest,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text('Allow $title'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Onboarding'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _checking
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.15),
                              child: Icon(
                                Icons.shield_outlined,
                                size: 40,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              'Welcome to Voyager Chat',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enable permissions for features you wish to use. You can skip any optional capability and enable it later.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          _buildPermissionTile(
                            icon: Icons.notifications_active_outlined,
                            title: 'Notifications',
                            description:
                                'Receive instant alerts for incoming messages and calls.',
                            isGranted: _notificationGranted,
                            onRequest: _requestNotificationPermission,
                          ),
                          _buildPermissionTile(
                            icon: Icons.videocam_outlined,
                            title: 'Camera & Microphone',
                            description:
                                'Make high-definition voice and video calls and take photos.',
                            isGranted: _cameraMicGranted,
                            onRequest: _requestCameraMicPermission,
                          ),
                          _buildPermissionTile(
                            icon: Icons.location_on_outlined,
                            title: 'Location Sharing',
                            description:
                                'Share live location in chat threads and map views.',
                            isGranted: _locationGranted,
                            onRequest: _requestLocationPermission,
                          ),
                          _buildPermissionTile(
                            icon: Icons.bluetooth_searching_outlined,
                            title: 'Offline Mesh Discovery',
                            description:
                                'Connect with nearby mesh peers over Bluetooth when offline.',
                            isGranted: _nearbyGranted,
                            onRequest: _requestNearbyPermission,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: _finishOnboarding,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Continue to Voyager Chat',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _finishOnboarding,
                          child: const Text('Not Now / Skip Optional'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
