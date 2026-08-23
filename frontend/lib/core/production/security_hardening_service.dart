class SecurityHardeningService {
  SecurityHardeningService._();

  static final SecurityHardeningService instance = SecurityHardeningService._();

  bool isDeviceJailbrokenOrRooted() {
    // Platform abstraction for Root / Jailbreak detection
    return false;
  }

  String obfuscateKey(String secretKey) {
    if (secretKey.length <= 4) return '****';
    final prefix = secretKey.substring(0, 2);
    final suffix = secretKey.substring(secretKey.length - 2);
    return '$prefix****$suffix';
  }

  String sanitizeLogMessage(String rawLog) {
    // Redact Bearer tokens, passwords, and private keys from production log strings
    var sanitized = rawLog.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*'),
      'Bearer [REDACTED]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'password\s*[:=]\s*\S+'),
      'password: [REDACTED]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'private_key\s*[:=]\s*\S+'),
      'private_key: [REDACTED]',
    );
    return sanitized;
  }
}
