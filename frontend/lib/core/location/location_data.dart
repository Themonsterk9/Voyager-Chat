enum LocationPermissionState { granted, denied, permanentlyDenied, disabled }

class LocationData {
  const LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy = 10.0,
    required this.timestamp,
    this.altitude,
    this.heading,
    this.expiresAt,
    this.isLive = false,
    this.isDeviceGps = false,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final double? altitude;
  final double? heading;
  final DateTime? expiresAt;
  final bool isLive;
  final bool isDeviceGps;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 10.0,
      timestamp:
          DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'].toString())
          : null,
      isLive: map['is_live'] == true || map['is_live'] == 1,
      isDeviceGps: map['is_device_gps'] == true || map['is_device_gps'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      'altitude': altitude,
      'heading': heading,
      'expires_at': expiresAt?.toIso8601String(),
      'is_live': isLive ? 1 : 0,
      'is_device_gps': isDeviceGps ? 1 : 0,
    };
  }

  String formatCoordinates() {
    return '${latitude.toStringAsFixed(4)}°, ${longitude.toStringAsFixed(4)}°';
  }
}
