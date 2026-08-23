import 'dart:async';
import 'dart:io';

import 'mesh/mesh_packet.dart';
import 'mesh/mesh_router.dart';
import 'mesh/nearby_device.dart';
import 'mesh/peer_handshake.dart';
import 'transport.dart';

class NearbyTransport implements Transport {
  NearbyTransport({required this.myDeviceId});

  final String myDeviceId;

  TransportStatus _status = TransportStatus.disconnected;
  final StreamController<TransportStatus> _statusController =
      StreamController<TransportStatus>.broadcast();
  final StreamController<dynamic> _packetController =
      StreamController<dynamic>.broadcast();

  final List<NearbyDevice> _discoveredDevices = [];
  bool _isScanning = false;

  bool get isScanning => _isScanning;
  List<NearbyDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);

  @override
  TransportCapabilities get capabilities {
    // Cross-platform capability detection
    final isSupported =
        Platform.isAndroid || Platform.isIOS || Platform.isWindows;
    return TransportCapabilities(
      isSupported: isSupported,
      isEnabled: true,
      hasPermissions: true,
      supportsMeshRelay: true,
      supportsDirectMessaging: true,
    );
  }

  @override
  TransportStatus get status => _status;

  @override
  Stream<TransportStatus> get statusStream => _statusController.stream;

  @override
  Stream<dynamic> get packetStream => _packetController.stream;

  @override
  Future<void> connect() async {
    _status = TransportStatus.connected;
    _statusController.add(_status);
  }

  @override
  Future<void> disconnect() async {
    _status = TransportStatus.disconnected;
    _statusController.add(_status);
    stopScan();
  }

  Future<void> startScan() async {
    _isScanning = true;
    _discoveredDevices.clear();
    _statusController.add(_status);

    // Simulate scanning discovery of reachable nearby Voyager peers
    await Future.delayed(const Duration(milliseconds: 300));
    final demoPeer = NearbyDevice(
      deviceId: 'peer-device-b',
      displayName: 'Voyager Peer (Nearby)',
      rssi: -58,
      lastSeen: DateTime.now(),
      connectionState: NearbyConnectionState.connected,
    );
    _discoveredDevices.add(demoPeer);
    MeshRouter.instance.registerPeer(demoPeer);
  }

  Future<void> stopScan() async {
    _isScanning = false;
    _statusController.add(_status);
  }

  bool verifyHandshake(PeerHandshake handshake) {
    if (!handshake.verify()) return false;
    final device = NearbyDevice(
      deviceId: handshake.deviceId,
      displayName: handshake.displayName,
      lastSeen: handshake.timestamp,
      connectionState: NearbyConnectionState.connected,
    );
    _discoveredDevices.add(device);
    MeshRouter.instance.registerPeer(device);
    return true;
  }

  @override
  Future<bool> send(dynamic packet) async {
    if (packet is MeshPacket) {
      final processed = MeshRouter.instance.processPacket(
        packet,
        myDeviceId: myDeviceId,
      );
      if (processed) {
        _packetController.add(packet);
        return true;
      }
      return false;
    }
    return false;
  }

  @override
  Future<void> dispose() async {
    await stopScan();
    await _statusController.close();
    await _packetController.close();
  }
}
