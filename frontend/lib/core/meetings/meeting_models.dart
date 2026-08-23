enum MeetingStatus { scheduled, waiting, active, ended, cancelled }

enum MeetingRole { host, coHost, participant }

class MeetingParticipant {
  const MeetingParticipant({
    required this.userId,
    required this.displayName,
    this.role = MeetingRole.participant,
    this.isMuted = false,
    this.isCameraOn = true,
    this.isHandRaised = false,
    this.isAdmitted = false,
  });

  final String userId;
  final String displayName;
  final MeetingRole role;
  final bool isMuted;
  final bool isCameraOn;
  final bool isHandRaised;
  final bool isAdmitted;

  MeetingParticipant copyWith({
    MeetingRole? role,
    bool? isMuted,
    bool? isCameraOn,
    bool? isHandRaised,
    bool? isAdmitted,
  }) {
    return MeetingParticipant(
      userId: userId,
      displayName: displayName,
      role: role ?? this.role,
      isMuted: isMuted ?? this.isMuted,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      isAdmitted: isAdmitted ?? this.isAdmitted,
    );
  }
}

class MeetingSession {
  const MeetingSession({
    required this.id,
    required this.conversationId,
    required this.title,
    this.description,
    required this.hostId,
    required this.scheduledTime,
    this.startedAt,
    this.endedAt,
    this.status = MeetingStatus.scheduled,
    this.participantLimit = 25,
  });

  final String id;
  final String conversationId;
  final String title;
  final String? description;
  final String hostId;
  final DateTime scheduledTime;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final MeetingStatus status;
  final int participantLimit;
}
