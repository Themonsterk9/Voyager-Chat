abstract final class AiServerConfig {
  static const String _defaultGeminiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static String _overrideKey = '';

  static void setApiKey(String key) {
    _overrideKey = key;
  }

  static String get geminiApiKey {
    if (_overrideKey.isNotEmpty) return _overrideKey;
    return _defaultGeminiKey;
  }

  static const String geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-1.5-flash',
  );

  static const String ollamaBaseUrl = String.fromEnvironment(
    'OLLAMA_BASE_URL',
    defaultValue: 'http://localhost:11434',
  );

  static bool get hasValidGeminiKey => geminiApiKey.isNotEmpty;
}
