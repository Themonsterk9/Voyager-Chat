import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/auth/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.logout();
  });

  group('Brevo OTP security boundaries', () {
    test('requesting an invalid address does not authenticate', () async {
      await expectLater(
        AuthService.instance.sendBrevoOtp('not-an-email', purpose: 'REGISTRATION'),
        throwsException,
      );
      expect(AuthService.instance.isAuthenticated, isFalse);
    });

    test('invalid verification input does not authenticate', () async {
      await expectLater(
        AuthService.instance.verifyBrevoOtp('person@example.com', '000'),
        throwsException,
      );
      expect(AuthService.instance.isAuthenticated, isFalse);
    });
  });
}
