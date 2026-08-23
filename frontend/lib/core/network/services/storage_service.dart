import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<String?> uploadAvatar({
    required String userId,
    required Uint8List fileBytes,
    required String fileExtension,
  }) async {
    try {
      final fileName =
          '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      await _client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = _client.storage.from('avatars').getPublicUrl(fileName);
      return publicUrl;
    } catch (_) {
      return null;
    }
  }

  Future<String?> uploadChatAttachment({
    required String conversationId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final path =
          '$conversationId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _client.storage
          .from('chat-attachments')
          .uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      return _client.storage.from('chat-attachments').getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }
}
