import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionHelper {
  PermissionHelper._();

  static final PermissionHelper instance = PermissionHelper._();
  static const String _onboardingKey = 'has_completed_permission_onboarding';

  /// Check if user has completed the post-login permission onboarding.
  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  /// Mark the post-login permission onboarding as completed or incomplete.
  Future<void> setOnboardingCompleted({bool completed = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, completed);
  }

  /// Checks if a permission is granted.
  Future<bool> isGranted(Permission permission) async {
    if (kIsWeb || Platform.isWindows) return true;
    final status = await permission.status;
    return status.isGranted || status.isLimited;
  }

  /// Ensures a permission is granted before executing a feature action.
  /// Requests permission if needed, shows rationale dialog if denied/permanently denied,
  /// and opens App Settings if permanently denied.
  Future<bool> ensurePermission(
    BuildContext context,
    Permission permission, {
    required String title,
    required String rationale,
  }) async {
    if (kIsWeb || Platform.isWindows) return true;

    var status = await permission.status;

    if (status.isGranted || status.isLimited) {
      return true;
    }

    // Request the permission
    status = await permission.request();

    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (!context.mounted) return false;

    // Handle denied or permanently denied
    final isPermanentlyDenied = status.isPermanentlyDenied || status.isRestricted;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(rationale),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          if (isPermanentlyDenied)
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            )
          else
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await permission.request();
              },
              child: const Text('Grant Permission'),
            ),
        ],
      ),
    );

    // Re-check after dialog / retry
    return await isGranted(permission);
  }

  /// Request media/photo access permission based on Android version
  Future<bool> ensureMediaPermission(
    BuildContext context, {
    required String title,
    required String rationale,
  }) async {
    if (kIsWeb || Platform.isWindows) return true;

    Permission mediaPermission = Permission.photos;

    var status = await mediaPermission.status;
    if (status.isGranted || status.isLimited) return true;

    // Fallback check storage permission if photos status is not granted
    var storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted || storageStatus.isLimited) return true;

    if (!context.mounted) return false;

    return ensurePermission(
      context,
      mediaPermission,
      title: title,
      rationale: rationale,
    );
  }

  /// Request Bluetooth & Location permissions for BLE Nearby Mesh scanning
  Future<bool> ensureNearbyPermissions(BuildContext context) async {
    if (kIsWeb || Platform.isWindows) return true;

    if (Platform.isAndroid) {
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();
      final locationStatus = await Permission.location.request();

      final granted =
          (scanStatus.isGranted || scanStatus.isLimited) &&
          (connectStatus.isGranted || connectStatus.isLimited);

      if (!granted && locationStatus.isDenied) {
        if (context.mounted) {
          await ensurePermission(
            context,
            Permission.bluetoothScan,
            title: 'Bluetooth & Nearby Permission Required',
            rationale:
                'Voyager Chat requires Bluetooth and Location permissions to discover and connect to nearby mesh peers when offline.',
          );
        }
      }

      return (await isGranted(Permission.bluetoothScan)) ||
          (await isGranted(Permission.location));
    }

    return true;
  }
}
