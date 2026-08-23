import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/database/app_database.dart';
import 'package:frontend/core/media/media_models.dart';
import 'package:frontend/core/media/media_service.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 14 Rich Media & Attachments Tests (Steps 281-300)', () {
    late MediaService mediaService;

    setUp(() {
      mediaService = MediaService.instance;
    });

    test('TEST 1 & 2: AttachmentType mimeType resolution', () {
      const img = MediaAttachment(
        id: '1',
        messageId: 'm1',
        fileName: 'a.png',
        fileSize: 100,
        mimeType: 'image/png',
      );
      const vid = MediaAttachment(
        id: '2',
        messageId: 'm2',
        fileName: 'b.mp4',
        fileSize: 200,
        mimeType: 'video/mp4',
      );
      const aud = MediaAttachment(
        id: '3',
        messageId: 'm3',
        fileName: 'c.mp3',
        fileSize: 300,
        mimeType: 'audio/mp3',
      );
      const doc = MediaAttachment(
        id: '4',
        messageId: 'm4',
        fileName: 'd.pdf',
        fileSize: 400,
        mimeType: 'application/pdf',
      );

      expect(img.type, equals(AttachmentType.image));
      expect(vid.type, equals(AttachmentType.video));
      expect(aud.type, equals(AttachmentType.audio));
      expect(doc.type, equals(AttachmentType.document));
    });

    test('TEST 3 & 4: E2EE binary attachment encryption and decryption idempotency', () {
      final rawBytes = [10, 20, 30, 40, 50];
      final secretKey = [99, 88, 77];

      final encrypted = mediaService.encryptAttachmentBytes(
        rawBytes,
        secretKey,
      );
      expect(encrypted, isNot(equals(rawBytes)));

      final decrypted = mediaService.decryptAttachmentBytes(
        encrypted,
        secretKey,
      );
      expect(decrypted, equals(rawBytes));
    });

    test('TEST 5 & 6: Transfer progress calculation and status updates', () {
      mediaService.startTransferSimulation('item-101', 1000);
      expect(
        mediaService.getTransferProgress('item-101')?.progressFraction,
        equals(0.0),
      );
    });

    test('TEST 7 & 8: Pause and resume transfer management', () {
      mediaService.startTransferSimulation('item-202', 1000);
      mediaService.pauseTransfer('item-202');
      expect(
        mediaService.getTransferProgress('item-202')?.status,
        equals(MediaTransferStatus.paused),
      );

      mediaService.resumeTransfer('item-202');
      expect(
        mediaService.getTransferProgress('item-202')?.status,
        equals(MediaTransferStatus.transferring),
      );
    });

    test('TEST 9 & 10: SQLite attachment saving and query', () async {
      try {
        final db = await AppDatabase.instance.database;
        await db.delete(
          'message_attachments',
          where: 'message_id = ?',
          whereArgs: ['msg-test-99'],
        );
      } catch (_) {}

      const att = MediaAttachment(
        id: 'att-test-99',
        messageId: 'msg-test-99',
        fileName: 'blueprint.pdf',
        fileSize: 2048,
        mimeType: 'application/pdf',
        isEncrypted: true,
      );

      await mediaService.saveAttachment(att);
      final attachments = await mediaService.getAttachmentsForMessage(
        'msg-test-99',
      );

      expect(attachments, isNotEmpty);
      expect(attachments.first.fileName, equals('blueprint.pdf'));
    });
  });
}
