enum EnterpriseRole { superAdmin, orgAdmin, complianceAuditor, user }

enum AuditEventType {
  userLogin,
  userLogout,
  userRegistration,
  loginFailed,
  passwordChanged,
  passwordReset,
  otpRequested,
  otpVerified,
  googleAuthSuccess,
  profileUpdated,
  keyRotation,
  groupRoleChanged,
  retentionPolicyUpdated,
  remoteWipeExecuted,
  auditLogPurged,
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.eventType,
    required this.userId,
    required this.detailsJson,
    required this.timestamp,
    required this.prevHash,
    required this.hash,
  });

  final String id;
  final AuditEventType eventType;
  final String userId;
  final String detailsJson;
  final DateTime timestamp;
  final String prevHash;
  final String hash;
}

class DataRetentionPolicy {
  const DataRetentionPolicy({
    required this.conversationId,
    this.retentionDays = 30,
    this.autoDeleteEphemeral = true,
  });

  final String conversationId;
  final int retentionDays;
  final bool autoDeleteEphemeral;
}
