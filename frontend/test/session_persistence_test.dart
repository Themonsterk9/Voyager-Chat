import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/auth/services/auth_service.dart';
import 'package:frontend/core/network/socket_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.logout();
  });

  group('Session Persistence Tests', () {
    test('Fresh install with no stored session returns null user', () async {
      final user = await AuthService.instance.restoreSession();
      expect(user, isNull);
      expect(AuthService.instance.isAuthenticated, isFalse);
    });

    test('Successful login persists session and restores across app restarts', () async {
      // 1. User logs in
      final loggedInUser = await AuthService.instance.login(
        email: 'user@example.com',
        password: 'password123',
      );
      expect(AuthService.instance.isAuthenticated, isTrue);
      expect(loggedInUser.email, equals('user@example.com'));

      // 2. Simulate app restart by clearing in-memory state
      // (calling logout without clearing SharedPreferences for simulation)
      final prefs = await SharedPreferences.getInstance();
      final savedUserJson = prefs.getString('auth_user_data');
      expect(savedUserJson, isNotNull);
      expect(savedUserJson, contains('user@example.com'));

      // 3. Restore session (as app opening again)
      final restoredUser = await AuthService.instance.restoreSession();
      expect(restoredUser, isNotNull);
      expect(restoredUser!.email, equals('user@example.com'));
      expect(AuthService.instance.isAuthenticated, isTrue);
      expect(AuthService.instance.currentUser?.id, equals(loggedInUser.id));
    });

    test('Logout clears persisted authentication state and disconnects socket', () async {
      // 1. Login
      await AuthService.instance.login(
        email: 'user2@example.com',
        password: 'password123',
      );
      expect(AuthService.instance.isAuthenticated, isTrue);

      // 2. Explicit logout
      await AuthService.instance.logout();

      // 3. Verify in-memory state
      expect(AuthService.instance.isAuthenticated, isFalse);
      expect(AuthService.instance.currentUser, isNull);
      expect(SocketClient.instance.isConnected, isFalse);

      // 4. Reopening app must NOT restore user
      final restoredUser = await AuthService.instance.restoreSession();
      expect(restoredUser, isNull);
      expect(AuthService.instance.isAuthenticated, isFalse);
    });
  });
}
