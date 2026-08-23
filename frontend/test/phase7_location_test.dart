import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/location/location_data.dart';
import 'package:frontend/core/location/location_service.dart';
import 'package:frontend/core/location/map_server_config.dart';
import 'package:frontend/core/security/e2ee_service.dart';
import 'package:frontend/core/transport/mesh/mesh_packet.dart';
import 'package:frontend/core/transport/mesh/mesh_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Phase 7 Location, Maps & Emergency Communication Tests (Steps 141-160)',
    () {
      late LocationService locationService;

      setUp(() {
        locationService = LocationService.instance;
        E2eeService.instance.initialize(
          userId: 'user-alice',
          deviceId: 'device-alice',
        );
      });

      test(
        'TEST 1 & 2: GPS permission management and LocationData formatting',
        () async {
          final perm = await locationService.requestPermission();
          expect(perm, equals(LocationPermissionState.granted));

          final loc = LocationData(
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 4.5,
            timestamp: DateTime.parse('2026-08-22T02:00:00Z'),
          );

          expect(loc.formatCoordinates(), equals('37.7749°, -122.4194°'));
          expect(loc.isExpired, isFalse);
        },
      );

      test(
        'TEST 3 & 4: Current location retrieval and expiration check',
        () async {
          final currentLocation = await locationService.getCurrentLocation();
          expect(currentLocation, isNotNull);
          expect(currentLocation!.latitude, equals(37.7749));
          expect(currentLocation.longitude, equals(-122.4194));

          final pastLoc = LocationData(
            latitude: 10.0,
            longitude: 20.0,
            timestamp: DateTime.now(),
            expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
          );
          expect(pastLoc.isExpired, isTrue);
        },
      );

      test(
        'TEST 5 & 6: Live location sharing stream emission and automatic stop',
        () async {
          final stream = locationService.startLiveLocationStream(
            duration: const Duration(seconds: 1),
          );
          expect(stream, isNotNull);
          expect(locationService.isSharingLive, isTrue);

          locationService.stopLiveLocationSharing();
          expect(locationService.isSharingLive, isFalse);
        },
      );

      test('TEST 7: Location payload E2EE encryption before transport', () {
        final loc = LocationData(
          latitude: 34.0522,
          longitude: -118.2437,
          timestamp: DateTime.now(),
        );

        final jsonPayload = loc.formatCoordinates();
        final encryptedCiphertext = E2eeService.instance.encryptPayload(
          jsonPayload,
          'device-recipient',
        );

        expect(encryptedCiphertext, startsWith('[E2EE-v1:'));
        expect(encryptedCiphertext, isNot(contains('34.0522')));

        // Decrypt at recipient
        final decrypted = E2eeService.instance.decryptPayload(
          encryptedCiphertext,
          'device-recipient',
        );
        expect(decrypted, equals('34.0522°, -118.2437°'));
      });

      test(
        'TEST 8: BLE Mesh forwards location ciphertext without decrypting',
        () {
          final encryptedLocation = E2eeService.instance.encryptPayload(
            '37.7749°, -122.4194°',
            'device-dest',
          );

          final packet = MeshPacket(
            packetId: 'loc-pkt-500',
            senderDeviceId: 'device-alice',
            targetDeviceId: 'device-dest',
            originUserId: 'user-alice',
            conversationId: 'conv-loc-1',
            payload: encryptedLocation,
            timestamp: DateTime.now(),
          );

          final processed = MeshRouter.instance.processPacket(
            packet,
            myDeviceId: 'device-relay-intermediate',
          );
          expect(processed, isTrue);

          final queued = MeshRouter.instance.storeAndForwardQueue.first;
          expect(queued.payload, startsWith('[E2EE-v1:'));
          expect(queued.payload, isNot(contains('37.7749')));
        },
      );

      test('TEST 9 & 10: LocationData toMap and fromMap serialization', () {
        final loc = LocationData(
          latitude: 51.5074,
          longitude: -0.1278,
          accuracy: 8.0,
          timestamp: DateTime.parse('2026-08-22T02:00:00Z'),
          isLive: true,
        );

        final map = loc.toMap();
        expect(map['latitude'], 51.5074);
        expect(map['is_live'], 1);

        final restored = LocationData.fromMap(map);
        expect(restored.latitude, 51.5074);
        expect(restored.longitude, -0.1278);
        expect(restored.isLive, isTrue);
      });

      test('TEST 11 & 12: MapServerConfig MapTiler API Key security and MapLibre style URL formatting', () {
        expect(MapServerConfig.mapTilerStyle, equals('streets-v2'));

        MapServerConfig.setApiKey('Cb8A7gWywdfBszgIwVdC');
        expect(MapServerConfig.hasValidKey, isTrue);
        expect(
          MapServerConfig.vectorStyleUrl,
          contains(
            'api.maptiler.com/maps/streets-v2/style.json?key=Cb8A7gWywdfBszgIwVdC',
          ),
        );
        expect(
          MapServerConfig.rasterTileUrlTemplate,
          contains(
            'api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=Cb8A7gWywdfBszgIwVdC',
          ),
        );
        expect(
          MapServerConfig.buildTileUrl(14, 2624, 6333),
          contains(
            'api.maptiler.com/maps/streets-v2/256/14/2624/6333.png?key=Cb8A7gWywdfBszgIwVdC',
          ),
        );
        final tile = MapServerConfig.latLngToTileXY(37.7749, -122.4194, 13);
        expect(tile.x, equals(1310));
        expect(tile.y, equals(3166));

        final grid = MapServerConfig.getSurroundingTileGrid(
          37.7749,
          -122.4194,
          13,
        );
        expect(grid, hasLength(9));
        expect(
          MapServerConfig.buildTileUrlForProvider(
            MapProviderType.openStreetMap,
            14,
            2624,
            6333,
          ),
          equals('https://tile.openstreetmap.org/14/2624/6333.png'),
        );
        expect(MapServerConfig.obfuscatedKey, equals('Cb8A...wVdC'));
      });
    },
  );
}
