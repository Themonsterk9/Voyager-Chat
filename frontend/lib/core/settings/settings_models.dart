class ChatSettings {
  ChatSettings({
    this.enterToSend = true,
    this.mediaAutoDownload = true,
    this.showTimestamps = true,
    this.linkPreviews = true,
  });

  bool enterToSend;
  bool mediaAutoDownload;
  bool showTimestamps;
  bool linkPreviews;

  Map<String, dynamic> toMap() {
    return {
      'enter_to_send': enterToSend,
      'media_auto_download': mediaAutoDownload,
      'show_timestamps': showTimestamps,
      'link_previews': linkPreviews,
    };
  }

  factory ChatSettings.fromMap(Map<String, dynamic> map) {
    return ChatSettings(
      enterToSend: map['enter_to_send'] ?? true,
      mediaAutoDownload: map['media_auto_download'] ?? true,
      showTimestamps: map['show_timestamps'] ?? true,
      linkPreviews: map['link_previews'] ?? true,
    );
  }
}

class PrivacySettings {
  PrivacySettings({
    this.showOnlineStatus = true,
    this.showLastSeen = true,
    this.readReceipts = true,
    this.typingIndicators = true,
  });

  bool showOnlineStatus;
  bool showLastSeen;
  bool readReceipts;
  bool typingIndicators;

  Map<String, dynamic> toMap() {
    return {
      'show_online_status': showOnlineStatus,
      'show_last_seen': showLastSeen,
      'read_receipts': readReceipts,
      'typing_indicators': typingIndicators,
    };
  }

  factory PrivacySettings.fromMap(Map<String, dynamic> map) {
    return PrivacySettings(
      showOnlineStatus: map['show_online_status'] ?? true,
      showLastSeen: map['show_last_seen'] ?? true,
      readReceipts: map['read_receipts'] ?? true,
      typingIndicators: map['typing_indicators'] ?? true,
    );
  }
}

class DeviceSession {
  const DeviceSession({
    required this.deviceId,
    required this.deviceName,
    required this.deviceOs,
    required this.lastActive,
    this.isCurrentDevice = false,
    this.isVerified = false,
  });

  final String deviceId;
  final String deviceName;
  final String deviceOs;
  final DateTime lastActive;
  final bool isCurrentDevice;
  final bool isVerified;

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'device_os': deviceOs,
      'last_active': lastActive.toIso8601String(),
      'is_current': isCurrentDevice ? 1 : 0,
      'is_verified': isVerified ? 1 : 0,
    };
  }

  factory DeviceSession.fromMap(Map<String, dynamic> map) {
    return DeviceSession(
      deviceId: map['device_id'] as String,
      deviceName: map['device_name'] as String,
      deviceOs: map['device_os'] as String,
      lastActive:
          DateTime.tryParse(map['last_active'].toString()) ?? DateTime.now(),
      isCurrentDevice: map['is_current'] == 1 || map['is_current'] == true,
      isVerified: map['is_verified'] == 1 || map['is_verified'] == true,
    );
  }
}
