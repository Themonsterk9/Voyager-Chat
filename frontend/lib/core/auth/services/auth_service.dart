import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_user.dart';

import '../../enterprise/enterprise_audit_service.dart';
import '../../enterprise/enterprise_models.dart';
import '../../../features/users/repositories/user_repository.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  AuthUser? _currentUser = const AuthUser(
    id: 'usr_default_voyager',
    email: 'user@voyager.chat',
    displayName: 'Voyager User',
  );

  final StreamController<AuthUser?> _authStateController =
      StreamController<AuthUser?>.broadcast();

  AuthUser? get currentUser => _currentUser;

  bool get isAuthenticated => _currentUser != null;

  Stream<AuthUser?> get authStateChanges => _authStateController.stream;

  String _generateRandomString(int length) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64Url
        .encode(values)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }

  String _createCodeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url
        .encode(digest.bytes)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
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

  String get backendBaseUrl {
    const envUrl = String.fromEnvironment('BACKEND_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    if (!kIsWeb && Platform.isAndroid && kDebugMode) {
      return 'http://10.0.2.2:3000';
    }
    if (kDebugMode) {
      return 'http://127.0.0.1:3000';
    }
    return 'https://api.voyager.chat';
  }

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

  Future<bool> signInWithGoogle() async {
    try {
      final String clientId = (!kIsWeb && Platform.isAndroid)
          ? const String.fromEnvironment(
              'GOOGLE_CLIENT_ID_ANDROID',
              defaultValue: 'YOUR_GOOGLE_CLIENT_ID_ANDROID',
            )
          : (!kIsWeb && Platform.isIOS)
          ? const String.fromEnvironment(
              'GOOGLE_CLIENT_ID_IOS',
              defaultValue: 'YOUR_GOOGLE_CLIENT_ID_IOS',
            )
          : const String.fromEnvironment(
              'GOOGLE_CLIENT_ID',
              defaultValue: 'YOUR_GOOGLE_CLIENT_ID_WINDOWS',
            );
      final state = _generateRandomString(16);
      final codeVerifier = _generateRandomString(32);
      final codeChallenge = _createCodeChallenge(codeVerifier);

      if (kIsWeb) {
        final redirectUri = Uri.base.origin;
        final oauthUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': 'openid email profile',
          'state': state,
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
          'prompt': 'select_account',
        });
        if (await canLaunchUrl(oauthUrl)) {
          await launchUrl(oauthUrl, mode: LaunchMode.externalApplication);
          return true;
        }
        return false;
      }

      HttpServer? server;
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
      } catch (_) {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      }

      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port/';

      final oauthUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'prompt': 'select_account',
      });

      if (!await canLaunchUrl(oauthUrl)) {
        await server.close();
        throw Exception('Could not launch system browser.');
      }

      await launchUrl(oauthUrl, mode: LaunchMode.externalApplication);

      final Completer<String> codeCompleter = Completer<String>();

      server.listen((HttpRequest request) async {
        final uri = request.uri;
        final returnedState = uri.queryParameters['state'];
        final code = uri.queryParameters['code'];
        final error = uri.queryParameters['error'];

        const responseHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Voyager Chat - Authentication Complete</title>
</head>
<body style="font-family: system-ui, -apple-system, sans-serif; background-color: #0f172a; color: #f8fafc; text-align: center; padding-top: 80px;">
  <div style="max-width: 480px; margin: 0 auto; background: #1e293b; padding: 40px; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.5);">
    <h1 style="color: #38bdf8; margin-bottom: 12px;">Authentication Successful</h1>
    <p style="font-size: 16px; color: #94a3b8;">You have successfully signed in to Voyager Chat.</p>
    <p style="color: #64748b; font-size: 14px; margin-top: 24px;">You can now close this browser tab and return to the Voyager Chat app.</p>
  </div>
  <script>setTimeout(function() { window.close(); }, 3000);</script>
</body>
</html>
''';

        request.response.headers.contentType = ContentType.html;
        request.response.statusCode = 200;
        request.response.write(responseHtml);
        await request.response.close();

        if (returnedState != state) {
          if (!codeCompleter.isCompleted) {
            codeCompleter.completeError(
              Exception('OAuth Security Error: State parameter mismatch.'),
            );
          }
          return;
        }

        if (error != null && error.isNotEmpty) {
          if (!codeCompleter.isCompleted) {
            codeCompleter.completeError(
              Exception('Google OAuth Error: $error'),
            );
          }
          return;
        }

        if (code != null && code.isNotEmpty) {
          if (!codeCompleter.isCompleted) {
            codeCompleter.complete(code);
          }
        }
      });

      final authCode = await codeCompleter.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          server?.close();
          throw Exception('Google Sign-In timed out. Please try again.');
        },
      );

      await server.close();

      final backendResponse = await http.post(
        Uri.parse('$backendBaseUrl/api/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': authCode,
          'redirect_uri': redirectUri,
          'code_verifier': codeVerifier,
          'client_id': clientId,
        }),
      );

      if (backendResponse.statusCode != 200) {
        final errData = jsonDecode(backendResponse.body);
        throw Exception(
          errData['message'] ?? 'Google authentication failed on backend.',
        );
      }

      final resData = jsonDecode(backendResponse.body) as Map<String, dynamic>;
      final userData = resData['user'] as Map<String, dynamic>;

      final googleUser = AuthUser(
        id: userData['id'] as String,
        email: userData['email'] as String,
        displayName: userData['displayName'] as String?,
      );

      _currentUser = googleUser;
      _authStateController.add(_currentUser);

      await UserRepository.instance.ensureProfileExists(
        googleUser,
        authProvider: 'google',
        avatarUrl: userData['avatarUrl'] as String?,
      );

      return true;
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  Future<void> logout() async {
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
