import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'internet_transport.dart';
import 'nearby_transport.dart';
import 'transport.dart';

enum ActiveTransportMode { internet, nearbyBle }

class TransportManager {
  TransportManager._();

  static final TransportManager instance = TransportManager._();

  late final InternetTransport _internetTransport;
  late final NearbyTransport _nearbyTransport;

  ActiveTransportMode _activeMode = ActiveTransportMode.internet;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final StreamController<ActiveTransportMode> _modeController =
      StreamController<ActiveTransportMode>.broadcast();

  ActiveTransportMode get activeMode => _activeMode;
  Stream<ActiveTransportMode> get modeStream => _modeController.stream;

  InternetTransport get internetTransport => _internetTransport;
  NearbyTransport get nearbyTransport => _nearbyTransport;

  Transport get activeTransport => _activeMode == ActiveTransportMode.internet
      ? _internetTransport
      : _nearbyTransport;

  void initialize({required String myDeviceId}) {
    _internetTransport = InternetTransport();
    _nearbyTransport = NearbyTransport(myDeviceId: myDeviceId);

    _internetTransport.connect();
    _nearbyTransport.connect();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);

      if (isOnline) {
        setTransportMode(ActiveTransportMode.internet);
      } else {
        setTransportMode(ActiveTransportMode.nearbyBle);
      }
    });
  }

  void setTransportMode(ActiveTransportMode mode) {
    if (_activeMode != mode) {
      _activeMode = mode;
      _modeController.add(_activeMode);
    }
  }

  Future<bool> send(dynamic packet) async {
    final success = await activeTransport.send(packet);
    if (!success && _activeMode == ActiveTransportMode.internet) {
      // Fallback attempt via Nearby BLE mesh transport
      return await _nearbyTransport.send(packet);
    }
    return success;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _internetTransport.dispose();
    _nearbyTransport.dispose();
    _modeController.close();
  }
}
