import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/notification_banner_service.dart';
import 'package:frontend/features/chat/models/conversation.dart';
import 'package:frontend/features/chat/models/conversation_member.dart';

void main() {
  group('Phase 3 Feature Tests (Steps 61-80)', () {
    test('Conversation model handles avatarUrl and inviteCode', () {
      final conv = Conversation.fromMap({
        'id': 'group-1',
        'type': 'group',
        'name': 'Voyager Devs',
        'created_by': 'user-1',
        'avatar_url': 'https://example.com/avatar.png',
        'invite_code': 'ABC12345',
      });

      expect(conv.id, 'group-1');
      expect(conv.type, 'group');
      expect(conv.name, 'Voyager Devs');
      expect(conv.avatarUrl, 'https://example.com/avatar.png');
      expect(conv.inviteCode, 'ABC12345');

      final copy = conv.copyWith(name: 'Voyager Engineering');
      expect(copy.name, 'Voyager Engineering');
      expect(copy.avatarUrl, 'https://example.com/avatar.png');
    });

    test('ConversationMember model handles role and isMuted', () {
      final member = ConversationMember.fromMap({
        'conversation_id': 'group-1',
        'user_id': 'user-1',
        'role': 'owner',
        'is_muted': 1,
      });

      expect(member.role, 'owner');
      expect(member.isMuted, true);

      final map = member.toDatabaseMap();
      expect(map['role'], 'owner');
      expect(map['is_muted'], 1);

      final copy = member.copyWith(role: 'admin', isMuted: false);
      expect(copy.role, 'admin');
      expect(copy.isMuted, false);
    });

    test('NotificationBannerService instance exists', () {
      final service = NotificationBannerService.instance;
      expect(service, isNotNull);
    });
  });
}
