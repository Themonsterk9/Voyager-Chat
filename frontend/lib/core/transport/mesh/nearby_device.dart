enum NearbyConnectionState { disconnected, connecting, connected, failed }

class NearbyDevice {
  const NearbyDevice({
    required this.deviceId,
    required this.displayName,
    this.rssi = -60,
    required this.lastSeen,
    this.connectionState = NearbyConnectionState.disconnected,
    this.isMeshRelay = true,
    this.isTrusted = true,
  });

  final String deviceId;
  final String displayName;
  final int rssi;
  final DateTime lastSeen;
  final NearbyConnectionState connectionState;
  final bool isMeshRelay;
  final bool isTrusted;

  factory NearbyDevice.fromMap(Map<String, dynamic> map) {
    return NearbyDevice(
      deviceId: map['device_id'] as String,
      displayName: map['display_name'] as String? ?? 'Nearby Voyager Peer',
      rssi: (map['rssi'] as num?)?.toInt() ?? -60,
      lastSeen:
          DateTime.tryParse(map['last_seen'].toString()) ?? DateTime.now(),
      connectionState: NearbyConnectionState.connected,
      isMeshRelay: true,
      isTrusted: (map['is_trusted'] as num?)?.toInt() == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'display_name': displayName,
      'rssi': rssi,
      'last_seen': lastSeen.toIso8601String(),
      'is_trusted': isTrusted ? 1 : 0,
    };
  }

  NearbyDevice copyWith({
    String? deviceId,
    String? displayName,
    int? rssi,
    DateTime? lastSeen,
    NearbyConnectionState? connectionState,
    bool? isMeshRelay,
    bool? isTrusted,
  }) {
    return NearbyDevice(
      deviceId: deviceId ?? this.deviceId,
      displayName: displayName ?? this.displayName,
      rssi: rssi ?? this.rssi,
      lastSeen: lastSeen ?? this.lastSeen,
      connectionState: connectionState ?? this.connectionState,
      isMeshRelay: isMeshRelay ?? this.isMeshRelay,
      isTrusted: isTrusted ?? this.isTrusted,
    );
  }
}
