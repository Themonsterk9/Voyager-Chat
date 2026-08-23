class ConversationMember {
  const ConversationMember({
    required this.conversationId,
    required this.userId,
    this.joinedAt,
    this.lastReadAt,
    this.role = 'member',
    this.isMuted = false,
  });

  final String conversationId;
  final String userId;
  final DateTime? joinedAt;
  final DateTime? lastReadAt;
  final String role;
  final bool isMuted;

  factory ConversationMember.fromMap(Map<String, dynamic> map) {
    return ConversationMember(
      conversationId: map['conversation_id'] as String,
      userId: map['user_id'] as String,
      joinedAt: map['joined_at'] == null
          ? null
          : DateTime.tryParse(map['joined_at'].toString()),
      lastReadAt: map['last_read_at'] == null
          ? null
          : DateTime.tryParse(map['last_read_at'].toString()),
      role: map['role'] as String? ?? 'member',
      isMuted: map['is_muted'] == 1 || map['is_muted'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversation_id': conversationId,
      'user_id': userId,
      'joined_at': joinedAt?.toIso8601String(),
      'last_read_at': lastReadAt?.toIso8601String(),
      'role': role,
      'is_muted': isMuted,
    };
  }

  Map<String, Object?> toDatabaseMap() {
    return {
      'conversation_id': conversationId,
      'user_id': userId,
      'joined_at': joinedAt?.toIso8601String(),
      'last_read_at': lastReadAt?.toIso8601String(),
      'role': role,
      'is_muted': isMuted ? 1 : 0,
    };
  }

  ConversationMember copyWith({
    String? conversationId,
    String? userId,
    DateTime? joinedAt,
    DateTime? lastReadAt,
    String? role,
    bool? isMuted,
  }) {
    return ConversationMember(
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      joinedAt: joinedAt ?? this.joinedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      role: role ?? this.role,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}
