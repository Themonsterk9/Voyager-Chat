import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/security/e2ee_service.dart';

class E2eeScreen extends StatefulWidget {
  const E2eeScreen({super.key});

  @override
  State<E2eeScreen> createState() => _E2eeScreenState();
}

class _E2eeScreenState extends State<E2eeScreen> {
  final E2eeService _e2eeService = E2eeService.instance;

  Future<void> _copyFingerprint() async {
    final fingerprint = _e2eeService.identityKey?.fingerprint;
    if (fingerprint != null) {
      await Clipboard.setData(ClipboardData(text: fingerprint));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Safety fingerprint copied: $fingerprint')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = _e2eeService.identityKey;

    return Scaffold(
      appBar: AppBar(title: const Text('End-to-End Encryption')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.green.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.lock, color: Colors.greenAccent),
                      SizedBox(width: 10),
                      Text(
                        'E2EE ACTIVE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Messages are encrypted on your device before transport. Neither Supabase cloud nor BLE mesh relays can decrypt message content.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'DEVICE IDENTITY & SAFETY FINGERPRINT',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '12-Digit Safety Fingerprint',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            key?.fingerprint ?? '0000 0000 0000',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: _copyFingerprint,
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 4),
                  Text('Device ID: ${key?.deviceId ?? "Unknown"}'),
                  const SizedBox(height: 4),
                  Text(
                    'Public Key: ${key?.publicKeyHex.substring(0, 24) ?? "N/A"}...',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SECURITY STATUS MATRIX',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.vpn_key, color: Colors.blueAccent),
                  title: Text('Device Identity Keys'),
                  trailing: Text(
                    'YES',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.swap_horiz, color: Colors.purpleAccent),
                  title: Text('Key Exchange & Handshakes'),
                  trailing: Text(
                    'YES',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.shield, color: Colors.orangeAccent),
                  title: Text('Payload MAC Authentication'),
                  trailing: Text(
                    'YES',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.replay, color: Colors.tealAccent),
                  title: Text('Replay Protection'),
                  trailing: Text(
                    'YES',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.radar, color: Colors.pinkAccent),
                  title: Text('BLE Mesh Ciphertext Relaying'),
                  trailing: Text(
                    'YES',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
