enum AttachmentType { image, video, audio, document }

enum MediaTransferStatus { pending, transferring, paused, completed, failed }

class MediaAttachment {
  const MediaAttachment({
    required this.id,
    required this.messageId,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    this.storageUrl,
    this.localPath,
    this.durationSeconds = 0,
    this.thumbnailUrl,
    this.isEncrypted = true,
  });

  final String id;
  final String messageId;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String? storageUrl;
  final String? localPath;
  final int durationSeconds;
  final String? thumbnailUrl;
  final bool isEncrypted;

  AttachmentType get type {
    if (mimeType.startsWith('image/')) return AttachmentType.image;
    if (mimeType.startsWith('video/')) return AttachmentType.video;
    if (mimeType.startsWith('audio/')) return AttachmentType.audio;
    return AttachmentType.document;
  }
}

class MediaTransferProgress {
  const MediaTransferProgress({
    required this.itemId,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.status,
  });

  final String itemId;
  final int bytesTransferred;
  final int totalBytes;
  final MediaTransferStatus status;

  double get progressFraction =>
      totalBytes > 0 ? bytesTransferred / totalBytes : 0.0;
}
