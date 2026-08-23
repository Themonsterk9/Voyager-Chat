import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/auth/models/auth_user.dart';
import '../../../core/auth/services/auth_service.dart';
import '../../../core/database/app_database.dart';
import '../models/user_profile.dart';

class UserRepository {
  UserRepository._();

  static final UserRepository instance = UserRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  AuthUser? get currentUser => AuthService.instance.currentUser;

  Future<void> saveLocalProfile(UserProfile profile) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.insert(
        'user_profiles',
        profile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<UserProfile?> getLocalProfile(String id) async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'user_profiles',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return UserProfile.fromMap(rows.first);
      }
    } catch (_) {}
    return null;
  }

  Future<UserProfile> ensureProfileExists(
    AuthUser user, {
    String authProvider = 'email',
    String? avatarUrl,
  }) async {
    final existingLocal = await getLocalProfile(user.id);
    if (existingLocal != null) {
      final updated = existingLocal.copyWith(
        email: existingLocal.email ?? user.email,
        displayName: existingLocal.displayName ?? user.displayName,
        avatarUrl: existingLocal.avatarUrl ?? avatarUrl,
        authProvider: existingLocal.authProvider ?? authProvider,
        lastSeen: DateTime.now().toUtc(),
      );
      await saveLocalProfile(updated);
      return updated;
    }

    final rawName = user.displayName?.trim();
    final rawEmail = user.email?.trim();
    final nameOrPrefix = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : ((rawEmail != null && rawEmail.contains('@'))
              ? rawEmail.split('@').first
              : 'user_${user.id.hashCode.abs()}');

    final sanitizedUsername = nameOrPrefix
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    final finalUsername = sanitizedUsername.length >= 3
        ? (sanitizedUsername.length <= 30
              ? sanitizedUsername
              : sanitizedUsername.substring(0, 30))
        : '${sanitizedUsername}_${user.id.hashCode.abs() % 1000}';

    final profile = UserProfile(
      id: user.id,
      email: user.email,
      displayName: nameOrPrefix,
      username: finalUsername,
      avatarUrl: avatarUrl,
      authProvider: authProvider,
      status: 'online',
      lastSeen: DateTime.now().toUtc(),
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    await saveLocalProfile(profile);

    try {
      await _client.from('profiles').upsert(profile.toMap());
    } catch (_) {}

    return profile;
  }

  Future<List<UserProfile>> getRegisteredUsers() async {
    try {
      final response = await _client
          .from('profiles')
          .select('''
            id,
            username,
            display_name,
            avatar_url,
            email,
            auth_provider,
            status,
            last_seen,
            created_at,
            updated_at
          ''')
          .order('display_name', ascending: true);

      final remoteProfiles = (response as List)
          .map<UserProfile>(
            (row) => UserProfile.fromMap(row as Map<String, dynamic>),
          )
          .toList();

      for (final p in remoteProfiles) {
        await saveLocalProfile(p);
      }
      return remoteProfiles;
    } catch (_) {
      try {
        final db = await AppDatabase.instance.database;
        final rows = await db.query(
          'user_profiles',
          orderBy: 'display_name ASC',
        );
        return rows.map((r) => UserProfile.fromMap(r)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    final user = currentUser;

    if (user == null) {
      throw const AuthException('You must be logged in to search users.');
    }

    final search = query.trim();

    if (search.isEmpty) {
      return [];
    }

    try {
      final response = await _client
          .from('profiles')
          .select('''
            id,
            username,
            display_name,
            avatar_url,
            email,
            auth_provider,
            status,
            last_seen,
            created_at,
            updated_at
          ''')
          .neq('id', user.id)
          .or('username.ilike.%$search%,display_name.ilike.%$search%')
          .order('display_name', ascending: true)
          .limit(20);

      final results = (response as List)
          .map<UserProfile>(
            (row) => UserProfile.fromMap(row as Map<String, dynamic>),
          )
          .toList();

      for (final p in results) {
        await saveLocalProfile(p);
      }
      return results;
    } catch (_) {
      try {
        final db = await AppDatabase.instance.database;
        final rows = await db.query(
          'user_profiles',
          where: 'id != ? AND (username LIKE ? OR display_name LIKE ?)',
          whereArgs: [user.id, '%$search%', '%$search%'],
          limit: 20,
        );
        return rows.map((r) => UserProfile.fromMap(r)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<UserProfile?> getUserById(String userId) async {
    final local = await getLocalProfile(userId);
    if (local != null) {
      return local;
    }

    try {
      final response = await _client
          .from('profiles')
          .select('''
            id,
            username,
            display_name,
            avatar_url,
            email,
            auth_provider,
            status,
            last_seen,
            created_at,
            updated_at
          ''')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        final remoteProfile = UserProfile.fromMap(response);
        await saveLocalProfile(remoteProfile);
        return remoteProfile;
      }
    } catch (_) {}

    final user = currentUser;
    if (user != null && user.id == userId) {
      return ensureProfileExists(user);
    }

    return null;
  }

  Future<void> updatePresence(String status) async {
    final user = currentUser;
    if (user == null) return;

    final existing = await getLocalProfile(user.id);
    if (existing != null) {
      await saveLocalProfile(
        existing.copyWith(status: status, lastSeen: DateTime.now().toUtc()),
      );
    }

    try {
      await _client
          .from('profiles')
          .update({
            'status': status,
            'last_seen': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);
    } catch (_) {}
  }

  static String? validateUsername(String? username) {
    if (username == null || username.trim().isEmpty) {
      return 'Username cannot be empty.';
    }

    final trimmed = username.trim().toLowerCase();

    if (trimmed.length < 3) {
      return 'Username must be at least 3 characters.';
    }

    if (trimmed.length > 30) {
      return 'Username must be 30 characters or less.';
    }

    final validRegExp = RegExp(r'^[a-z0-9_]+$');
    if (!validRegExp.hasMatch(trimmed)) {
      return 'Username can contain only letters, numbers, and underscores.';
    }

    return null;
  }

  Future<bool> checkUsernameAvailable(
    String username, {
    String? excludeUserId,
  }) async {
    final validationError = validateUsername(username);
    if (validationError != null) return false;

    final normalized = username.trim().toLowerCase();
    final currentId = excludeUserId ?? currentUser?.id;

    try {
      final db = await AppDatabase.instance.database;
      final localRows = await db.query(
        'user_profiles',
        where: 'username = ? AND id != ?',
        whereArgs: [normalized, currentId ?? ''],
      );
      if (localRows.isNotEmpty) {
        return false;
      }
    } catch (_) {}

    try {
      var query = _client
          .from('profiles')
          .select('id')
          .eq('username', normalized);
      if (currentId != null && currentId.isNotEmpty) {
        query = query.neq('id', currentId);
      }

      final res = await query.maybeSingle();
      return res == null;
    } catch (_) {
      return true;
    }
  }

  Future<UserProfile> updateUsername(String newUsername) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException(
        'You must be logged in to update your username.',
      );
    }

    final validationError = validateUsername(newUsername);
    if (validationError != null) {
      throw AuthException(validationError);
    }

    final normalized = newUsername.trim().toLowerCase();

    final isAvailable = await checkUsernameAvailable(
      normalized,
      excludeUserId: user.id,
    );
    if (!isAvailable) {
      throw const AuthException('Username is already taken.');
    }

    final currentProfile = await getUserById(user.id);
    final updated = (currentProfile ?? await ensureProfileExists(user))
        .copyWith(username: normalized, updatedAt: DateTime.now().toUtc());

    await saveLocalProfile(updated);

    try {
      await _client
          .from('profiles')
          .update({
            'username': normalized,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (e.code == '23505' ||
          msg.contains('unique') ||
          msg.contains('duplicate') ||
          msg.contains('already exists') ||
          msg.contains('username')) {
        throw const AuthException('Username is already taken.');
      }
    } catch (_) {}

    return updated;
  }

  Future<UserProfile> updateDisplayName(String newName) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('You must be logged in to update your name.');
    }

    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw const AuthException('Display name cannot be empty.');
    }

    final currentProfile = await getUserById(user.id);
    final updated = (currentProfile ?? await ensureProfileExists(user))
        .copyWith(displayName: trimmed, updatedAt: DateTime.now().toUtc());

    await saveLocalProfile(updated);

    try {
      await _client
          .from('profiles')
          .update({
            'display_name': trimmed,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);
    } catch (_) {}

    return updated;
  }

  Future<UserProfile> updateAvatarUrl(String avatarUrl) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('You must be logged in to update your avatar.');
    }

    final trimmed = avatarUrl.trim();

    final currentProfile = await getUserById(user.id);
    final updated = (currentProfile ?? await ensureProfileExists(user))
        .copyWith(
          avatarUrl: trimmed.isEmpty ? null : trimmed,
          updatedAt: DateTime.now().toUtc(),
        );

    await saveLocalProfile(updated);

    try {
      await _client
          .from('profiles')
          .update({
            'avatar_url': trimmed.isEmpty ? null : trimmed,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);
    } catch (_) {}

    return updated;
  }
}
