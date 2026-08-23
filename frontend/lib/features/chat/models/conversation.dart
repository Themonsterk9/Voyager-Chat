class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    this.name,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.pinnedAt,
    this.archivedAt,
    this.avatarUrl,
    this.inviteCode,
    this.draftText,
  });

  final String id;
  final String type;
  final String? name;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? pinnedAt;
  final DateTime? archivedAt;
  final String? avatarUrl;
  final String? inviteCode;
  final String? draftText;

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      type: map['type'] as String? ?? 'direct',
      name: map['name'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
      pinnedAt: _parseDateTime(map['pinned_at']),
      archivedAt: _parseDateTime(map['archived_at']),
      avatarUrl: map['avatar_url'] as String?,
      inviteCode: map['invite_code'] as String?,
      draftText: map['draft_text'] as String?,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'pinned_at': pinnedAt?.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
      'avatar_url': avatarUrl,
      'invite_code': inviteCode,
      'draft_text': draftText,
    };
  }

  Map<String, Object?> toDatabaseMap() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'pinned_at': pinnedAt?.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
      'avatar_url': avatarUrl,
      'invite_code': inviteCode,
      'draft_text': draftText,
    };
  }

  Conversation copyWith({
    String? id,
    String? type,
    String? name,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? pinnedAt,
    DateTime? archivedAt,
    String? avatarUrl,
    String? inviteCode,
    String? draftText,
    bool clearPinnedAt = false,
    bool clearArchivedAt = false,
    bool clearDraftText = false,
  }) {
    return Conversation(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pinnedAt: clearPinnedAt ? null : (pinnedAt ?? this.pinnedAt),
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      avatarUrl: avatarUrl ?? this.avatarUrl,
      inviteCode: inviteCode ?? this.inviteCode,
      draftText: clearDraftText ? null : (draftText ?? this.draftText),
    );
  }
}
