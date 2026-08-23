import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/transport/mesh/mesh_packet.dart';
import 'package:frontend/core/transport/mesh/mesh_router.dart';
import 'package:frontend/core/transport/mesh/nearby_device.dart';
import 'package:frontend/core/transport/mesh/peer_handshake.dart';
import 'package:frontend/core/transport/nearby_transport.dart';
import 'package:frontend/core/transport/transport_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 Mesh & Offline Transport Tests (Steps 101-120)', () {
    late NearbyTransport nearbyTransport;
    late MeshRouter meshRouter;

    setUp(() {
      nearbyTransport = NearbyTransport(myDeviceId: 'device-a');
      meshRouter = MeshRouter.instance;
      meshRouter.clearCache();
    });

    test('TEST 1 & 2 & 3: BLE capability and status detection', () {
      final caps = nearbyTransport.capabilities;
      expect(caps.isSupported, isTrue);
      expect(caps.supportsMeshRelay, isTrue);
      expect(caps.supportsDirectMessaging, isTrue);
    });

    test('TEST 4 & 5: Nearby scanning and device discovery', () async {
      await nearbyTransport.startScan();
      expect(nearbyTransport.isScanning, isTrue);
      expect(nearbyTransport.discoveredDevices, isNotEmpty);

      final device = nearbyTransport.discoveredDevices.first;
      expect(device.deviceId, 'peer-device-b');
      expect(device.rssi, -58);
      await nearbyTransport.stopScan();
      expect(nearbyTransport.isScanning, isFalse);
    });

    test('TEST 6: Peer handshake identity verification', () {
      final handshake = PeerHandshake(
        deviceId: 'device-c',
        displayName: 'Peer C',
        challenge: 'random-nonce-123',
        appVersion: '1.0.0',
        timestamp: DateTime.now(),
      );

      final isValid = nearbyTransport.verifyHandshake(handshake);
      expect(isValid, isTrue);
      expect(
        nearbyTransport.discoveredDevices.any((d) => d.deviceId == 'device-c'),
        isTrue,
      );
    });

    test('TEST 7: Direct nearby packet processing', () {
      final packet = MeshPacket(
        packetId: 'pkt-1',
        senderDeviceId: 'device-b',
        targetDeviceId: 'device-a',
        originUserId: 'user-b',
        conversationId: 'conv-1',
        payload: 'Hello directly via BLE',
        timestamp: DateTime.now(),
      );

      final processed = meshRouter.processPacket(
        packet,
        myDeviceId: 'device-a',
      );
      expect(processed, isTrue);
    });

    test(
      'TEST 8 & 9: Store-and-forward relay (A -> B -> C) and TTL decrement',
      () {
        final packet = MeshPacket(
          packetId: 'pkt-relay-1',
          senderDeviceId: 'device-a',
          targetDeviceId: 'device-c', // Target C is not directly reachable by A
          originUserId: 'user-a',
          conversationId: 'conv-group-1',
          payload: 'Relayed payload via B',
          timestamp: DateTime.now(),
          ttl: 5,
        );

        final processed = meshRouter.processPacket(
          packet,
          myDeviceId: 'device-b',
        );
        expect(processed, isTrue);
        expect(meshRouter.storeAndForwardQueue.length, equals(1));

        final queued = meshRouter.storeAndForwardQueue.first;
        expect(queued.ttl, equals(4));
        expect(queued.hopsCount, equals(1));
      },
    );

    test('TEST 10: Duplicate packet protection (LRU Loop Prevention)', () {
      final packet = MeshPacket(
        packetId: 'pkt-dup-1',
        senderDeviceId: 'device-a',
        targetDeviceId: 'device-b',
        originUserId: 'user-a',
        conversationId: 'conv-1',
        payload: 'Unique packet',
        timestamp: DateTime.now(),
      );

      final firstPass = meshRouter.processPacket(
        packet,
        myDeviceId: 'device-b',
      );
      expect(firstPass, isTrue);

      final duplicatePass = meshRouter.processPacket(
        packet,
        myDeviceId: 'device-b',
      );
      expect(duplicatePass, isFalse);
    });

    test('TEST 11 & 12: TransportManager automatic transport selection', () {
      final manager = TransportManager.instance;
      manager.initialize(myDeviceId: 'device-local-1');

      expect(manager.activeMode, equals(ActiveTransportMode.internet));

      manager.setTransportMode(ActiveTransportMode.nearbyBle);
      expect(manager.activeMode, equals(ActiveTransportMode.nearbyBle));
    });

    test('TEST 13: NearbyDevice toMap and fromMap serialization', () {
      final device = NearbyDevice(
        deviceId: 'dev-99',
        displayName: 'Relay Node 99',
        rssi: -45,
        lastSeen: DateTime.now(),
      );

      final map = device.toMap();
      expect(map['device_id'], 'dev-99');
      expect(map['rssi'], -45);

      final restored = NearbyDevice.fromMap(map);
      expect(restored.deviceId, 'dev-99');
      expect(restored.displayName, 'Relay Node 99');
    });
  });
}
