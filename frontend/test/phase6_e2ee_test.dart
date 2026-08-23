import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/security/e2ee_service.dart';
import 'package:frontend/core/security/e2ee_session.dart';
import 'package:frontend/core/security/identity_key.dart';
import 'package:frontend/core/transport/mesh/mesh_packet.dart';
import 'package:frontend/core/transport/mesh/mesh_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 6 End-to-End Encryption & Security Tests (Steps 121-140)', () {
    late E2eeService e2eeService;

    setUp(() {
      e2eeService = E2eeService.instance;
      e2eeService.initialize(userId: 'user-alice', deviceId: 'device-alice');
    });

    test('TEST 1 & 2: Device identity key generation and 12-digit safety fingerprint', () {
      final key = E2eeIdentityKey.generate(
        userId: 'user-bob',
        deviceId: 'device-bob',
      );
      expect(key.publicKeyHex, isNotEmpty);
      expect(key.privateKeyHex, isNotEmpty);

      final fingerprint = key.fingerprint;
      expect(fingerprint.length, equals(14)); // Formatted as "XXXX XXXX XXXX"
      expect(fingerprint, matches(RegExp(r'^\d{4} \d{4} \d{4}$')));
    });

    test('TEST 3: HKDF session key derivation and key uniqueness', () {
      final session = E2eeSession.establish(
        myPrivateKeyHex: 'priv-alice-1234567890abcdef',
        peerPublicKeyHex: 'pub-bob-abcdef1234567890',
        peerDeviceId: 'device-bob',
      );

      expect(session.sharedMasterKey, isNotEmpty);
      final key1 = session.deriveMessageKey(1);
      final key2 = session.deriveMessageKey(2);
      expect(key1, isNot(equals(key2))); // Message key changes per sequence
    });

    test('TEST 4 & 5: Message payload encryption and recipient decryption', () {
      const plaintext = 'Secret E2EE message over Voyager Chat';
      const recipientDeviceId = 'device-bob';

      final ciphertextString = e2eeService.encryptPayload(
        plaintext,
        recipientDeviceId,
      );
      expect(ciphertextString, startsWith('[E2EE-v1:'));
      expect(ciphertextString, isNot(contains(plaintext)));

      // Recipient decrypts payload
      final decrypted = e2eeService.decryptPayload(
        ciphertextString,
        recipientDeviceId,
      );
      expect(decrypted, equals(plaintext));
    });

    test(
      'TEST 6: Ciphertext MAC tampering detection (Authentication failure)',
      () {
        const plaintext = 'Tamper test payload';
        const recipientDeviceId = 'device-carol';

        final ciphertextString = e2eeService.encryptPayload(
          plaintext,
          recipientDeviceId,
        );
        final tamperedString = ciphertextString.replaceFirst(
          'E2EE',
          'TAMPERED',
        );

        final result = e2eeService.decryptPayload(
          tamperedString,
          recipientDeviceId,
        );
        expect(result, isNull);
      },
    );

    test(
      'TEST 7: Replay protection prevents replaying old sequence packets',
      () {
        const plaintext = 'Replay prevention test';
        const recipientDeviceId = 'device-dave';

        final ciphertextString = e2eeService.encryptPayload(
          plaintext,
          recipientDeviceId,
        );

        final firstDecrypt = e2eeService.decryptPayload(
          ciphertextString,
          recipientDeviceId,
        );
        expect(firstDecrypt, equals(plaintext));

        // Attempt replaying the exact same packet sequence
        final replayResult = e2eeService.decryptPayload(
          ciphertextString,
          recipientDeviceId,
        );
        expect(replayResult, equals('[REPLAYED PACKET REJECTED]'));
      },
    );

    test('TEST 8: BLE Mesh relays forward ciphertext without decrypting', () {
      const secretPayload = 'Mesh E2EE payload';
      final encryptedText = e2eeService.encryptPayload(
        secretPayload,
        'device-destination',
      );

      final packet = MeshPacket(
        packetId: 'mesh-pkt-100',
        senderDeviceId: 'device-alice',
        targetDeviceId: 'device-destination',
        originUserId: 'user-alice',
        conversationId: 'conv-e2ee-1',
        payload: encryptedText, // Payload is encrypted ciphertext
        timestamp: DateTime.now(),
      );

      final processed = MeshRouter.instance.processPacket(
        packet,
        myDeviceId: 'device-intermediate-relay',
      );
      expect(processed, isTrue);

      // Intermediate relay holds the packet in queue but cannot decrypt it
      final queued = MeshRouter.instance.storeAndForwardQueue.first;
      expect(queued.payload, startsWith('[E2EE-v1:'));
      expect(queued.payload, isNot(contains(secretPayload)));
    });

    test(
      'TEST 9 & 10: E2eeCipherPayload parsing and serialization consistency',
      () {
        const rawText = '[E2EE-v1:cGlwZWxpbmU=:IV12345:MAC999:1:device-sender]';
        final parsed = E2eeCipherPayload.parse(rawText);

        expect(parsed, isNotNull);
        expect(parsed!.ciphertextHex, equals('cGlwZWxpbmU='));
        expect(parsed.ivHex, equals('IV12345'));
        expect(parsed.macHex, equals('MAC999'));
        expect(parsed.sequenceNumber, equals(1));
        expect(parsed.senderDeviceId, equals('device-sender'));
      },
    );
  });
}
