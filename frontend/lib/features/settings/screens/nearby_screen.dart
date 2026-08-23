import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/transport/mesh/mesh_router.dart';
import '../../../core/transport/transport_manager.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final TransportManager _transportManager = TransportManager.instance;
  final MeshRouter _meshRouter = MeshRouter.instance;

  StreamSubscription? _modeSubscription;

  @override
  void initState() {
    super.initState();
    _modeSubscription = _transportManager.modeStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _toggleScan() async {
    final nearby = _transportManager.nearbyTransport;
    if (nearby.isScanning) {
      await nearby.stopScan();
    } else {
      await nearby.startScan();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _modeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nearby = _transportManager.nearbyTransport;
    final caps = nearby.capabilities;
    final activeMode = _transportManager.activeMode;

    final discoveredPeers = nearby.discoveredDevices;
    final queueCount = _meshRouter.storeAndForwardQueue.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Devices & Mesh'),
        actions: [
          IconButton(
            icon: Icon(nearby.isScanning ? Icons.stop : Icons.radar),
            onPressed: _toggleScan,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: activeMode == ActiveTransportMode.internet
                ? Colors.blue.withValues(alpha: 0.15)
                : Colors.purple.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        activeMode == ActiveTransportMode.internet
                            ? Icons.cloud_done
                            : Icons.bluetooth_connected,
                        color: activeMode == ActiveTransportMode.internet
                            ? Colors.blueAccent
                            : Colors.purpleAccent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        activeMode == ActiveTransportMode.internet
                            ? 'INTERNET TRANSPORT (CLOUD)'
                            : 'NEARBY TRANSPORT (BLE MESH)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activeMode == ActiveTransportMode.internet
                        ? 'Connected to Supabase cloud. Direct & group messages are synced globally.'
                        : 'Internet is offline. Operating in peer-to-peer store-and-forward mesh mode.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'HARDWARE CAPABILITIES',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: const Text('BLE Hardware Support'),
                  trailing: Text(
                    caps.isSupported ? 'Supported' : 'Unsupported',
                    style: TextStyle(
                      color: caps.isSupported ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Location & Bluetooth Permissions'),
                  trailing: const Text(
                    'Granted',
                    style: TextStyle(color: Colors.green),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.alt_route),
                  title: const Text('Store-and-Forward Mesh Relay'),
                  trailing: const Text(
                    'Active (TTL Max 5)',
                    style: TextStyle(color: Colors.purpleAccent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DISCOVERED NEARBY PEERS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              if (nearby.isScanning)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          discoveredPeers.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No nearby Voyager peers found. Tap radar to scan.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              : Column(
                  children: discoveredPeers.map((peer) {
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purpleAccent.withValues(
                            alpha: 0.2,
                          ),
                          child: const Icon(
                            Icons.devices,
                            color: Colors.purpleAccent,
                          ),
                        ),
                        title: Text(peer.displayName),
                        subtitle: Text(
                          'ID: ${peer.deviceId} | RSSI: ${peer.rssi} dBm',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'MESH PEER',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 16),
          const Text(
            'STORE-AND-FORWARD QUEUE',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.all_inbox),
              title: const Text('Pending Mesh Packets'),
              subtitle: const Text(
                'Packets waiting for destination peers to come in range',
              ),
              trailing: Text(
                '$queueCount',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
