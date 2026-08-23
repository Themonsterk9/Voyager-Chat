import 'package:flutter/material.dart';

import '../../../core/settings/settings_models.dart';
import '../../../core/settings/settings_service.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  final SettingsService _service = SettingsService.instance;

  Future<void> _revoke(DeviceSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Device'),
        content: Text(
          'Revoke access for ${session.deviceName}? This device will be signed out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.revokeDevice(session.deviceId);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Device ${session.deviceName} revoked.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _service.activeSessions;

    return Scaffold(
      appBar: AppBar(title: const Text('Registered Devices & Sessions')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final session = sessions[index];
          return ListTile(
            leading: Icon(
              session.deviceOs.contains('Windows')
                  ? Icons.desktop_windows
                  : Icons.phone_android,
              color: session.isCurrentDevice
                  ? Colors.greenAccent
                  : Colors.blueAccent,
            ),
            title: Row(
              children: [
                Text(
                  session.deviceName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (session.isCurrentDevice) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'THIS DEVICE',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text('${session.deviceOs} • Verified E2EE Identity'),
            trailing: session.isCurrentDevice
                ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                : IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _revoke(session),
                  ),
          );
        },
      ),
    );
  }
}
