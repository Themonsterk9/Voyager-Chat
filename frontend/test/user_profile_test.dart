import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/users/models/user_profile.dart';
import 'package:frontend/features/users/repositories/user_repository.dart';

void main() {
  group('UserProfile model tests', () {
    test('creates UserProfile from map correctly', () {
      final map = {
        'id': 'user-123',
        'username': 'john_doe',
        'display_name': 'John Doe',
        'avatar_url': 'https://example.com/avatar.png',
        'status': 'online',
        'last_seen': '2026-08-20T12:00:00.000Z',
      };

      final profile = UserProfile.fromMap(map);

      expect(profile.id, 'user-123');
      expect(profile.username, 'john_doe');
      expect(profile.displayName, 'John Doe');
      expect(profile.avatarUrl, 'https://example.com/avatar.png');
      expect(profile.status, 'online');
      expect(profile.lastSeen, isNotNull);
    });

    test('displayNameOrUsername returns displayName when present', () {
      const profile = UserProfile(
        id: '1',
        displayName: 'Alice',
        username: 'alice99',
      );

      expect(profile.displayNameOrUsername, 'Alice');
    });

    test('displayNameOrUsername falls back to username when displayName is null/empty', () {
      const profile = UserProfile(
        id: '1',
        displayName: '',
        username: 'bob_builder',
      );

      expect(profile.displayNameOrUsername, 'bob_builder');
    });

    test('displayNameOrUsername falls back to Voyager User when both are null/empty', () {
      const profile = UserProfile(id: '1', displayName: null, username: '  ');

      expect(profile.displayNameOrUsername, 'Voyager User');
    });

    test('secondaryName formats username with @ prefix', () {
      const profile = UserProfile(id: '1', username: 'charlie');

      expect(profile.secondaryName, '@charlie');
    });

    test('secondaryName returns empty string when username is null', () {
      const profile = UserProfile(id: '1', username: null);

      expect(profile.secondaryName, '');
    });
  });

  group('UserRepository username validation rules', () {
    test('rejects null, empty, or whitespace usernames', () {
      expect(
        UserRepository.validateUsername(null),
        'Username cannot be empty.',
      );
      expect(UserRepository.validateUsername(''), 'Username cannot be empty.');
      expect(
        UserRepository.validateUsername('   '),
        'Username cannot be empty.',
      );
    });

    test('rejects usernames shorter than 3 characters', () {
      expect(
        UserRepository.validateUsername('a'),
        'Username must be at least 3 characters.',
      );
      expect(
        UserRepository.validateUsername('ab'),
        'Username must be at least 3 characters.',
      );
    });

    test('rejects usernames longer than 30 characters', () {
      final longUsername = 'a' * 31;
      expect(
        UserRepository.validateUsername(longUsername),
        'Username must be 30 characters or less.',
      );
    });

    test('rejects invalid characters (spaces, special characters, emojis)', () {
      expect(
        UserRepository.validateUsername('john doe'),
        'Username can contain only letters, numbers, and underscores.',
      );
      expect(
        UserRepository.validateUsername('john-doe'),
        'Username can contain only letters, numbers, and underscores.',
      );
      expect(
        UserRepository.validateUsername('john@doe'),
        'Username can contain only letters, numbers, and underscores.',
      );
      expect(
        UserRepository.validateUsername('user!'),
        'Username can contain only letters, numbers, and underscores.',
      );
      expect(
        UserRepository.validateUsername('😊user'),
        'Username can contain only letters, numbers, and underscores.',
      );
    });

    test('accepts valid usernames with letters, numbers, and underscores', () {
      expect(UserRepository.validateUsername('john_doe'), isNull);
      expect(UserRepository.validateUsername('gopal123'), isNull);
      expect(UserRepository.validateUsername('VOYAGER_USER_01'), isNull);
    });
  });
}
