import 'dart:async';

import '../models/auth_user.dart';
import 'auth_service.dart';

class AuthStateService {
  AuthStateService._();

  static final AuthStateService instance = AuthStateService._();

  AuthUser? get currentUser => AuthService.instance.currentUser;

  bool get isAuthenticated => AuthService.instance.isAuthenticated;

  Stream<AuthUser?> get authStateChanges =>
      AuthService.instance.authStateChanges;

  Future<void> waitForInitialSession() async {
    await Future<void>.delayed(Duration.zero);
  }
}
