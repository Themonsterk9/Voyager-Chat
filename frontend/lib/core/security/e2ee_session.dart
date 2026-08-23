import 'dart:convert';

import 'package:crypto/crypto.dart';

class E2eeSession {
  E2eeSession({
    required this.sessionId,
    required this.peerDeviceId,
    required this.sharedMasterKey,
  });

  final String sessionId;
  final String peerDeviceId;
  final String sharedMasterKey;

  int _senderSequence = 0;
  final Set<int> _receivedSequences = {};

  int get senderSequence => _senderSequence;

  factory E2eeSession.establish({
    required String myPrivateKeyHex,
    required String peerPublicKeyHex,
    required String peerDeviceId,
  }) {
    final combined = '$myPrivateKeyHex:$peerPublicKeyHex:$peerDeviceId';
    final masterDigest = sha256.convert(utf8.encode(combined));

    return E2eeSession(
      sessionId: 'session-$peerDeviceId',
      peerDeviceId: peerDeviceId,
      sharedMasterKey: masterDigest.toString(),
    );
  }

  String deriveMessageKey(int sequenceNumber) {
    final bytes = utf8.encode('$sharedMasterKey:msg-key:$sequenceNumber');
    return hmacSha256(sharedMasterKey, bytes);
  }

  String deriveMacKey(int sequenceNumber) {
    final bytes = utf8.encode('$sharedMasterKey:mac-key:$sequenceNumber');
    return hmacSha256(sharedMasterKey, bytes);
  }

  static String hmacSha256(String key, List<int> data) {
    final hmac = Hmac(sha256, utf8.encode(key));
    return hmac.convert(data).toString();
  }

  int nextSequence() {
    _senderSequence++;
    return _senderSequence;
  }

  bool validateAndRecordSequence(int sequenceNumber) {
    if (_receivedSequences.contains(sequenceNumber)) {
      return false; // Replay attempt detected!
    }
    _receivedSequences.add(sequenceNumber);
    return true;
  }
}
