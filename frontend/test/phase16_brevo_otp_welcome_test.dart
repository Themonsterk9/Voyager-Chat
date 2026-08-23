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

  group('Phase 16 Brevo Email OTP & Welcome Registration Email Tests', () {
    test('1. REGISTRATION OTP Request & Verification', () async {
      const email = 'real_test_user@voyager.chat';

      // Request REGISTRATION OTP
      final sent = await AuthService.instance.sendBrevoOtp(
        email,
        purpose: 'REGISTRATION',
      );
      expect(sent, isTrue);

      // CRITICAL: Requesting OTP does NOT authenticate user
      expect(AuthService.instance.isAuthenticated, isFalse);

      // Verifying with REGISTRATION purpose succeeds and authenticates session
      final user = await AuthService.instance.verifyBrevoOtp(
        email,
        '123456',
        purpose: 'REGISTRATION',
      );
      expect(user.email, email);
      expect(AuthService.instance.isAuthenticated, isTrue);
    });

    test(
      '2. Welcome Registration Email Dispatch on Successful Verification',
      () async {
        const email = 'welcome_user@voyager.chat';
        const displayName = 'Alice Voyager';

        final sentWelcome = await AuthService.instance.sendWelcomeEmail(
          email,
          displayName,
        );
        expect(sentWelcome, isTrue);
      },
    );

    test('3. Forgot Password OTP Flow with PASSWORD_RESET Purpose', () async {
      const email = 'reset_user@voyager.chat';

      final sentReset = await AuthService.instance.sendForgotPasswordOtp(email);
      expect(sentReset, isTrue);

      // User remains unauthenticated
      expect(AuthService.instance.isAuthenticated, isFalse);

      // Password update requires valid parameters
      final updated = await AuthService.instance.updatePassword(
        email,
        'NewSecurePass123!',
      );
      expect(updated, isTrue);
    });
  });
}
