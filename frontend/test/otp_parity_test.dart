import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:frontend/core/auth/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    AuthService.instance.logout();
  });

  test('Aether AI OTP Parity: Requesting OTP does NOT authenticate user or create session', () async {
    const email = 'user_test_otp@voyager.chat';

    expect(AuthService.instance.isAuthenticated, isFalse);

    final sent = await AuthService.instance.sendBrevoOtp(
      email,
      purpose: 'LOGIN',
    );
    expect(sent, isTrue);

    // CRITICAL AETHER AI RULE: User MUST remain UNAUTHENTICATED after requesting OTP
    expect(AuthService.instance.isAuthenticated, isFalse);
    expect(AuthService.instance.currentUser, isNull);
  });

  test('Aether AI OTP Parity: Session created ONLY after successful OTP verification', () async {
    const email = 'user_verify_otp@voyager.chat';

    await AuthService.instance.sendBrevoOtp(email, purpose: 'LOGIN');
    expect(AuthService.instance.isAuthenticated, isFalse);

    final user = await AuthService.instance.verifyBrevoOtp(email, '123456');

    // SUCCESSFUL VERIFICATION -> Session created!
    expect(user.email, email);
    expect(AuthService.instance.isAuthenticated, isTrue);
    expect(AuthService.instance.currentUser?.email, email);
  });
}
