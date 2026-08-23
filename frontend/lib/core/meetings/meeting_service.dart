import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../calling/call_manager.dart';
import '../calling/call_models.dart';
import '../database/app_database.dart';
import 'meeting_models.dart';

class MeetingService {
  MeetingService._();

  static final MeetingService instance = MeetingService._();

  final Map<String, List<MeetingParticipant>> _participantsMap = {};

  Future<MeetingSession> createMeeting({
    required String conversationId,
    required String title,
    String? description,
    required String hostId,
    required DateTime scheduledTime,
  }) async {
    final meetingId = 'mtg_${DateTime.now().millisecondsSinceEpoch}';
    final session = MeetingSession(
      id: meetingId,
      conversationId: conversationId,
      title: title,
      description: description,
      hostId: hostId,
      scheduledTime: scheduledTime,
      status: MeetingStatus.scheduled,
    );

    // Add Host as admitted participant
    _participantsMap[meetingId] = [
      MeetingParticipant(
        userId: hostId,
        displayName: 'Host User',
        role: MeetingRole.host,
        isAdmitted: true,
      ),
    ];

    try {
      final db = await AppDatabase.instance.database;
      await db.insert('meetings', {
        'id': session.id,
        'conversation_id': session.conversationId,
        'title': session.title,
        'description': session.description,
        'host_id': session.hostId,
        'scheduled_time': session.scheduledTime.toIso8601String(),
        'status': session.status.name,
        'participant_limit': session.participantLimit,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}

    return session;
  }

  Future<void> joinMeetingLobby({
    required String meetingId,
    required String userId,
    required String displayName,
  }) async {
    final list = _participantsMap.putIfAbsent(meetingId, () => []);

    if (!list.any((p) => p.userId == userId)) {
      list.add(
        MeetingParticipant(
          userId: userId,
          displayName: displayName,
          role: MeetingRole.participant,
          isAdmitted: false, // Placed in Waiting Room by default
        ),
      );
    }
  }

  void admitParticipant(String meetingId, String userId) {
    final list = _participantsMap[meetingId];
    if (list != null) {
      final index = list.indexWhere((p) => p.userId == userId);
      if (index != -1) {
        list[index] = list[index].copyWith(isAdmitted: true);
      }
    }
  }

  void rejectParticipant(String meetingId, String userId) {
    final list = _participantsMap[meetingId];
    if (list != null) {
      list.removeWhere((p) => p.userId == userId);
    }
  }

  void toggleHandRaise(String meetingId, String userId) {
    final list = _participantsMap[meetingId];
    if (list != null) {
      final index = list.indexWhere((p) => p.userId == userId);
      if (index != -1) {
        final current = list[index];
        list[index] = current.copyWith(isHandRaised: !current.isHandRaised);
      }
    }
  }

  List<MeetingParticipant> getParticipants(String meetingId) {
    return List.unmodifiable(_participantsMap[meetingId] ?? []);
  }

  void startMeetingCall(String recipientName) {
    CallManager.instance.startCall(
      conversationId: 'meeting-channel',
      recipientId: 'recipient-meeting-channel',
      recipientName: recipientName,
      type: CallType.video,
    );
  }
}
