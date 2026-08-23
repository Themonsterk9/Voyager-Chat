import 'package:flutter/widgets.dart';

import '../database/app_database.dart';

class PerformanceOptimizerService {
  PerformanceOptimizerService._();

  static final PerformanceOptimizerService instance =
      PerformanceOptimizerService._();

  Future<bool> vacuumDatabase() async {
    try {
      final db = await AppDatabase.instance.database;
      try {
        await db.execute('PRAGMA wal_checkpoint(FULL)');
      } catch (_) {}
      await db.execute('VACUUM');
      return true;
    } catch (_) {
      return false;
    }
  }

  int trimMediaCaches() {
    int bytesFreed = 0;
    try {
      final cache = PaintingBinding.instance.imageCache;
      final currentSize = cache.currentSizeBytes;
      cache.clear();
      cache.clearLiveImages();
      bytesFreed = currentSize;
    } catch (_) {}
    return bytesFreed;
  }
}
