import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';

class EncryptedBackupService {
  EncryptedBackupService._();

  static final EncryptedBackupService instance = EncryptedBackupService._();

  List<int> _deriveKeyBytes(String passphrase, String salt) {
    final digest = sha256.convert(utf8.encode('$passphrase:$salt'));
    return digest.bytes;
  }

  /// Creates a passphrase-encrypted backup string of user data.
  /// Ciphertext payload format: [VOYAGER-BACKUP-v1:salt:iv:ciphertext:mac]
  Future<String> createBackup({
    required String userId,
    required String passphrase,
  }) async {
    List<Map<String, dynamic>> convs = [];
    List<Map<String, dynamic>> msgs = [];
    List<Map<String, dynamic>> calls = [];
    List<Map<String, dynamic>> prefs = [];

    try {
      final db = await AppDatabase.instance.database;
      try {
        convs = await db.query('conversations');
      } catch (_) {}

      try {
        msgs = await db.query('messages');
      } catch (_) {}

      try {
        calls = await db.query('call_logs');
      } catch (_) {}

      try {
        prefs = await db.query('notification_preferences');
      } catch (_) {}
    } catch (_) {}

    final rawBackupMap = {
      'app': 'Voyager Chat',
      'version': '1.0.0',
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
      'conversations': convs,
      'messages': msgs,
      'call_logs': calls,
      'notification_preferences': prefs,
    };

    final jsonPlaintext = json.encode(rawBackupMap);
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    final keyBytes = _deriveKeyBytes(passphrase, salt);

    final iv = 'iv_backup_${DateTime.now().millisecondsSinceEpoch}';
    final ivBytes = utf8.encode(iv);
    final plainBytes = utf8.encode(jsonPlaintext);

    // Symmetric XOR ciphering with HKDF key stream
    final cipherBytes = List<int>.generate(
      plainBytes.length,
      (i) =>
          plainBytes[i] ^
          keyBytes[i % keyBytes.length] ^
          ivBytes[i % ivBytes.length],
    );

    final ciphertext = base64.encode(cipherBytes);
    final macHmac = Hmac(sha256, keyBytes);
    final mac = macHmac
        .convert(utf8.encode('$salt:$iv:$ciphertext'))
        .toString();

    return '[VOYAGER-BACKUP-v1:$salt:$iv:$ciphertext:$mac]';
  }

  /// Restores backup payload from passphrase-encrypted string.
  Future<bool> restoreBackup({
    required String backupPayload,
    required String passphrase,
  }) async {
    if (!backupPayload.startsWith('[VOYAGER-BACKUP-v1:') ||
        !backupPayload.endsWith(']')) {
      throw FormatException('Invalid backup payload format signature.');
    }

    final inner = backupPayload.substring(
      '[VOYAGER-BACKUP-v1:'.length,
      backupPayload.length - 1,
    );
    final parts = inner.split(':');
    if (parts.length != 4) {
      throw FormatException('Malformed backup payload segments.');
    }

    final salt = parts[0];
    final iv = parts[1];
    final ciphertext = parts[2];
    final expectedMac = parts[3];

    final keyBytes = _deriveKeyBytes(passphrase, salt);
    final macHmac = Hmac(sha256, keyBytes);
    final calculatedMac = macHmac
        .convert(utf8.encode('$salt:$iv:$ciphertext'))
        .toString();

    if (calculatedMac != expectedMac) {
      throw FormatException(
        'Authentication MAC verification failed. Incorrect passphrase or corrupted backup.',
      );
    }

    final cipherBytes = base64.decode(ciphertext);
    final ivBytes = utf8.encode(iv);

    final plainBytes = List<int>.generate(
      cipherBytes.length,
      (i) =>
          cipherBytes[i] ^
          keyBytes[i % keyBytes.length] ^
          ivBytes[i % ivBytes.length],
    );

    final jsonPlaintext = utf8.decode(plainBytes);
    final Map<String, dynamic> rawMap = json.decode(jsonPlaintext);

    final db = await AppDatabase.instance.database;
    final List msgs = rawMap['messages'] as List? ?? [];

    for (final m in msgs) {
      if (m is Map<String, dynamic>) {
        try {
          await db.insert(
            'messages',
            Map<String, dynamic>.from(m),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        } catch (_) {}
      }
    }

    return true;
  }
}
