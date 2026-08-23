import 'dart:async';

import '../database/app_database.dart';
import 'call_models.dart';
import 'signaling_service.dart';

class CallManager {
  CallManager._();

  static final CallManager instance = CallManager._();

  CallState _state = CallState.idle;
  CallType _callType = CallType.voice;
  String? _activeCallId;
  String? _activeConversationId;
  String? _remoteParticipantName;

  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isCameraOn = true;
  bool _isFrontCamera = true;
  bool _isScreenSharing = false;

  Timer? _durationTimer;
  int _durationSeconds = 0;
  DateTime? _startTime;

  final _stateController = StreamController<CallState>.broadcast();
  final _durationController = StreamController<int>.broadcast();

  CallState get state => _state;
  CallType get callType => _callType;
  String? get activeCallId => _activeCallId;
  String? get remoteParticipantName => _remoteParticipantName;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isCameraOn => _isCameraOn;
  bool get isFrontCamera => _isFrontCamera;
  bool get isScreenSharing => _isScreenSharing;
  int get durationSeconds => _durationSeconds;

  Stream<CallState> get stateStream => _stateController.stream;
  Stream<int> get durationStream => _durationController.stream;

  void startCall({
    required String conversationId,
    required String recipientId,
    required String recipientName,
    required CallType type,
  }) {
    _activeCallId = 'call-${DateTime.now().millisecondsSinceEpoch}';
    _activeConversationId = conversationId;
    _remoteParticipantName = recipientName;
    _callType = type;
    _state = CallState.calling;
    _stateController.add(_state);

    // Send WebRTC invitation offer signal out-of-band
    SignalingService.instance.sendSignal(
      CallSignalEvent(
        callId: _activeCallId!,
        senderId: 'current-user',
        recipientId: recipientId,
        type: SignalEventType.offer,
        callType: type,
        timestamp: DateTime.now(),
      ),
    );
  }

  void acceptCall() {
    _state = CallState.connecting;
    _stateController.add(_state);

    // Simulate WebRTC connection establishment
    Future.delayed(const Duration(milliseconds: 500), () {
      _state = CallState.connected;
      _startTime = DateTime.now();
      _durationSeconds = 0;
      _stateController.add(_state);

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _durationSeconds++;
        _durationController.add(_durationSeconds);
      });
    });
  }

  void declineCall() {
    _state = CallState.declined;
    _stateController.add(_state);
    _saveCallLog(status: 'declined');
    _cleanup();
  }

  void endCall() {
    _state = CallState.ended;
    _stateController.add(_state);
    _saveCallLog(status: 'completed');
    _cleanup();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
  }

  void toggleCamera() {
    _isCameraOn = !_isCameraOn;
  }

  void switchCamera() {
    _isFrontCamera = !_isFrontCamera;
  }

  void startScreenShare() {
    _isScreenSharing = true;
  }

  void stopScreenShare() {
    _isScreenSharing = false;
  }

  Future<void> _saveCallLog({required String status}) async {
    if (_activeCallId == null || _activeConversationId == null) return;

    try {
      final db = await AppDatabase.instance.database;
      final log = CallLog(
        id: _activeCallId!,
        conversationId: _activeConversationId!,
        callerId: 'current-user',
        callerName: _remoteParticipantName ?? 'Contact',
        callType: _callType,
        startTime: _startTime ?? DateTime.now(),
        endTime: DateTime.now(),
        durationSeconds: _durationSeconds,
        status: status,
      );

      await db.insert('call_logs', log.toMap());
    } catch (_) {}
  }

  void _cleanup() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _isScreenSharing = false;
    Future.delayed(const Duration(seconds: 1), () {
      _state = CallState.idle;
      _stateController.add(_state);
    });
  }

  void dispose() {
    _durationTimer?.cancel();
    _stateController.close();
    _durationController.close();
  }
}
