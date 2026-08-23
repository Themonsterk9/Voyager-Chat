import 'package:flutter/material.dart';

import '../../../core/settings/settings_service.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final SettingsService _service = SettingsService.instance;

  @override
  Widget build(BuildContext context) {
    final privacy = _service.privacySettings;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Controls')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'PRESENCE & VISIBILITY',
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
                  title: const Text('Show Online Status'),
                  subtitle: const Text(
                    'Allow contacts to see when you are online',
                  ),
                  value: privacy.showOnlineStatus,
                  onChanged: (val) {
                    setState(() {
                      privacy.showOnlineStatus = val;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Show Last Seen Timestamp'),
                  subtitle: const Text('Display when you were last active'),
                  value: privacy.showLastSeen,
                  onChanged: (val) {
                    setState(() {
                      privacy.showLastSeen = val;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Send Read Receipts'),
                  subtitle: const Text(
                    'Allow senders to see when you read their messages',
                  ),
                  value: privacy.readReceipts,
                  onChanged: (val) {
                    setState(() {
                      privacy.readReceipts = val;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Send Typing Indicators'),
                  subtitle: const Text(
                    'Show typing indicator when composing messages',
                  ),
                  value: privacy.typingIndicators,
                  onChanged: (val) {
                    setState(() {
                      privacy.typingIndicators = val;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
