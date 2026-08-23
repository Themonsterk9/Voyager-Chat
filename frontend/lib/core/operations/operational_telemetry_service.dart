import 'dart:io';

import '../database/app_database.dart';

class PerformanceSnapshot {
  const PerformanceSnapshot({
    required this.ramUsageMb,
    required this.networkLatencyMs,
    required this.messageDeliveryLatencyMs,
    required this.fps,
    required this.timestamp,
  });

  final double ramUsageMb;
  final int networkLatencyMs;
  final int messageDeliveryLatencyMs;
  final double fps;
  final DateTime timestamp;
}

class OperationalTelemetryService {
  OperationalTelemetryService._();

  static final OperationalTelemetryService instance =
      OperationalTelemetryService._();

  final List<PerformanceSnapshot> _history = [];

  double _getRealRamUsageMb() {
    try {
      final bytes = ProcessInfo.currentRss;
      if (bytes > 0) {
        return bytes / (1024 * 1024);
      }
    } catch (_) {}
    return 0.0;
  }

  void recordSnapshot({
    double? ramUsageMb,
    int networkLatencyMs = 0,
    int messageDeliveryLatencyMs = 0,
    double fps = 60.0,
  }) {
    final snapshot = PerformanceSnapshot(
      ramUsageMb: ramUsageMb ?? _getRealRamUsageMb(),
      networkLatencyMs: networkLatencyMs,
      messageDeliveryLatencyMs: messageDeliveryLatencyMs,
      fps: fps,
      timestamp: DateTime.now(),
    );

    _history.add(snapshot);
    if (_history.length > 100) {
      _history.removeAt(0);
    }
  }

  List<PerformanceSnapshot> getHistory() => List.unmodifiable(_history);

  PerformanceSnapshot get latestSnapshot {
    if (_history.isNotEmpty) return _history.last;
    return PerformanceSnapshot(
      ramUsageMb: _getRealRamUsageMb(),
      networkLatencyMs: 0,
      messageDeliveryLatencyMs: 0,
      fps: 60.0,
      timestamp: DateTime.now(),
    );
  }

  Future<String> checkDatabaseIntegrity() async {
    try {
      final db = await AppDatabase.instance.database;
      final result = await db.rawQuery('PRAGMA integrity_check');
      if (result.isNotEmpty && result.first.values.first == 'ok') {
        return 'HEALTHY';
      }
      return 'CORRUPTED';
    } catch (_) {
      return 'UNAVAILABLE';
    }
  }

  Future<double> getDatabaseSizeMb() async {
    try {
      final db = await AppDatabase.instance.database;
      final pageCountRes = await db.rawQuery('PRAGMA page_count');
      final pageSizeRes = await db.rawQuery('PRAGMA page_size');
      if (pageCountRes.isNotEmpty && pageSizeRes.isNotEmpty) {
        final pageCount = (pageCountRes.first.values.first as num).toInt();
        final pageSize = (pageSizeRes.first.values.first as num).toInt();
        final bytes = pageCount * pageSize;
        return bytes / (1024 * 1024);
      }
    } catch (_) {}
    return 0.0;
  }

  Future<int> getPendingQueueCount() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query('pending_messages');
      return rows.length;
    } catch (_) {
      return 0;
    }
  }
}
