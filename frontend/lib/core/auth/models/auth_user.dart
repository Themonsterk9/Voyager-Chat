class AuthUser {
  const AuthUser({required this.id, this.email, this.displayName});

  final String id;
  final String? email;
  final String? displayName;

  factory AuthUser.fromMap(Map<String, dynamic> map) {
    return AuthUser(
      id: map['id'] as String,
      email: map['email'] as String?,
      displayName:
          map['display_name'] as String? ?? map['displayName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'email': email, 'display_name': displayName};
  }
}
