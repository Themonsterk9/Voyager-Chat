import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_user.dart';

import '../../enterprise/enterprise_audit_service.dart';
import '../../enterprise/enterprise_models.dart';
import '../../network/api_client.dart';
import '../../network/socket_client.dart';
import '../../../features/users/repositories/user_repository.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String _userStorageKey = 'auth_user_data';
  static const String _sessionTokenStorageKey = 'auth_user_session_token';

  AuthUser? _currentUser;

  final StreamController<AuthUser?> _authStateController =
      StreamController<AuthUser?>.broadcast();

  AuthUser? get currentUser => _currentUser;

  bool get isAuthenticated => _currentUser != null;

  Stream<AuthUser?> get authStateChanges => _authStateController.stream;

  Future<void> _saveSession(AuthUser user, [String? sessionToken]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userStorageKey, jsonEncode(user.toMap()));
      if (sessionToken != null && sessionToken.isNotEmpty) {
        await prefs.setString(_sessionTokenStorageKey, sessionToken);
      }
    } catch (e) {
      // Storage error ignored gracefully
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userStorageKey);
      await prefs.remove(_sessionTokenStorageKey);
    } catch (e) {
      // Storage error ignored gracefully
    }
  }

  Future<AuthUser?> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = prefs.getString(_userStorageKey);
      if (userDataJson == null || userDataJson.isEmpty) {
        _currentUser = null;
        _authStateController.add(null);
        return null;
      }

      final Map<String, dynamic> userMap =
          jsonDecode(userDataJson) as Map<String, dynamic>;
      AuthUser restoredUser = AuthUser.fromMap(userMap);
      final token = prefs.getString(_sessionTokenStorageKey);

      if (token != null && token.isNotEmpty) {
        try {
          final response = await http
              .get(
                Uri.parse('$backendBaseUrl/api/auth/session'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['status'] == 'success' && data['user'] != null) {
              restoredUser =
                  AuthUser.fromMap(Map<String, dynamic>.from(data['user']));
            }
          } else if (response.statusCode == 401) {
            await _clearSession();
            _currentUser = null;
            _authStateController.add(null);
            return null;
          }
        } on TimeoutException {
          // Network offline / timeout: retain local session
        } on SocketException {
          // Network offline: retain local session
        } catch (_) {
          // Other network failure: retain local session
        }
      }

      _currentUser = restoredUser;
      _authStateController.add(_currentUser);
      await _saveSession(_currentUser!, token);
      SocketClient.instance.connect(_currentUser!.id);
      return _currentUser;
    } catch (e) {
      _currentUser = null;
      _authStateController.add(null);
      return null;
    }
  }

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
    await _saveSession(user);
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
    await _saveSession(user);
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

    String? sessionToken;
    AuthUser user;

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
        if (data['session'] is String) {
          sessionToken = data['session'] as String;
        }
        if (data['user'] is Map) {
          user = AuthUser.fromMap(Map<String, dynamic>.from(data['user']));
        } else {
          user = AuthUser(
            id: 'usr_otp_${trimmedEmail.hashCode.abs()}',
            email: trimmedEmail,
            displayName: trimmedEmail.split('@').first,
          );
        }
      } else {
        user = AuthUser(
          id: 'usr_otp_${trimmedEmail.hashCode.abs()}',
          email: trimmedEmail,
          displayName: trimmedEmail.split('@').first,
        );
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

    _currentUser = user;
    _authStateController.add(_currentUser);
    await _saveSession(user, sessionToken);
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
    await _clearSession();
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
