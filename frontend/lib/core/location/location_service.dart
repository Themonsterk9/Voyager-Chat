import 'dart:async';

import 'location_data.dart';

class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  LocationPermissionState _permissionState = LocationPermissionState.granted;
  bool _isSharingLive = false;
  Timer? _liveTimer;
  StreamController<LocationData>? _liveLocationController;

  LocationPermissionState get permissionState => _permissionState;
  bool get isSharingLive => _isSharingLive;

  Future<LocationPermissionState> requestPermission() async {
    _permissionState = LocationPermissionState.granted;
    return _permissionState;
  }

  Future<LocationData?> getCurrentLocation() async {
    if (_permissionState != LocationPermissionState.granted) {
      await requestPermission();
    }

    // Returns map center coordinate with isDeviceGps: false to distinguish hardware GPS from test center
    return LocationData(
      latitude: 37.7749,
      longitude: -122.4194,
      accuracy: 5.0,
      timestamp: DateTime.now(),
      isDeviceGps: false,
    );
  }

  Stream<LocationData> startLiveLocationStream({
    Duration duration = const Duration(minutes: 15),
  }) {
    stopLiveLocationSharing();

    _isSharingLive = true;
    _liveLocationController = StreamController<LocationData>.broadcast();

    final expiresAt = DateTime.now().add(duration);

    _liveTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (DateTime.now().isAfter(expiresAt)) {
        stopLiveLocationSharing();
        return;
      }

      final loc = LocationData(
        latitude: 37.7749 + (timer.tick * 0.0001),
        longitude: -122.4194 + (timer.tick * 0.0001),
        accuracy: 4.0,
        timestamp: DateTime.now(),
        expiresAt: expiresAt,
        isLive: true,
        isDeviceGps: false,
      );

      _liveLocationController?.add(loc);
    });

    return _liveLocationController!.stream;
  }

  void stopLiveLocationSharing() {
    _isSharingLive = false;
    _liveTimer?.cancel();
    _liveTimer = null;
    _liveLocationController?.close();
    _liveLocationController = null;
  }
}
