import 'dart:async';
import 'dart:math';

import '../database/app_database.dart';
import 'media_models.dart';

class MediaService {
  MediaService._();

  static final MediaService instance = MediaService._();

  final Map<String, MediaTransferProgress> _activeTransfers = {};

  // Stream controller for transfer progress updates
  final StreamController<MediaTransferProgress> _progressController =
      StreamController<MediaTransferProgress>.broadcast();

  Stream<MediaTransferProgress> get transferProgressStream =>
      _progressController.stream;

  // E2EE Binary Attachment Encryption Engine (AES-GCM simulation / Key Stream)
  List<int> encryptAttachmentBytes(List<int> rawBytes, List<int> secretKey) {
    if (secretKey.isEmpty) return rawBytes;
    final encrypted = <int>[];
    for (int i = 0; i < rawBytes.length; i++) {
      encrypted.add(rawBytes[i] ^ secretKey[i % secretKey.length]);
    }
    return encrypted;
  }

  // E2EE Binary Attachment Decryption Engine
  List<int> decryptAttachmentBytes(
    List<int> encryptedBytes,
    List<int> secretKey,
  ) {
    return encryptAttachmentBytes(encryptedBytes, secretKey);
  }

  Future<void> saveAttachment(MediaAttachment attachment) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.insert('message_attachments', {
        'id': attachment.id,
        'message_id': attachment.messageId,
        'file_name': attachment.fileName,
        'file_size': attachment.fileSize,
        'mime_type': attachment.mimeType,
        'storage_url': attachment.storageUrl,
        'local_path': attachment.localPath,
        'duration_seconds': attachment.durationSeconds,
        'thumbnail_url': attachment.thumbnailUrl,
        'is_encrypted': attachment.isEncrypted ? 1 : 0,
      });
    } catch (_) {}
  }

  Future<List<MediaAttachment>> getAttachmentsForMessage(
    String messageId,
  ) async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'message_attachments',
        where: 'message_id = ?',
        whereArgs: [messageId],
      );

      return rows.map((r) {
        return MediaAttachment(
          id: r['id'] as String,
          messageId: r['message_id'] as String,
          fileName: r['file_name'] as String,
          fileSize: r['file_size'] as int,
          mimeType: r['mime_type'] as String,
          storageUrl: r['storage_url'] as String?,
          localPath: r['local_path'] as String?,
          durationSeconds: (r['duration_seconds'] as num?)?.toInt() ?? 0,
          thumbnailUrl: r['thumbnail_url'] as String?,
          isEncrypted: (r['is_encrypted'] as int?) == 1,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void startTransferSimulation(String itemId, int totalBytes) {
    _activeTransfers[itemId] = MediaTransferProgress(
      itemId: itemId,
      bytesTransferred: 0,
      totalBytes: totalBytes,
      status: MediaTransferStatus.transferring,
    );
    _progressController.add(_activeTransfers[itemId]!);
  }

  void pauseTransfer(String itemId) {
    final current = _activeTransfers[itemId];
    if (current != null) {
      _activeTransfers[itemId] = MediaTransferProgress(
        itemId: itemId,
        bytesTransferred: current.bytesTransferred,
        totalBytes: current.totalBytes,
        status: MediaTransferStatus.paused,
      );
      _progressController.add(_activeTransfers[itemId]!);
    }
  }

  void resumeTransfer(String itemId) {
    final current = _activeTransfers[itemId];
    if (current != null) {
      _activeTransfers[itemId] = MediaTransferProgress(
        itemId: itemId,
        bytesTransferred: min(
          current.bytesTransferred + 1024,
          current.totalBytes,
        ),
        totalBytes: current.totalBytes,
        status: MediaTransferStatus.transferring,
      );
      _progressController.add(_activeTransfers[itemId]!);
    }
  }

  void completeTransfer(String itemId) {
    final current = _activeTransfers[itemId];
    if (current != null) {
      _activeTransfers[itemId] = MediaTransferProgress(
        itemId: itemId,
        bytesTransferred: current.totalBytes,
        totalBytes: current.totalBytes,
        status: MediaTransferStatus.completed,
      );
      _progressController.add(_activeTransfers[itemId]!);
    }
  }

  MediaTransferProgress? getTransferProgress(String itemId) =>
      _activeTransfers[itemId];
}
