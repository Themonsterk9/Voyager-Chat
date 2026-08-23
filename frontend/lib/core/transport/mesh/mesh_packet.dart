class MeshPacket {
  const MeshPacket({
    required this.packetId,
    required this.senderDeviceId,
    this.targetDeviceId,
    required this.originUserId,
    this.targetUserId,
    required this.conversationId,
    required this.payload,
    required this.timestamp,
    this.ttl = 5,
    this.hopsCount = 0,
    this.protocolVersion = 1,
    this.messageId,
  });

  final String packetId;
  final String senderDeviceId;
  final String? targetDeviceId;
  final String originUserId;
  final String? targetUserId;
  final String conversationId;
  final String payload;
  final DateTime timestamp;
  final int ttl;
  final int hopsCount;
  final int protocolVersion;
  final String? messageId;

  factory MeshPacket.fromMap(Map<String, dynamic> map) {
    return MeshPacket(
      packetId: map['packet_id'] as String,
      senderDeviceId: map['sender_device_id'] as String,
      targetDeviceId: map['target_device_id'] as String?,
      originUserId: map['origin_user_id'] as String,
      targetUserId: map['target_user_id'] as String?,
      conversationId: map['conversation_id'] as String,
      payload: map['payload'] as String,
      timestamp:
          DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now(),
      ttl: (map['ttl'] as num?)?.toInt() ?? 5,
      hopsCount: (map['hops_count'] as num?)?.toInt() ?? 0,
      protocolVersion: (map['protocol_version'] as num?)?.toInt() ?? 1,
      messageId: map['message_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packet_id': packetId,
      'sender_device_id': senderDeviceId,
      'target_device_id': targetDeviceId,
      'origin_user_id': originUserId,
      'target_user_id': targetUserId,
      'conversation_id': conversationId,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
      'ttl': ttl,
      'hops_count': hopsCount,
      'protocol_version': protocolVersion,
      'message_id': messageId,
    };
  }

  MeshPacket decrementTtl() {
    return MeshPacket(
      packetId: packetId,
      senderDeviceId: senderDeviceId,
      targetDeviceId: targetDeviceId,
      originUserId: originUserId,
      targetUserId: targetUserId,
      conversationId: conversationId,
      payload: payload,
      timestamp: timestamp,
      ttl: ttl - 1,
      hopsCount: hopsCount + 1,
      protocolVersion: protocolVersion,
      messageId: messageId,
    );
  }
}
