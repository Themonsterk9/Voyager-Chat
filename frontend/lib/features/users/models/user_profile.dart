class UserProfile {
  const UserProfile({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.email,
    this.authProvider = 'email',
    this.status = 'offline',
    this.lastSeen,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? email;
  final String? authProvider;
  final String status;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String?,
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      email: map['email'] as String?,
      authProvider: map['auth_provider'] as String? ?? 'email',
      status: map['status'] as String? ?? 'offline',
      lastSeen: map['last_seen'] == null
          ? null
          : DateTime.tryParse(map['last_seen'].toString()),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.tryParse(map['updated_at'].toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'email': email,
      'auth_provider': authProvider,
      'status': status,
      'last_seen': lastSeen?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? email,
    String? authProvider,
    String? status,
    DateTime? lastSeen,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      authProvider: authProvider ?? this.authProvider,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayNameOrUsername {
    final name = displayName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final user = username?.trim();

    if (user != null && user.isNotEmpty) {
      return user;
    }

    return 'Voyager User';
  }

  String get secondaryName {
    final user = username?.trim();

    if (user != null && user.isNotEmpty) {
      return '@$user';
    }

    return '';
  }
}
