import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/auth/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.logout();
  });

  test('fresh state has no automatic user or Guest session', () {
    expect(AuthService.instance.isAuthenticated, isFalse);
    expect(AuthService.instance.currentUser, isNull);
  });

  test('invalid OTP input never creates a session', () async {
    await expectLater(
      AuthService.instance.verifyBrevoOtp('person@example.com', '12'),
      throwsException,
    );
    expect(AuthService.instance.isAuthenticated, isFalse);
  });
}
