import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/chat/models/message.dart';
import 'ai_models.dart';
import 'ai_server_config.dart';

abstract class AiProvider {
  Future<String> generateResponse(String prompt);

  Future<List<String>> generateSmartReplies(Message? lastMessage);

  Future<String> summarizeConversation(List<Message> messages);

  Future<TranslationResult> translateText({
    required String text,
    required String targetLanguage,
    bool isEncryptedMessage = false,
  });
}

class GeminiProvider implements AiProvider {
  GeminiProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<String> generateResponse(String prompt) async {
    if (!AiServerConfig.hasValidGeminiKey) {
      return LocalRuleEngineProvider().generateResponse(prompt);
    }

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${AiServerConfig.geminiModel}:generateContent?key=${AiServerConfig.geminiApiKey}',
      );

      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            return parts.first['text'] as String? ?? 'Gemini response empty.';
          }
        }
      }
    } catch (_) {}

    // Fallback to Ollama or Rule Engine if Gemini call fails or offline
    return LocalRuleEngineProvider().generateResponse(prompt);
  }

  @override
  Future<List<String>> generateSmartReplies(Message? lastMessage) async {
    if (lastMessage == null || lastMessage.content == null) {
      return ['Hello! 👋', 'How are you?', 'Sounds good!'];
    }

    try {
      final text = lastMessage.content!;
      final prompt =
          'Suggest 3 short, friendly chat replies to this message: "$text". Output only 3 options separated by lines.';
      final res = await generateResponse(prompt);
      final lines = res
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .take(3)
          .toList();
      if (lines.isNotEmpty) return lines;
    } catch (_) {}

    return LocalRuleEngineProvider().generateSmartReplies(lastMessage);
  }

  @override
  Future<String> summarizeConversation(List<Message> messages) async {
    if (messages.isEmpty) return 'No messages in conversation to summarize.';

    try {
      final transcript = messages
          .where((m) => m.content != null)
          .take(10)
          .map((m) => '${m.senderId}: ${m.content}')
          .join('\n');
      final prompt =
          'Summarize the following chat conversation in 2 concise sentences:\n$transcript';
      return await generateResponse(prompt);
    } catch (_) {}

    return LocalRuleEngineProvider().summarizeConversation(messages);
  }

  @override
  Future<TranslationResult> translateText({
    required String text,
    required String targetLanguage,
    bool isEncryptedMessage = false,
  }) async {
    try {
      final prompt =
          'Translate the following text into $targetLanguage. Output only the translated text:\n$text';
      final translated = await generateResponse(prompt);
      return TranslationResult(
        originalText: text,
        translatedText: translated,
        sourceLanguage: 'auto',
        targetLanguage: targetLanguage,
      );
    } catch (_) {}

    return LocalRuleEngineProvider().translateText(
      text: text,
      targetLanguage: targetLanguage,
      isEncryptedMessage: isEncryptedMessage,
    );
  }
}

class OllamaProvider implements AiProvider {
  OllamaProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<String> generateResponse(String prompt) async {
    try {
      final url = Uri.parse('${AiServerConfig.ollamaBaseUrl}/api/generate');
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': 'llama3',
          'prompt': prompt,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['response'] as String? ?? 'Ollama response empty.';
      }
    } catch (_) {}

    return LocalRuleEngineProvider().generateResponse(prompt);
  }

  @override
  Future<List<String>> generateSmartReplies(Message? lastMessage) async {
    return LocalRuleEngineProvider().generateSmartReplies(lastMessage);
  }

  @override
  Future<String> summarizeConversation(List<Message> messages) async {
    return LocalRuleEngineProvider().summarizeConversation(messages);
  }

  @override
  Future<TranslationResult> translateText({
    required String text,
    required String targetLanguage,
    bool isEncryptedMessage = false,
  }) async {
    return LocalRuleEngineProvider().translateText(
      text: text,
      targetLanguage: targetLanguage,
      isEncryptedMessage: isEncryptedMessage,
    );
  }
}

class LocalRuleEngineProvider implements AiProvider {
  @override
  Future<String> generateResponse(String userPrompt) async {
    final lower = userPrompt.toLowerCase();
    if (lower.contains('hello') || lower.contains('hi')) {
      return 'Greetings! I am VoyagerAI, your secure on-device assistant. How can I help you today?';
    }
    if (lower.contains('summary') || lower.contains('summarize')) {
      return 'VoyagerAI Summary: Your chat is active with key updates on scheduled meetings and encrypted media files.';
    }
    return 'VoyagerAI Assistant: I processed your query locally ("$userPrompt") with end-to-end privacy.';
  }

  @override
  Future<List<String>> generateSmartReplies(Message? lastMessage) async {
    if (lastMessage == null || lastMessage.content == null) {
      return ['Hello! 👋', 'How are you?', 'Sounds good!'];
    }

    final text = lastMessage.content!.toLowerCase();

    if (text.contains('hello') || text.contains('hi') || text.contains('hey')) {
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

  @override
  Future<String> summarizeConversation(List<Message> messages) async {
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

  @override
  Future<TranslationResult> translateText({
    required String text,
    required String targetLanguage,
    bool isEncryptedMessage = false,
  }) async {
    final translated = isEncryptedMessage
        ? '[Local AI Translated to $targetLanguage]: $text'
        : '[Translated to $targetLanguage]: $text';

    return TranslationResult(
      originalText: text,
      translatedText: translated,
      sourceLanguage: 'auto',
      targetLanguage: targetLanguage,
    );
  }
}
