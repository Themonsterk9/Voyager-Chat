import 'package:flutter/material.dart';

import '../../../core/production/production_health_service.dart';
import '../../../core/production/security_hardening_service.dart';

class ProductionHealthScreen extends StatefulWidget {
  const ProductionHealthScreen({super.key});

  @override
  State<ProductionHealthScreen> createState() => _ProductionHealthScreenState();
}

class _ProductionHealthScreenState extends State<ProductionHealthScreen> {
  ProductionHealthReport? _report;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    setState(() => _isLoading = true);
    final report = await ProductionHealthService.instance.runHealthCheck();
    setState(() {
      _report = report;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final isRooted = SecurityHardeningService.instance
        .isDeviceJailbrokenOrRooted();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Production Health & Diagnostics'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _runCheck),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : report == null
          ? const Center(child: Text('No health data available.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: report.isDbIntegrityClean
                      ? Colors.green.shade900
                      : Colors.red.shade900,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              report.isDbIntegrityClean
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'SQLite Database Integrity',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          report.statusSummary,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.storage, color: Colors.blueAccent),
                  title: const Text('Database File Size'),
                  trailing: Text(
                    '${report.dbSizeMb} MB',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.memory, color: Colors.purpleAccent),
                  title: const Text('App Memory (RSS) Footprint'),
                  trailing: Text(
                    '${report.memoryUsageMb} MB',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    isRooted ? Icons.warning : Icons.verified_user,
                    color: isRooted ? Colors.redAccent : Colors.greenAccent,
                  ),
                  title: const Text('Root / Jailbreak Detection Status'),
                  trailing: Text(
                    isRooted ? 'ROOTED' : 'SECURE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isRooted ? Colors.redAccent : Colors.greenAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text('Re-Run Diagnostics Audit'),
                  onPressed: _runCheck,
                ),
              ],
            ),
    );
  }
}
