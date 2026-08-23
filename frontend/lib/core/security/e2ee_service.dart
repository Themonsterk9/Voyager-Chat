import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'e2ee_session.dart';
import 'identity_key.dart';

class E2eeCipherPayload {
  const E2eeCipherPayload({
    required this.ciphertextHex,
    required this.ivHex,
    required this.macHex,
    required this.senderDeviceId,
    required this.sequenceNumber,
    this.version = 1,
  });

  final String ciphertextHex;
  final String ivHex;
  final String macHex;
  final String senderDeviceId;
  final int sequenceNumber;
  final int version;

  String encode() {
    return '[E2EE-v$version:$ciphertextHex:$ivHex:$macHex:$sequenceNumber:$senderDeviceId]';
  }

  static E2eeCipherPayload? parse(String text) {
    if (!text.startsWith('[E2EE-v1:') || !text.endsWith(']')) {
      return null;
    }
    final raw = text.substring(9, text.length - 1);
    final parts = raw.split(':');
    if (parts.length < 5) return null;

    return E2eeCipherPayload(
      ciphertextHex: parts[0],
      ivHex: parts[1],
      macHex: parts[2],
      sequenceNumber: int.tryParse(parts[3]) ?? 0,
      senderDeviceId: parts[4],
    );
  }
}

class E2eeService {
  E2eeService._();

  static final E2eeService instance = E2eeService._();

  E2eeIdentityKey? _myIdentityKey;
  final Map<String, E2eeSession> _sessions = {};
  final Map<String, String> _verifiedPeerPublicKeys = {};

  E2eeIdentityKey? get identityKey => _myIdentityKey;

  void initialize({required String userId, required String deviceId}) {
    if (_myIdentityKey == null || _myIdentityKey!.deviceId != deviceId) {
      _myIdentityKey = E2eeIdentityKey.generate(
        userId: userId,
        deviceId: deviceId,
      );
    }
  }

  void registerPeerPublicKey(String peerDeviceId, String peerPublicKeyHex) {
    _verifiedPeerPublicKeys[peerDeviceId] = peerPublicKeyHex;
  }

  E2eeSession _getOrCreateSession(String peerDeviceId) {
    if (_sessions.containsKey(peerDeviceId)) {
      return _sessions[peerDeviceId]!;
    }

    final peerPubKey =
        _verifiedPeerPublicKeys[peerDeviceId] ??
        '00000000000000000000000000000000';
    final session = E2eeSession.establish(
      myPrivateKeyHex: _myIdentityKey?.privateKeyHex ?? 'default-key',
      peerPublicKeyHex: peerPubKey,
      peerDeviceId: peerDeviceId,
    );
    _sessions[peerDeviceId] = session;
    return session;
  }

  String encryptPayload(String plaintext, String recipientDeviceId) {
    final session = _getOrCreateSession(recipientDeviceId);
    final seq = session.nextSequence();

    final msgKey = session.deriveMessageKey(seq);
    final macKey = session.deriveMacKey(seq);

    // XOR Payload ciphering with derived message key
    final plainBytes = utf8.encode(plaintext);
    final keyBytes = utf8.encode(msgKey);
    final cipherBytes = <int>[];

    for (int i = 0; i < plainBytes.length; i++) {
      cipherBytes.add(plainBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    final ciphertextHex = base64.encode(cipherBytes);
    final ivHex = sha256
        .convert(utf8.encode('IV:$seq'))
        .toString()
        .substring(0, 16);

    // Compute HMAC authentication MAC
    final macStr = E2eeSession.hmacSha256(
      macKey,
      utf8.encode('$ciphertextHex:$ivHex:$seq'),
    );

    final payload = E2eeCipherPayload(
      ciphertextHex: ciphertextHex,
      ivHex: ivHex,
      macHex: macStr,
      senderDeviceId: _myIdentityKey?.deviceId ?? 'unknown-device',
      sequenceNumber: seq,
    );

    return payload.encode();
  }

  String? decryptPayload(String payloadString, String senderDeviceId) {
    final payload = E2eeCipherPayload.parse(payloadString);
    if (payload == null) {
      return null; // Not an E2EE payload or invalid format
    }

    final session = _getOrCreateSession(senderDeviceId);

    // Replay protection check
    if (!session.validateAndRecordSequence(payload.sequenceNumber)) {
      return '[REPLAYED PACKET REJECTED]';
    }

    final macKey = session.deriveMacKey(payload.sequenceNumber);
    final expectedMac = E2eeSession.hmacSha256(
      macKey,
      utf8.encode(
        '${payload.ciphertextHex}:${payload.ivHex}:${payload.sequenceNumber}',
      ),
    );

    // MAC Verification (Authentication Check)
    if (expectedMac != payload.macHex) {
      return '[AUTHENTICATION FAILED: CORRUPTED CIPHERTEXT]';
    }

    final msgKey = session.deriveMessageKey(payload.sequenceNumber);
    final cipherBytes = base64.decode(payload.ciphertextHex);
    final keyBytes = utf8.encode(msgKey);
    final plainBytes = <int>[];

    for (int i = 0; i < cipherBytes.length; i++) {
      plainBytes.add(cipherBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return utf8.decode(plainBytes);
  }
}
