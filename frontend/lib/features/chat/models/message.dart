class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.content,
    this.messageType = 'text',
    this.clientMessageId,
    this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.replyToMessageId,
    this.scheduledAt,
    this.isEncrypted = true,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String? content;
  final String messageType;
  final String? clientMessageId;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? replyToMessageId;
  final DateTime? scheduledAt;
  final bool isEncrypted;

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String?,
      messageType: map['message_type'] as String? ?? 'text',
      clientMessageId: map['client_message_id'] as String?,
      createdAt: _parseDateTime(map['created_at']),
      editedAt: _parseDateTime(map['edited_at']),
      deletedAt: _parseDateTime(map['deleted_at']),
      replyToMessageId: map['reply_to_message_id'] as String?,
      scheduledAt: _parseDateTime(map['scheduled_at']),
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
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'client_message_id': clientMessageId,
      'created_at': createdAt?.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'reply_to_message_id': replyToMessageId,
      'scheduled_at': scheduledAt?.toIso8601String(),
    };
  }

  Map<String, Object?> toDatabaseMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'client_message_id': clientMessageId,
      'created_at': createdAt?.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'reply_to_message_id': replyToMessageId,
      'scheduled_at': scheduledAt?.toIso8601String(),
    };
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    String? messageType,
    String? clientMessageId,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    String? replyToMessageId,
    DateTime? scheduledAt,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
    );
  }
}
