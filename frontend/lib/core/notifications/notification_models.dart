enum NotificationCategory {
  message,
  mention,
  reaction,
  callVoice,
  callVideo,
  location,
  emergency,
}

enum NotificationPermissionState {
  notRequested,
  granted,
  denied,
  permanentlyDenied,
}

class QuietHoursConfig {
  const QuietHoursConfig({
    this.enabled = false,
    this.startHour = 22,
    this.startMinute = 0,
    this.endHour = 7,
    this.endMinute = 0,
    this.allowEmergencyCalls = true,
  });

  final bool enabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final bool allowEmergencyCalls;

  bool isTimeWithinQuietHours(DateTime time) {
    if (!enabled) return false;

    final currentMin = time.hour * 60 + time.minute;
    final startMin = startHour * 60 + startMinute;
    final effectiveEndMinute = endMinute == 0 ? 59 : endMinute;
    final endMin = endHour * 60 + effectiveEndMinute;

    if (startMin <= endMin) {
      return currentMin >= startMin && currentMin <= endMin;
    } else {
      return currentMin >= startMin || currentMin <= endMin;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled ? 1 : 0,
      'start_hour': startHour,
      'start_minute': startMinute,
      'end_hour': endHour,
      'end_minute': endMinute,
      'allow_emergency_calls': allowEmergencyCalls ? 1 : 0,
    };
  }

  factory QuietHoursConfig.fromMap(Map<String, dynamic> map) {
    return QuietHoursConfig(
      enabled: map['enabled'] == 1 || map['enabled'] == true,
      startHour: (map['start_hour'] as num?)?.toInt() ?? 22,
      startMinute: (map['start_minute'] as num?)?.toInt() ?? 0,
      endHour: (map['end_hour'] as num?)?.toInt() ?? 7,
      endMinute: (map['end_minute'] as num?)?.toInt() ?? 0,
      allowEmergencyCalls:
          map['allow_emergency_calls'] == 1 ||
          map['allow_emergency_calls'] == true,
    );
  }
}

class NotificationSettings {
  NotificationSettings({
    this.enableMessages = true,
    this.enableMentions = true,
    this.enableReactions = true,
    this.enableCalls = true,
    this.enableLocation = true,
    this.quietHours = const QuietHoursConfig(),
  });

  bool enableMessages;
  bool enableMentions;
  bool enableReactions;
  bool enableCalls;
  bool enableLocation;
  QuietHoursConfig quietHours;
}
