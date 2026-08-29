import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/services/auth_service.dart';
import '../../chat/repositories/local_chat_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.onThemeModeChanged,
    required this.currentThemeMode,
  });

  final void Function(ThemeMode mode) onThemeModeChanged;
  final ThemeMode currentThemeMode;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Local Cache'),
        content: const Text(
          'This will delete offline cached messages and reload them from Supabase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await LocalChatRepository.instance.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local cache cleared successfully.')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out of Voyager Chat?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.instance.logout();
      if (mounted) {
        context.go('/welcome');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService.instance.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'ACCOUNT & SECURITY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Edit Profile'),
            subtitle: const Text('Name, username, and avatar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (currentUserId != null) {
                context.push('/profile/$currentUserId');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.devices, color: Colors.blueAccent),
            title: const Text('Registered Devices & Sessions'),
            subtitle: const Text('Active device sessions & revocation'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/devices'),
          ),
          ListTile(
            leading: const Icon(Icons.shield, color: Colors.greenAccent),
            title: const Text('Feature Permissions Onboarding'),
            subtitle: const Text(
              'Manage camera, microphone, location & notifications',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/permission-onboarding'),
          ),
          ListTile(
            leading: const Icon(Icons.security, color: Colors.orangeAccent),
            title: const Text('Account Security & Data Export'),
            subtitle: const Text('Data export JSON & account deletion'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/security'),
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy, color: Colors.purpleAccent),
            title: const Text('AI & Smart Assistant Preferences'),
            subtitle: const Text(
              'COMING SOON - Smart Replies, Translation & AI',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI Assistant features are Coming Soon!')),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.health_and_safety,
              color: Colors.tealAccent,
            ),
            title: const Text('Production Health & Diagnostics'),
            subtitle: const Text('SQLite PRAGMA check, RAM & root audit'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/production-health'),
          ),
          ListTile(
            leading: const Icon(Icons.rocket_launch, color: Colors.blueAccent),
            title: const Text('App Version & Deployment Info'),
            subtitle: const Text('Version 1.0.0+1, updates & compliance'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/release-info'),
          ),
          ListTile(
            leading: const Icon(
              Icons.admin_panel_settings,
              color: Colors.deepOrangeAccent,
            ),
            title: const Text('Enterprise Governance & Audit Logs'),
            subtitle: const Text('Hash chain audit logs, retention & wipe'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/enterprise-governance'),
          ),
          ListTile(
            leading: const Icon(
              Icons.monitor_heart,
              color: Colors.indigoAccent,
            ),
            title: const Text('Operations & Telemetry Monitoring'),
            subtitle: const Text('Live metrics, crash recovery & DB vacuum'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/operations-monitoring'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'DATA, STORAGE & BACKUP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sd_storage, color: Colors.amberAccent),
            title: const Text('Data Usage & Encrypted Backup'),
            subtitle: const Text(
              'Passphrase backup, LRU cache eviction & metrics',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/storage-backup'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'PRIVACY & CHAT PREFERENCES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: Colors.purpleAccent),
            title: const Text('Privacy Controls'),
            subtitle: const Text('Online status, last seen & read receipts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/privacy'),
          ),
          ListTile(
            leading: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.tealAccent,
            ),
            title: const Text('Chat Preferences'),
            subtitle: const Text('Enter key, auto-download & timestamps'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/chat-preferences'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'NOTIFICATIONS & QUIET HOURS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.notifications_active,
              color: Colors.blueAccent,
            ),
            title: const Text('Notification Rules & Quiet Hours'),
            subtitle: const Text(
              'Category toggles, Do Not Disturb & E2EE privacy',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/notifications'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'CALLS & MEDIA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone, color: Colors.greenAccent),
            title: const Text('Call History'),
            subtitle: const Text('COMING SOON - Voice & video calls'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice & Video calling features are Coming Soon!')),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'APPEARANCE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          RadioGroup<ThemeMode>(
            groupValue: widget.currentThemeMode,
            onChanged: (val) {
              if (val != null) widget.onThemeModeChanged(val);
            },
            child: Column(
              children: const [
                RadioListTile<ThemeMode>(
                  title: Text('Dark Mode (Default)'),
                  value: ThemeMode.dark,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Light Mode'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('System Mode'),
                  value: ThemeMode.system,
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'LOCATION & MAPS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.map, color: Colors.blueAccent),
            title: const Text('OpenStreetMap & Emergency Share'),
            subtitle: const Text(
              'COMING SOON - Interactive map & live location',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Location sharing features are Coming Soon!')),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'SECURITY & PRIVACY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock, color: Colors.greenAccent),
            title: const Text('End-to-End Encryption'),
            subtitle: const Text(
              'Safety fingerprints, identity keys & MAC verification',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/e2ee'),
          ),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.redAccent),
            title: const Text('Blocked Users'),
            subtitle: const Text('Manage blocked profiles'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/blocked-users'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'OFFLINE & TRANSPORT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.radar, color: Colors.purpleAccent),
            title: const Text('Nearby Devices & BLE Mesh'),
            subtitle: const Text(
              'Peer discovery, BLE status & store-and-forward queue',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/nearby'),
          ),
          ListTile(
            leading: const Icon(
              Icons.health_and_safety,
              color: Colors.greenAccent,
            ),
            title: const Text('System Diagnostics'),
            subtitle: const Text(
              'Database health, table metrics & report export',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/diagnostics'),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear Local Database Cache'),
            subtitle: const Text('Purge SQLite offline message database'),
            onTap: _clearCache,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Log Out',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
