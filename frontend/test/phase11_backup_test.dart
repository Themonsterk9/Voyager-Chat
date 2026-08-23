import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/storage/encrypted_backup_service.dart';
import 'package:frontend/core/storage/media_cache_manager.dart';
import 'package:frontend/features/chat/models/message.dart';
import 'package:frontend/features/chat/repositories/local_chat_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 11 Data, Storage & Backup Tests (Steps 221-240)', () {
    late EncryptedBackupService backupService;
    late MediaCacheManager cacheManager;
    late LocalChatRepository localRepo;

    setUp(() {
      backupService = EncryptedBackupService.instance;
      cacheManager = MediaCacheManager.instance;
      localRepo = LocalChatRepository.instance;
    });

    test(
      'TEST 1 & 2: Encrypted backup creation format and passphrase protection',
      () async {
        const passphrase = 'MySecretPassphrase123!';
        final backupPayload = await backupService.createBackup(
          userId: 'user-backup-test',
          passphrase: passphrase,
        );

        expect(backupPayload, startsWith('[VOYAGER-BACKUP-v1:'));
        expect(backupPayload, endsWith(']'));
        expect(backupPayload.contains('MySecretPassphrase123!'), isFalse);
      },
    );

    test('TEST 3 & 4: Backup restore rejects invalid passphrase (MAC tampering check)', () async {
      const passphrase = 'CorrectPassphrase!123';
      const wrongPassphrase = 'WrongPassphrase!999';

      final backupPayload = await backupService.createBackup(
        userId: 'user-backup-mac',
        passphrase: passphrase,
      );

      expect(
        () async => await backupService.restoreBackup(
          backupPayload: backupPayload,
          passphrase: wrongPassphrase,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('TEST 5: Backup restore with correct passphrase succeeds', () async {
      const passphrase = 'ValidPassphrase!777';

      final backupPayload = await backupService.createBackup(
        userId: 'user-backup-valid',
        passphrase: passphrase,
      );

      final success = await backupService.restoreBackup(
        backupPayload: backupPayload,
        passphrase: passphrase,
      );

      expect(success, isTrue);
    });

    test('TEST 6: Message pagination retrieves correct subset', () async {
      const convId = 'conv-paginated-1';
      final msg = Message(
        id: 'msg-p1',
        conversationId: convId,
        senderId: 'sender-1',
        content: 'Paginated message',
        createdAt: DateTime.now(),
      );

      await localRepo.saveMessage(msg);

      final page = await localRepo.getMessagesPaginated(
        convId,
        limit: 10,
        offset: 0,
      );
      expect(page, isNotEmpty);
      expect(page.first.id, equals('msg-p1'));
    });

    test(
      'TEST 7 & 8: Storage metrics calculation and LRU cache eviction',
      () async {
        final metrics = await cacheManager.getStorageMetrics();
        expect(metrics.databaseSizeBytes, greaterThan(0));

        await cacheManager.evictOldestCache();
        final evictedMetrics = await cacheManager.getStorageMetrics();
        expect(evictedMetrics.mediaCacheSizeBytes, equals(0));
      },
    );
  });
}
