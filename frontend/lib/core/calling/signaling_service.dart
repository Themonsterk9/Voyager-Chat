import 'dart:async';

import 'call_models.dart';

class SignalingService {
  SignalingService._();

  static final SignalingService instance = SignalingService._();

  final _signalController = StreamController<CallSignalEvent>.broadcast();

  Stream<CallSignalEvent> get signalStream => _signalController.stream;

  void sendSignal(CallSignalEvent event) {
    // Broadcast signaling event over real-time socket channel out-of-band
    _signalController.add(event);
  }

  void dispose() {
    _signalController.close();
  }
}
