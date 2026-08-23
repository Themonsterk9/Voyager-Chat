import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../auth/services/auth_service.dart';
import 'transport.dart';

class InternetTransport implements Transport {
  InternetTransport() {
    _initConnectivityListener();
  }

  TransportStatus _status = TransportStatus.disconnected;
  final StreamController<TransportStatus> _statusController =
      StreamController<TransportStatus>.broadcast();
  final StreamController<dynamic> _packetController =
      StreamController<dynamic>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      _status = isOnline
          ? TransportStatus.connected
          : TransportStatus.disconnected;
      _statusController.add(_status);
    });
  }

  @override
  TransportCapabilities get capabilities => const TransportCapabilities(
    isSupported: true,
    isEnabled: true,
    hasPermissions: true,
    supportsMeshRelay: false,
    supportsDirectMessaging: true,
  );

  @override
  TransportStatus get status => _status;

  @override
  Stream<TransportStatus> get statusStream => _statusController.stream;

  @override
  Stream<dynamic> get packetStream => _packetController.stream;

  @override
  Future<void> connect() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        _status = TransportStatus.connected;
      } else {
        _status = TransportStatus.disconnected;
      }
    } catch (_) {
      _status = TransportStatus.connected;
    }
    _statusController.add(_status);
  }

  @override
  Future<void> disconnect() async {
    _status = TransportStatus.disconnected;
    _statusController.add(_status);
  }

  @override
  Future<bool> send(dynamic packet) async {
    if (_status != TransportStatus.connected) return false;
    _packetController.add(packet);
    return true;
  }

  @override
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _statusController.close();
    await _packetController.close();
  }
}
