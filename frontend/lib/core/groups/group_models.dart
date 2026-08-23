enum GroupRole { owner, admin, moderator, member }

enum GroupPrivacy { public, private, inviteOnly }

class GroupPollOption {
  const GroupPollOption({required this.id, required this.text, this.votes = 0});

  final String id;
  final String text;
  final int votes;

  Map<String, dynamic> toMap() {
    return {'id': id, 'text': text, 'votes': votes};
  }

  factory GroupPollOption.fromMap(Map<String, dynamic> map) {
    return GroupPollOption(
      id: map['id'] as String,
      text: map['text'] as String,
      votes: (map['votes'] as num?)?.toInt() ?? 0,
    );
  }
}

class GroupPoll {
  GroupPoll({
    required this.id,
    required this.conversationId,
    required this.question,
    required this.options,
    this.voterUserIds = const [],
  });

  final String id;
  final String conversationId;
  final String question;
  final List<GroupPollOption> options;
  final List<String> voterUserIds;

  int get totalVotes => options.fold(0, (sum, opt) => sum + opt.votes);
}

class GroupEvent {
  const GroupEvent({
    required this.id,
    required this.conversationId,
    required this.title,
    this.description,
    required this.eventDate,
    this.locationName,
    required this.creatorId,
  });

  final String id;
  final String conversationId;
  final String title;
  final String? description;
  final DateTime eventDate;
  final String? locationName;
  final String creatorId;
}

class GroupAnnouncement {
  const GroupAnnouncement({
    required this.id,
    required this.conversationId,
    required this.title,
    required this.content,
    required this.authorName,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String title;
  final String content;
  final String authorName;
  final DateTime createdAt;
}
