import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/operations/crash_recovery_service.dart';
import '../../../core/operations/operational_telemetry_service.dart';
import '../../../core/operations/performance_optimizer_service.dart';

class OperationsMonitoringScreen extends StatefulWidget {
  const OperationsMonitoringScreen({super.key});

  @override
  State<OperationsMonitoringScreen> createState() =>
      _OperationsMonitoringScreenState();
}

class _OperationsMonitoringScreenState
    extends State<OperationsMonitoringScreen> {
  bool _isOptimizing = false;
  bool _isLoading = true;

  String _sqliteHealth = 'HEALTHY';
  double _dbSizeMb = 0.0;
  int _pendingQueueCount = 0;
  Timer? _liveRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTelemetryMetrics();
    _liveRefreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadTelemetryMetrics(isSilent: true),
    );
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTelemetryMetrics({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoading = true);
    }

    OperationalTelemetryService.instance.recordSnapshot();

    final health = await OperationalTelemetryService.instance
        .checkDatabaseIntegrity();
    final dbSize = await OperationalTelemetryService.instance
        .getDatabaseSizeMb();
    final queue = await OperationalTelemetryService.instance
        .getPendingQueueCount();

    if (mounted) {
      setState(() {
        _sqliteHealth = health;
        _dbSizeMb = dbSize;
        _pendingQueueCount = queue;
        _isLoading = false;
      });
    }
  }

  Color _getHealthColor(String health) {
    switch (health) {
      case 'HEALTHY':
        return Colors.greenAccent;
      case 'CORRUPTED':
        return Colors.redAccent;
      case 'UNAVAILABLE':
      default:
        return Colors.amberAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = OperationalTelemetryService.instance.latestSnapshot;
    final crashRecovery = CrashRecoveryService.instance;
    final healthColor = _getHealthColor(_sqliteHealth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operations & Telemetry Monitoring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadTelemetryMetrics(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Privacy-First Local Telemetry Badge
                Card(
                  color: const Color(0xFF0F172A),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.shield_outlined,
                          color: Colors.greenAccent,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Privacy-First Local Telemetry: Zero plaintext, API keys, or E2EE message content collected.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Live System Performance Card
                Card(
                  color: Colors.blueGrey.shade900,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'LIVE SYSTEM PERFORMANCE & METRICS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'AUTO-REFRESH (3s)',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _metricTile(
                                'RAM Usage',
                                '${telemetry.ramUsageMb.toStringAsFixed(1)} MB',
                              ),
                              const SizedBox(width: 16),
                              _metricTile(
                                'FPS',
                                telemetry.fps.toStringAsFixed(0),
                              ),
                              const SizedBox(width: 16),
                              _metricTile(
                                'Latency',
                                '${telemetry.networkLatencyMs} ms',
                              ),
                              const SizedBox(width: 16),
                              _metricTile(
                                'DB Size',
                                '${_dbSizeMb.toStringAsFixed(2)} MB',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Database Health & SQLite Integrity Status Card
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          _sqliteHealth == 'HEALTHY'
                              ? Icons.check_circle_rounded
                              : _sqliteHealth == 'CORRUPTED'
                              ? Icons.cancel_rounded
                              : Icons.warning_rounded,
                          color: healthColor,
                        ),
                        title: const Text('SQLite Database Integrity'),
                        subtitle: const Text(
                          'PRAGMA integrity_check & Schema Validation',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: healthColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: healthColor),
                          ),
                          child: Text(
                            _sqliteHealth,
                            style: TextStyle(
                              color: healthColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.queue_rounded,
                          color: Colors.cyanAccent,
                        ),
                        title: const Text('Pending Operations & Sync Queue'),
                        subtitle: Text(
                          'Unsent Messages in Queue: $_pendingQueueCount',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Crash Recovery Engine Section
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.build_circle,
                      color: Colors.greenAccent,
                    ),
                    title: const Text('Crash Recovery Engine'),
                    subtitle: Text(
                      'Status: ${crashRecovery.wasAbnormalShutdown ? "RECOVERED FROM CRASH" : "CLEAN"} (${crashRecovery.capturedErrors.length} errors logged)',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.cleaning_services),
                      tooltip: 'Clear Orphaned Lock Files',
                      onPressed: () async {
                        final count = await crashRecovery
                            .recoverOrphanedLocks();
                        await _loadTelemetryMetrics();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Cleared $count orphaned lock files',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Continuous Performance Optimizer Section
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.storage,
                      color: Colors.purpleAccent,
                    ),
                    title: const Text('Continuous Performance Optimizer'),
                    subtitle: const Text(
                      'Database VACUUM & Media Cache Trimming',
                    ),
                    trailing: _isOptimizing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : ElevatedButton(
                            onPressed: () async {
                              setState(() => _isOptimizing = true);
                              final vacuumSuccess =
                                  await PerformanceOptimizerService.instance
                                      .vacuumDatabase();
                              final freedBytes = PerformanceOptimizerService
                                  .instance
                                  .trimMediaCaches();
                              await _loadTelemetryMetrics();
                              setState(() => _isOptimizing = false);
                              if (context.mounted) {
                                final message = vacuumSuccess
                                    ? 'VACUUM complete. Freed ${(freedBytes / (1024 * 1024)).toStringAsFixed(1)} MB.'
                                    : 'Media cache cleared. Database VACUUM deferred due to active locks.';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              }
                            },
                            child: const Text('Optimize'),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
