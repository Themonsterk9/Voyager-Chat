enum AiProviderType { cloudGemini, localOllama, localRuleEngine, cloudOpenAi }

enum AiIntentType { scheduleMeeting, shareLocation, setReminder, unknown }

class AiIntent {
  const AiIntent({
    required this.type,
    required this.confidence,
    required this.extractedData,
  });

  final AiIntentType type;
  final double confidence;
  final Map<String, dynamic> extractedData;
}

class TranslationResult {
  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
}

class AiConfig {
  const AiConfig({
    this.provider = AiProviderType.cloudGemini,
    this.enableSmartReplies = true,
    this.enableAutoSummarization = true,
    this.allowCloudE2eeProcessing = false,
  });

  final AiProviderType provider;
  final bool enableSmartReplies;
  final bool enableAutoSummarization;
  final bool allowCloudE2eeProcessing;
}
