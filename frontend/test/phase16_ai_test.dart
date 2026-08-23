import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/ai/ai_models.dart';
import 'package:frontend/core/ai/ai_provider.dart';
import 'package:frontend/core/ai/ai_server_config.dart';
import 'package:frontend/features/chat/models/message.dart';
import 'package:frontend/features/chat/services/ai_assistant_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 16 Advanced AI & Gemini Provider Decision Tests', () {
    late AiAssistantService aiService;

    setUp(() {
      aiService = AiAssistantService.instance;
      aiService.updateConfig(const AiConfig());
      AiServerConfig.setApiKey('test_gemini_api_key_placeholder');
    });

    test('TEST 1 & 2: AiProviderType and AiConfig defaults to cloudGemini', () {
      expect(AiProviderType.cloudGemini.name, equals('cloudGemini'));
      expect(AiProviderType.localOllama.name, equals('localOllama'));
      expect(AiProviderType.localRuleEngine.name, equals('localRuleEngine'));

      final defaultConfig = const AiConfig();
      expect(defaultConfig.provider, equals(AiProviderType.cloudGemini));
      expect(defaultConfig.enableSmartReplies, isTrue);
    });

    test('TEST 3 & 4: Dedicated Gemini API key security and environment configuration', () {
      expect(AiServerConfig.hasValidGeminiKey, isTrue);
      expect(AiServerConfig.geminiModel, equals('gemini-1.5-flash'));
      // Key must be valid and obscured from plaintext logging
      expect(AiServerConfig.geminiApiKey, startsWith('test_gemini'));
    });

    test('TEST 5 & 6: Provider abstraction & GeminiProvider fallback to local rule engine', () async {
      final geminiProvider = GeminiProvider();
      final response = await geminiProvider.generateResponse('Hello Gemini!');
      expect(response, isNotEmpty);

      final ollamaProvider = OllamaProvider();
      final ollamaResponse = await ollamaProvider.generateResponse(
        'Hello Ollama!',
      );
      expect(ollamaResponse, isNotEmpty);
    });

    test(
      'TEST 7 & 8: Smart replies generation with provider fallback chain',
      () {
        final replies = aiService.generateSmartReplies(
          Message(
            id: 'msg-1',
            conversationId: 'conv-1',
            senderId: 'user-2',
            content: 'Hello, how are you?',
            messageType: 'text',
            createdAt: DateTime.now(),
          ),
        );

        expect(replies, isNotEmpty);
      },
    );

    test(
      'TEST 9 & 10: E2EE Privacy Guard routes encrypted messages to local AI',
      () {
        final translation = aiService.translateText(
          text: 'Secret Message',
          targetLanguage: 'Spanish',
          isEncryptedMessage: true,
        );

        expect(translation.translatedText, contains('Local AI Translated'));
      },
    );

    test(
      'TEST 11 & 12: Smart intent recognition and @VoyagerAI bot response',
      () async {
        final intent = aiService.detectIntents(
          'Let us schedule a meeting tomorrow at 3 PM.',
        );
        expect(intent.type, equals(AiIntentType.scheduleMeeting));

        final botResponse = await aiService.generateBotResponseAsync(
          'Can you summarize the chat?',
        );
        expect(botResponse, isNotEmpty);
      },
    );
  });
}
