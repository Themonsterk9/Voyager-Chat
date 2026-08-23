import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';

class ProductionHealthReport {
  const ProductionHealthReport({
    required this.isDbIntegrityClean,
    required this.dbSizeMb,
    required this.memoryUsageMb,
    required this.timestamp,
    required this.statusSummary,
  });

  final bool isDbIntegrityClean;
  final double dbSizeMb;
  final double memoryUsageMb;
  final DateTime timestamp;
  final String statusSummary;
}

class ProductionHealthService {
  ProductionHealthService._();

  static final ProductionHealthService instance = ProductionHealthService._();

  Future<ProductionHealthReport> runHealthCheck() async {
    bool isDbClean = true;
    double dbSize = 0.0;

    try {
      final db = await AppDatabase.instance.database;
      final result = await db.rawQuery('PRAGMA integrity_check');
      if (result.isNotEmpty) {
        final val = result.first.values.first.toString().toLowerCase();
        isDbClean = val == 'ok';
      }

      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'voyager_chat.db');
      final dbFile = File(path);
      if (await dbFile.exists()) {
        final bytes = await dbFile.length();
        dbSize = bytes / (1024 * 1024);
      }
    } catch (_) {
      isDbClean = false;
    }

    final currentRamMb = ProcessInfo.currentRss / (1024 * 1024);

    return ProductionHealthReport(
      isDbIntegrityClean: isDbClean,
      dbSizeMb: double.parse(dbSize.toStringAsFixed(2)),
      memoryUsageMb: double.parse(currentRamMb.toStringAsFixed(2)),
      timestamp: DateTime.now(),
      statusSummary: isDbClean
          ? 'SYSTEM HEALTH OK: SQLite integrity verified cleanly.'
          : 'WARNING: SQLite integrity check flagged issues.',
    );
  }
}
