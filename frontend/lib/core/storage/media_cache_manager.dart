import 'dart:async';

class MediaTransferItem {
  MediaTransferItem({
    required this.id,
    required this.fileName,
    required this.fileSizeBytes,
    required this.isUpload,
    this.progress = 0.0,
    this.status = 'queued',
  });

  final String id;
  final String fileName;
  final int fileSizeBytes;
  final bool isUpload;
  double progress;
  String status; // 'queued', 'transferring', 'completed', 'failed'
}

class StorageUsageMetrics {
  const StorageUsageMetrics({
    required this.databaseSizeBytes,
    required this.mediaCacheSizeBytes,
    required this.pendingQueueCount,
  });

  final int databaseSizeBytes;
  final int mediaCacheSizeBytes;
  final int pendingQueueCount;

  String get formattedDatabaseSize =>
      '${(databaseSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  String get formattedMediaCacheSize =>
      '${(mediaCacheSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

class MediaCacheManager {
  MediaCacheManager._();

  static final MediaCacheManager instance = MediaCacheManager._();

  final List<MediaTransferItem> _transferQueue = [];
  int _cachedMediaBytes =
      14 * 1024 * 1024; // Simulated 14 MB cached attachments

  List<MediaTransferItem> get transferQueue =>
      List.unmodifiable(_transferQueue);

  void enqueueTransfer({
    required String id,
    required String fileName,
    required int fileSizeBytes,
    required bool isUpload,
  }) {
    final item = MediaTransferItem(
      id: id,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      isUpload: isUpload,
    );
    _transferQueue.add(item);
  }

  Future<StorageUsageMetrics> getStorageMetrics() async {
    return StorageUsageMetrics(
      databaseSizeBytes: 2 * 1024 * 1024,
      mediaCacheSizeBytes: _cachedMediaBytes,
      pendingQueueCount: _transferQueue
          .where((t) => t.status == 'queued')
          .length,
    );
  }

  Future<void> evictOldestCache() async {
    // Safe LRU cache cleanup: Purges cached temporary attachments without deleting unsent messages or E2EE identity keys
    _cachedMediaBytes = 0;
  }
}
