import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/auth_user.dart';

import '../../enterprise/enterprise_audit_service.dart';
import '../../enterprise/enterprise_models.dart';
import '../../network/api_client.dart';
import '../../network/socket_client.dart';
import '../../../features/users/repositories/user_repository.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  AuthUser? _currentUser;

  final StreamController<AuthUser?> _authStateController =
      StreamController<AuthUser?>.broadcast();

  AuthUser? get currentUser => _currentUser;

  bool get isAuthenticated => _currentUser != null;

  Stream<AuthUser?> get authStateChanges => _authStateController.stream;

  Future<AuthUser> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final id = 'usr_${DateTime.now().millisecondsSinceEpoch}';
    final user = AuthUser(
      id: id,
      email: trimmedEmail,
      displayName: displayName == null || displayName.isEmpty
          ? trimmedEmail.split('@').first
          : displayName,
    );

    _currentUser = user;
    _authStateController.add(_currentUser);
    SocketClient.instance.connect(user.id);

    await UserRepository.instance.ensureProfileExists(
      user,
      authProvider: 'email',
    );

    await EnterpriseAuditService.instance.logEvent(
      eventType: AuditEventType.userRegistration,
      userId: user.id,
      details: {'email': user.email, 'provider': 'email'},
    );

    return user;
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      await EnterpriseAuditService.instance.logEvent(
        eventType: AuditEventType.loginFailed,
        userId: 'anonymous',
        details: {'email': email, 'reason': 'invalid_email'},
      );
      throw Exception('Please enter a valid email address.');
    }
    if (password.isEmpty) {
      await EnterpriseAuditService.instance.logEvent(
        eventType: AuditEventType.loginFailed,
        userId: 'anonymous',
        details: {'email': trimmedEmail, 'reason': 'empty_password'},
      );
      throw Exception('Password cannot be empty.');
    }

    final id = 'usr_${trimmedEmail.hashCode.abs()}';
    final user = AuthUser(
      id: id,
      email: trimmedEmail,
      displayName: trimmedEmail.split('@').first,
    );

    _currentUser = user;
    _authStateController.add(_currentUser);
    SocketClient.instance.connect(user.id);

    await UserRepository.instance.ensureProfileExists(
      user,
      authProvider: 'email',
    );

    await EnterpriseAuditService.instance.logEvent(
      eventType: AuditEventType.userLogin,
      userId: user.id,
      details: {'email': user.email, 'provider': 'email'},
    );

    return user;
  }

  String get backendBaseUrl => ApiClient.baseUrl;

  Future<bool> sendBrevoOtp(
    String email, {
    String purpose = 'Verification',
  }) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/api/auth/send-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': trimmed, 'purpose': purpose}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.body.isEmpty) {
        return true;
      }
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return true;
      }
      throw Exception(
        data['message'] ?? 'Unable to send OTP. Please try again.',
      );
    } on TimeoutException {
      throw Exception('Unable to contact authentication server.');
    } on SocketException {
      throw Exception(
        'Authentication server is currently offline. Please check your network connection.',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Unable to send OTP. Please try again.');
    }
  }

  Future<AuthUser> verifyBrevoOtp(
    String email,
    String otp, {
    String purpose = 'LOGIN',
  }) async {
    final trimmedEmail = email.trim();
    final trimmedOtp = otp.trim();

    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }
    if (trimmedOtp.length < 4) {
      throw Exception('Invalid OTP. Please check the code sent to your email.');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/api/auth/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': trimmedEmail,
              'otp': trimmedOtp,
              'purpose': purpose,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (response.statusCode != 200 || data['status'] != 'success') {
          throw Exception(
            data['message'] ?? 'Invalid OTP code. Please try again.',
          );
        }
      }
    } on TimeoutException {
      throw Exception('Unable to contact authentication server.');
    } on SocketException {
      throw Exception(
        'Authentication server is currently offline. Unable to verify OTP.',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Invalid OTP code. Please try again.');
    }

    final id = 'usr_otp_${trimmedEmail.hashCode.abs()}';
    final user = AuthUser(
      id: id,
      email: trimmedEmail,
      displayName: trimmedEmail.split('@').first,
    );

    _currentUser = user;
    _authStateController.add(_currentUser);
    SocketClient.instance.connect(user.id);

    await UserRepository.instance.ensureProfileExists(
      user,
      authProvider: 'email_otp',
    );

    return user;
  }

  Future<bool> sendForgotPasswordOtp(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/api/auth/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': trimmed}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.body.isEmpty) {
        return true;
      }
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return true;
      }
      throw Exception(data['message'] ?? 'Unable to request password reset.');
    } catch (e) {
      if (e is Exception) rethrow;
      return true;
    }
  }

  Future<bool> updatePassword(String email, String newPassword) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }
    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
    await EnterpriseAuditService.instance.logEvent(
      eventType: AuditEventType.passwordChanged,
      userId: trimmedEmail,
      details: {'email': trimmedEmail},
    );
    return true;
  }

  Future<bool> sendWelcomeEmail(String email, String displayName) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      return false;
    }
    try {
      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/api/auth/send-welcome'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': trimmedEmail,
              'displayName': displayName.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        return response.statusCode == 200 && data['status'] == 'success';
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> logout() async {
    SocketClient.instance.disconnect();
    _currentUser = null;
    _authStateController.add(null);
  }

  Future<void> resetPassword(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }
  }
}
