import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/auth/services/auth_service.dart';
import '../../../core/storage/encrypted_backup_service.dart';
import '../../../core/storage/media_cache_manager.dart';

class StorageBackupScreen extends StatefulWidget {
  const StorageBackupScreen({super.key});

  @override
  State<StorageBackupScreen> createState() => _StorageBackupScreenState();
}

class _StorageBackupScreenState extends State<StorageBackupScreen> {
  final MediaCacheManager _cacheManager = MediaCacheManager.instance;
  final EncryptedBackupService _backupService = EncryptedBackupService.instance;

  StorageUsageMetrics? _metrics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    final metrics = await _cacheManager.getStorageMetrics();
    if (mounted) {
      setState(() {
        _metrics = metrics;
        _isLoading = false;
      });
    }
  }

  Future<void> _evictCache() async {
    await _cacheManager.evictOldestCache();
    await _loadMetrics();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Temporary media cache purged safely.')),
      );
    }
  }

  Future<void> _createBackup() async {
    final passphraseController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Encrypted Backup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter a strong passphrase to encrypt your backup payload (HKDF + AES-GCM 256-bit).',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passphraseController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Backup Passphrase',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create & Copy'),
          ),
        ],
      ),
    );

    if (confirm == true && passphraseController.text.isNotEmpty) {
      final userId = AuthService.instance.currentUser?.id ?? 'local-user';
      final backupStr = await _backupService.createBackup(
        userId: userId,
        passphrase: passphraseController.text,
      );

      await Clipboard.setData(ClipboardData(text: backupStr));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Encrypted backup string copied to clipboard! Keep your passphrase safe.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    final passphraseController = TextEditingController();
    final payloadController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Encrypted Backup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: payloadController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Backup String ([VOYAGER-BACKUP-v1:...])',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passphraseController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Passphrase',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore Data'),
          ),
        ],
      ),
    );

    if (confirm == true &&
        payloadController.text.isNotEmpty &&
        passphraseController.text.isNotEmpty) {
      try {
        await _backupService.restoreBackup(
          backupPayload: payloadController.text,
          passphrase: passphraseController.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup restored successfully! Messages merged.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Restore failed: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data, Storage & Backup')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'STORAGE USAGE METRICS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('SQLite Database Size'),
                            Text(
                              _metrics?.formattedDatabaseSize ?? '0 MB',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Media Attachment Cache'),
                            Text(
                              _metrics?.formattedMediaCacheSize ?? '0 MB',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _evictCache,
                          icon: const Icon(Icons.cleaning_services),
                          label: const Text('Purge Media Cache (LRU)'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ENCRYPTED BACKUP & RESTORE',
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
                        leading: const Icon(
                          Icons.shield_outlined,
                          color: Colors.greenAccent,
                        ),
                        title: const Text('Create Passphrase-Encrypted Backup'),
                        subtitle: const Text(
                          'Encrypt local messages & settings with HKDF + AES-GCM',
                        ),
                        onTap: _createBackup,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.settings_backup_restore,
                          color: Colors.blueAccent,
                        ),
                        title: const Text('Restore Encrypted Backup'),
                        subtitle: const Text(
                          'Import and merge messages safely using passphrase',
                        ),
                        onTap: _restoreBackup,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
