import 'dart:async';

enum TransportStatus {
  disconnected,
  connecting,
  connected,
  unavailable,
  disabled,
  permissionRequired,
}

class TransportCapabilities {
  const TransportCapabilities({
    required this.isSupported,
    required this.isEnabled,
    required this.hasPermissions,
    required this.supportsMeshRelay,
    required this.supportsDirectMessaging,
  });

  final bool isSupported;
  final bool isEnabled;
  final bool hasPermissions;
  final bool supportsMeshRelay;
  final bool supportsDirectMessaging;
}

abstract class Transport {
  TransportStatus get status;

  TransportCapabilities get capabilities;

  Stream<TransportStatus> get statusStream;

  Stream<dynamic> get packetStream;

  Future<void> connect();

  Future<void> disconnect();

  Future<bool> send(dynamic packet);

  Future<void> dispose();
}
