import 'dart:async';

import 'mesh_packet.dart';
import 'nearby_device.dart';

class MeshRouter {
  MeshRouter._();

  static final MeshRouter instance = MeshRouter._();

  final Set<String> _seenPacketIds = {};
  final List<MeshPacket> _storeAndForwardQueue = [];
  final Map<String, NearbyDevice> _activePeers = {};

  final StreamController<MeshPacket> _incomingPacketController =
      StreamController<MeshPacket>.broadcast();

  Stream<MeshPacket> get onPacketReceived => _incomingPacketController.stream;

  List<MeshPacket> get storeAndForwardQueue =>
      List.unmodifiable(_storeAndForwardQueue);
  List<NearbyDevice> get activePeers => _activePeers.values.toList();

  void registerPeer(NearbyDevice device) {
    _activePeers[device.deviceId] = device;
  }

  void unregisterPeer(String deviceId) {
    _activePeers.remove(deviceId);
  }

  bool processPacket(MeshPacket packet, {required String myDeviceId}) {
    // Step 1: Check duplicate packet cache to prevent loops (A -> B -> C -> B -> A)
    if (_seenPacketIds.contains(packet.packetId)) {
      return false;
    }

    // Cache packet ID
    _seenPacketIds.add(packet.packetId);
    if (_seenPacketIds.length > 500) {
      _seenPacketIds.remove(_seenPacketIds.first);
    }

    // Step 2: Validate TTL (Bounded hop count protection)
    if (packet.ttl <= 0) {
      return false;
    }

    // Step 3: Check if packet is intended for me
    if (packet.targetDeviceId == null || packet.targetDeviceId == myDeviceId) {
      _incomingPacketController.add(packet);
    }

    // Step 4: If target is another device, handle store-and-forward relaying
    if (packet.targetDeviceId != null && packet.targetDeviceId != myDeviceId) {
      final forwardedPacket = packet.decrementTtl();

      if (_activePeers.containsKey(packet.targetDeviceId)) {
        // Direct relay to target peer if currently connected
        _relayToPeer(packet.targetDeviceId!, forwardedPacket);
      } else {
        // Store packet for forward delivery when target peer becomes reachable
        _storeAndForwardQueue.add(forwardedPacket);
      }
    }

    return true;
  }

  void _relayToPeer(String deviceId, MeshPacket packet) {
    // Peer relay output
  }

  void flushQueueForPeer(String deviceId) {
    _storeAndForwardQueue.removeWhere((p) {
      if (p.targetDeviceId == deviceId) {
        _relayToPeer(deviceId, p);
        return true;
      }
      return false;
    });
  }

  void clearCache() {
    _seenPacketIds.clear();
    _storeAndForwardQueue.clear();
    _activePeers.clear();
  }
}
