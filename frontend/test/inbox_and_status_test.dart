import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/models/message.dart';
import 'package:frontend/features/users/models/user_profile.dart';

void main() {
  group('Step 22-35 Feature Tests', () {
    test('Message copyWith handles editedAt and deletedAt correctly', () {
      final now = DateTime.now().toUtc();
      final msg = Message(
        id: 'msg-1',
        conversationId: 'conv-1',
        senderId: 'user-1',
        content: 'Original',
        createdAt: now,
      );

      final edited = msg.copyWith(content: 'Edited content', editedAt: now);

      expect(edited.content, 'Edited content');
      expect(edited.editedAt, now);
      expect(edited.deletedAt, isNull);

      final deleted = edited.copyWith(deletedAt: now);

      expect(deleted.deletedAt, now);
    });

    test('UserProfile handles presence status correctly', () {
      final onlineProfile = UserProfile.fromMap({
        'id': 'u1',
        'username': 'alice',
        'display_name': 'Alice',
        'status': 'online',
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      });

      expect(onlineProfile.status, 'online');
      expect(onlineProfile.lastSeen, isNotNull);

      final offlineProfile = UserProfile.fromMap({
        'id': 'u2',
        'username': 'bob',
        'display_name': 'Bob',
        'status': 'offline',
      });

      expect(offlineProfile.status, 'offline');
    });
  });
}
