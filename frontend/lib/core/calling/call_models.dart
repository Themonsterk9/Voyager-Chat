enum CallType { voice, video, groupVoice, groupVideo }

enum CallState {
  idle,
  calling,
  ringing,
  connecting,
  connected,
  reconnecting,
  declined,
  ended,
  failed,
}

enum SignalEventType {
  offer,
  answer,
  iceCandidate,
  accept,
  decline,
  cancel,
  end,
}

class CallSignalEvent {
  const CallSignalEvent({
    required this.callId,
    required this.senderId,
    required this.recipientId,
    required this.type,
    required this.callType,
    this.sdp,
    this.candidate,
    required this.timestamp,
  });

  final String callId;
  final String senderId;
  final String recipientId;
  final SignalEventType type;
  final CallType callType;
  final String? sdp;
  final String? candidate;
  final DateTime timestamp;

  Map<String, dynamic> toMap() {
    return {
      'call_id': callId,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'type': type.name,
      'call_type': callType.name,
      'sdp': sdp,
      'candidate': candidate,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory CallSignalEvent.fromMap(Map<String, dynamic> map) {
    return CallSignalEvent(
      callId: map['call_id'] as String,
      senderId: map['sender_id'] as String,
      recipientId: map['recipient_id'] as String,
      type: SignalEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SignalEventType.offer,
      ),
      callType: CallType.values.firstWhere(
        (e) => e.name == map['call_type'],
        orElse: () => CallType.voice,
      ),
      sdp: map['sdp'] as String?,
      candidate: map['candidate'] as String?,
      timestamp:
          DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now(),
    );
  }
}

class CallLog {
  const CallLog({
    required this.id,
    required this.conversationId,
    required this.callerId,
    required this.callerName,
    required this.callType,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    required this.status,
  });

  final String id;
  final String conversationId;
  final String callerId;
  final String callerName;
  final CallType callType;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final String status; // 'completed', 'missed', 'declined', 'failed'

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'caller_id': callerId,
      'caller_name': callerName,
      'call_type': callType.name,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'status': status,
    };
  }

  factory CallLog.fromMap(Map<String, dynamic> map) {
    return CallLog(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      callerId: map['caller_id'] as String,
      callerName: map['caller_name'] as String,
      callType: CallType.values.firstWhere(
        (e) => e.name == map['call_type'],
        orElse: () => CallType.voice,
      ),
      startTime:
          DateTime.tryParse(map['start_time'].toString()) ?? DateTime.now(),
      endTime: map['end_time'] != null
          ? DateTime.tryParse(map['end_time'].toString())
          : null,
      durationSeconds: (map['duration_seconds'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'completed',
    );
  }
}
