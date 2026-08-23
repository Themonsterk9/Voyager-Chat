import 'package:flutter/material.dart';

import '../../../core/settings/settings_service.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  final SettingsService _service = SettingsService.instance;

  @override
  Widget build(BuildContext context) {
    final chat = _service.chatSettings;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'COMPOSER & MESSAGE DISPLAY',
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
                  title: const Text('Enter Key Sends Message'),
                  subtitle: const Text(
                    'Pressing Enter on keyboard sends message immediately',
                  ),
                  value: chat.enterToSend,
                  onChanged: (val) {
                    setState(() {
                      chat.enterToSend = val;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Media Auto-Download'),
                  subtitle: const Text(
                    'Automatically download incoming media over Wi-Fi/Cellular',
                  ),
                  value: chat.mediaAutoDownload,
                  onChanged: (val) {
                    setState(() {
                      chat.mediaAutoDownload = val;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Show Timestamps'),
                  subtitle: const Text(
                    'Display creation timestamps on chat bubbles',
                  ),
                  value: chat.showTimestamps,
                  onChanged: (val) {
                    setState(() {
                      chat.showTimestamps = val;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Rich Link Previews'),
                  subtitle: const Text(
                    'Generate visual previews for shared URLs',
                  ),
                  value: chat.linkPreviews,
                  onChanged: (val) {
                    setState(() {
                      chat.linkPreviews = val;
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
