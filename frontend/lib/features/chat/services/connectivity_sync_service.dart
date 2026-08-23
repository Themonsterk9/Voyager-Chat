import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'pending_message_sync_service.dart';

class ConnectivitySyncService {
  ConnectivitySyncService._();

  static final ConnectivitySyncService instance = ConnectivitySyncService._();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;

    _subscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final hasConnection = results.any(
        (result) => result != ConnectivityResult.none,
      );

      if (!hasConnection) {
        return;
      }

      await PendingMessageSyncService.instance.syncPendingMessages();
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
