import 'dart:convert';

import 'package:crypto/crypto.dart';

class SafetyFingerprint {
  static String compute(String publicKeyHex, String deviceId) {
    final bytes = utf8.encode('$publicKeyHex:$deviceId');
    final digest = sha256.convert(bytes);
    final hexStr = digest.toString();

    // Convert hex string into 12 numeric digits formatted as "XXXX XXXX XXXX"
    final num1 = int.parse(hexStr.substring(0, 4), radix: 16) % 10000;
    final num2 = int.parse(hexStr.substring(4, 8), radix: 16) % 10000;
    final num3 = int.parse(hexStr.substring(8, 12), radix: 16) % 10000;

    final part1 = num1.toString().padLeft(4, '0');
    final part2 = num2.toString().padLeft(4, '0');
    final part3 = num3.toString().padLeft(4, '0');

    return '$part1 $part2 $part3';
  }
}

class E2eeIdentityKey {
  const E2eeIdentityKey({
    required this.userId,
    required this.deviceId,
    required this.publicKeyHex,
    required this.privateKeyHex,
    required this.createdAt,
  });

  final String userId;
  final String deviceId;
  final String publicKeyHex;
  final String privateKeyHex;
  final DateTime createdAt;

  String get fingerprint => SafetyFingerprint.compute(publicKeyHex, deviceId);

  factory E2eeIdentityKey.generate({
    required String userId,
    required String deviceId,
  }) {
    final now = DateTime.now().toUtc();
    final seed = '$userId:$deviceId:${now.microsecondsSinceEpoch}';
    final pubBytes = sha256.convert(utf8.encode('PUB:$seed'));
    final privBytes = sha256.convert(utf8.encode('PRIV:$seed'));

    return E2eeIdentityKey(
      userId: userId,
      deviceId: deviceId,
      publicKeyHex: pubBytes.toString(),
      privateKeyHex: privBytes.toString(),
      createdAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'device_id': deviceId,
      'public_key': publicKeyHex,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
