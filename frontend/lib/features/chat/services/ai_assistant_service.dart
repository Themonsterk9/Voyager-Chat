import '../../../core/ai/ai_models.dart';
import '../../../core/ai/ai_provider.dart';
import '../models/message.dart';

class AiAssistantService {
  AiAssistantService._();

  static final AiAssistantService instance = AiAssistantService._();

  AiConfig _config = const AiConfig();

  AiConfig get config => _config;

  void updateConfig(AiConfig newConfig) {
    _config = newConfig;
  }

  AiProvider _getProvider({bool isEncryptedMessage = false}) {
    if (isEncryptedMessage && !_config.allowCloudE2eeProcessing) {
      return LocalRuleEngineProvider();
    }

    switch (_config.provider) {
      case AiProviderType.cloudGemini:
        return GeminiProvider();
      case AiProviderType.localOllama:
        return OllamaProvider();
      case AiProviderType.localRuleEngine:
      default:
        return LocalRuleEngineProvider();
    }
  }

  List<String> generateSmartReplies(Message? lastMessage) {
    if (!_config.enableSmartReplies) return [];

    final provider = _getProvider(
      isEncryptedMessage: lastMessage?.isEncrypted ?? false,
    );
    if (provider is LocalRuleEngineProvider) {
      // Synchronous return for local rule engine
      final text = lastMessage?.content?.toLowerCase() ?? '';
      if (text.contains('hello') ||
          text.contains('hi') ||
          text.contains('hey')) {
        return ['Hi there! 👋', 'Hello! How can I help?', 'Hey!'];
      }
      if (text.contains('how are you') || text.contains('how r u')) {
        return [
          "I'm doing great, thanks!",
          'All good! How about you?',
          'Doing well!',
        ];
      }
      if (text.contains('when') ||
          text.contains('time') ||
          text.contains('meeting')) {
        return ['Let me check my calendar 📅', 'How about 3 PM?', 'Free now!'];
      }
      if (text.contains('?')) {
        return ['Yes, absolutely!', 'Let me get back to you.', 'Sure thing!'];
      }
      return ['Sounds great! 👍', 'Got it, thanks!', 'Awesome! 😊'];
    }

    return ['Sounds great! 👍', 'Got it, thanks!', 'Awesome! 😊'];
  }

  Future<List<String>> generateSmartRepliesAsync(Message? lastMessage) async {
    if (!_config.enableSmartReplies) return [];
    final provider = _getProvider(
      isEncryptedMessage: lastMessage?.isEncrypted ?? false,
    );
    return await provider.generateSmartReplies(lastMessage);
  }

  String summarizeConversation(List<Message> messages) {
    if (messages.isEmpty) {
      return 'No messages in conversation to summarize.';
    }

    final textCount = messages
        .where((m) => m.content != null && m.deletedAt == null)
        .length;
    final imageCount = messages.where((m) => m.messageType == 'image').length;
    final fileCount = messages.where((m) => m.messageType == 'file').length;

    return 'Summary: $textCount text messages exchanged, $imageCount shared images, and $fileCount attached files.';
  }

  Future<String> summarizeConversationAsync(List<Message> messages) async {
    final provider = _getProvider();
    return await provider.summarizeConversation(messages);
  }

  TranslationResult translateText({
    required String text,
    required String targetLanguage,
    bool isEncryptedMessage = false,
  }) {
    final translated = isEncryptedMessage && !_config.allowCloudE2eeProcessing
        ? '[Local AI Translated to $targetLanguage]: $text'
        : '[Translated to $targetLanguage]: $text';

    return TranslationResult(
      originalText: text,
      translatedText: translated,
      sourceLanguage: 'auto',
      targetLanguage: targetLanguage,
    );
  }

  Future<TranslationResult> translateTextAsync({
    required String text,
    required String targetLanguage,
    bool isEncryptedMessage = false,
  }) async {
    final provider = _getProvider(isEncryptedMessage: isEncryptedMessage);
    return await provider.translateText(
      text: text,
      targetLanguage: targetLanguage,
      isEncryptedMessage: isEncryptedMessage,
    );
  }

  AiIntent detectIntents(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('meet') ||
        lower.contains('schedule') ||
        lower.contains('calendar')) {
      return const AiIntent(
        type: AiIntentType.scheduleMeeting,
        confidence: 0.92,
        extractedData: {'action': 'schedule', 'topic': 'meeting'},
      );
    }

    if (lower.contains('where') ||
        lower.contains('location') ||
        lower.contains('map')) {
      return const AiIntent(
        type: AiIntentType.shareLocation,
        confidence: 0.88,
        extractedData: {'action': 'share_location'},
      );
    }

    if (lower.contains('remind') || lower.contains('dont forget')) {
      return const AiIntent(
        type: AiIntentType.setReminder,
        confidence: 0.85,
        extractedData: {'action': 'reminder'},
      );
    }

    return const AiIntent(
      type: AiIntentType.unknown,
      confidence: 0.0,
      extractedData: {},
    );
  }

  String generateBotResponse(String userPrompt) {
    if (userPrompt.contains('hello') || userPrompt.contains('hi')) {
      return 'Greetings! I am VoyagerAI, your secure on-device assistant. How can I help you today?';
    }

    if (userPrompt.contains('summary') || userPrompt.contains('summarize')) {
      return 'VoyagerAI Summary: Your chat is active with key updates on scheduled meetings and encrypted media files.';
    }

    return 'VoyagerAI Assistant: I processed your query locally ("$userPrompt") with end-to-end privacy.';
  }

  Future<String> generateBotResponseAsync(String userPrompt) async {
    final provider = _getProvider();
    return await provider.generateResponse(userPrompt);
  }
}
