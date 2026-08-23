class PeerHandshake {
  const PeerHandshake({
    required this.deviceId,
    required this.displayName,
    required this.challenge,
    required this.appVersion,
    required this.timestamp,
  });

  final String deviceId;
  final String displayName;
  final String challenge;
  final String appVersion;
  final DateTime timestamp;

  factory PeerHandshake.fromMap(Map<String, dynamic> map) {
    return PeerHandshake(
      deviceId: map['device_id'] as String,
      displayName: map['display_name'] as String? ?? 'Voyager Device',
      challenge: map['challenge'] as String,
      appVersion: map['app_version'] as String? ?? '1.0.0',
      timestamp:
          DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'display_name': displayName,
      'challenge': challenge,
      'app_version': appVersion,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  bool verify() {
    if (deviceId.isEmpty || challenge.isEmpty) return false;
    final diff = DateTime.now().difference(timestamp).abs();
    return diff < const Duration(minutes: 5);
  }
}
