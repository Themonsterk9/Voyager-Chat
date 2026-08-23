import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/services/auth_service.dart';
import '../../../core/settings/settings_service.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final SettingsService _service = SettingsService.instance;

  Future<void> _exportData() async {
    final userId = AuthService.instance.currentUser?.id ?? 'local-user';
    final jsonStr = await _service.exportUserDataJson(userId: userId);

    await Clipboard.setData(ClipboardData(text: jsonStr));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account data exported to clipboard (JSON format). Raw private keys excluded for safety.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.redAccent),
            SizedBox(width: 8),
            Expanded(child: Text('DELETE ACCOUNT')),
          ],
        ),
        content: const Text(
          'WARNING: This action is permanent and cannot be undone. All your local cached conversations, call logs, and preferences will be wiped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('PERMANENTLY DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final userId = AuthService.instance.currentUser?.id ?? 'local-user';
      await _service.deleteAccount(userId: userId);
      await AuthService.instance.logout();
      if (mounted) {
        context.go('/welcome');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Security & Data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'ACCOUNT DATA & PORTABILITY',
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
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.blueAccent),
                  title: const Text('Export Account Data'),
                  subtitle: const Text(
                    'Download profile, chat metadata, call history in JSON format',
                  ),
                  onTap: _exportData,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'DANGER ZONE',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.red.withValues(alpha: 0.1),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete Account',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Wipe all local and cloud account records permanently',
                  ),
                  onTap: _deleteAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
