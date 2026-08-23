class RateLimiterService {
  RateLimiterService._();

  static final RateLimiterService instance = RateLimiterService._();

  final List<DateTime> _messageTimestamps = [];
  static const int _maxMessagesPerWindow = 5;
  static const Duration _windowDuration = Duration(seconds: 3);

  bool checkCanSendMessage() {
    final now = DateTime.now();
    _messageTimestamps.removeWhere((t) => now.difference(t) > _windowDuration);

    if (_messageTimestamps.length >= _maxMessagesPerWindow) {
      return false;
    }

    _messageTimestamps.add(now);
    return true;
  }
}
