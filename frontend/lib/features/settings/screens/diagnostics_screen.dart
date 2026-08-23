import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/diagnostics_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final DiagnosticsService _diagnosticsService = DiagnosticsService.instance;

  SystemDiagnostics? _diagnostics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _loading = true;
    });
    final report = await _diagnosticsService.runDiagnostics();
    if (mounted) {
      setState(() {
        _diagnostics = report;
        _loading = false;
      });
    }
  }

  Future<void> _copyReport() async {
    if (_diagnostics != null) {
      await Clipboard.setData(
        ClipboardData(text: _diagnostics!.exportReport()),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Diagnostics report copied to clipboard!'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runDiagnostics,
          ),
          IconButton(icon: const Icon(Icons.copy), onPressed: _copyReport),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.check_circle, color: Colors.greenAccent),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'SYSTEM STATUS: HEALTHY',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('SQLite DB Version: ${_diagnostics?.dbVersion}'),
                        Text(
                          'Auth Status: ${_diagnostics?.isAuthenticated == true ? "Authenticated (${_diagnostics?.currentUserEmail})" : "Not Authenticated"}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.forum),
                        title: const Text('Cached Conversations'),
                        trailing: Text(
                          '${_diagnostics?.conversationCount}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.message),
                        title: const Text('Cached Messages'),
                        trailing: Text(
                          '${_diagnostics?.messageCount}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.pending_actions),
                        title: const Text('Pending Offline Messages'),
                        trailing: Text(
                          '${_diagnostics?.pendingMessageCount}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.add_reaction),
                        title: const Text('Message Reactions'),
                        trailing: Text(
                          '${_diagnostics?.reactionCount}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Diagnostics Report'),
                  onPressed: _copyReport,
                ),
              ],
            ),
    );
  }
}
