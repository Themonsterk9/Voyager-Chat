import 'package:flutter/material.dart';

import '../../../core/notifications/notification_manager.dart';
import '../../../core/notifications/notification_models.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final NotificationManager _manager = NotificationManager.instance;

  @override
  Widget build(BuildContext context) {
    final settings = _manager.settings;
    final quiet = settings.quietHours;

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'NOTIFICATION CATEGORIES',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('New Message Alerts'),
                  subtitle: const Text('Show alerts when messages arrive'),
                  value: settings.enableMessages,
                  onChanged: (val) {
                    setState(() {
                      settings.enableMessages = val;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Mention Alerts (@user)'),
                  subtitle: const Text(
                    'Alerts when explicitly mentioned in chats',
                  ),
                  value: settings.enableMentions,
                  onChanged: (val) {
                    setState(() {
                      settings.enableMentions = val;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Reaction Alerts'),
                  subtitle: const Text(
                    'Alerts when someone reacts to your message',
                  ),
                  value: settings.enableReactions,
                  onChanged: (val) {
                    setState(() {
                      settings.enableReactions = val;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Incoming Call Alerts'),
                  subtitle: const Text('Voice & video calling notifications'),
                  value: settings.enableCalls,
                  onChanged: (val) {
                    setState(() {
                      settings.enableCalls = val;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Location & Emergency Alerts'),
                  subtitle: const Text('Shared location & emergency triggers'),
                  value: settings.enableLocation,
                  onChanged: (val) {
                    setState(() {
                      settings.enableLocation = val;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'QUIET HOURS (DO NOT DISTURB)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enable Quiet Hours'),
                  subtitle: const Text(
                    'Suppress non-critical alerts during set times',
                  ),
                  value: quiet.enabled,
                  onChanged: (val) {
                    setState(() {
                      settings.quietHours = QuietHoursConfig(
                        enabled: val,
                        startHour: quiet.startHour,
                        startMinute: quiet.startMinute,
                        endHour: quiet.endHour,
                        endMinute: quiet.endMinute,
                        allowEmergencyCalls: quiet.allowEmergencyCalls,
                      );
                    });
                  },
                ),
                if (quiet.enabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Quiet Hours Window'),
                    subtitle: Text(
                      '${quiet.startHour.toString().padLeft(2, '0')}:${quiet.startMinute.toString().padLeft(2, '0')} — ${quiet.endHour.toString().padLeft(2, '0')}:${quiet.endMinute.toString().padLeft(2, '0')} (Crosses Midnight)',
                    ),
                    trailing: const Icon(Icons.access_time),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Allow Emergency Calls'),
                    subtitle: const Text('Emergency alerts bypass Quiet Hours'),
                    value: quiet.allowEmergencyCalls,
                    onChanged: (val) {
                      setState(() {
                        settings.quietHours = QuietHoursConfig(
                          enabled: quiet.enabled,
                          startHour: quiet.startHour,
                          startMinute: quiet.startMinute,
                          endHour: quiet.endHour,
                          endMinute: quiet.endMinute,
                          allowEmergencyCalls: val,
                        );
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.blue.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const [
                  Icon(Icons.privacy_tip, color: Colors.blueAccent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'E2EE Privacy Guard Active: Message notifications never expose plaintext content or private keys in notification payloads or logs.',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
