import 'package:flutter/material.dart';

import '../../../core/ai/ai_models.dart';
import '../../chat/services/ai_assistant_service.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late AiConfig _config;

  @override
  void initState() {
    super.initState();
    _config = AiAssistantService.instance.config;
  }

  void _updateConfig(AiConfig newConfig) {
    setState(() {
      _config = newConfig;
    });
    AiAssistantService.instance.updateConfig(newConfig);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI & Smart Assistant Preferences')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'AI PROVIDER ENGINE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          RadioGroup<AiProviderType>(
            groupValue: _config.provider,
            onChanged: (val) {
              if (val != null) {
                _updateConfig(
                  AiConfig(
                    provider: val,
                    enableSmartReplies: _config.enableSmartReplies,
                    enableAutoSummarization: _config.enableAutoSummarization,
                    allowCloudE2eeProcessing: _config.allowCloudE2eeProcessing,
                  ),
                );
              }
            },
            child: Column(
              children: const [
                RadioListTile<AiProviderType>(
                  title: Text('Google Gemini API (Primary Cloud AI)'),
                  subtitle: Text(
                    'Gemini 1.5 Flash - Dedicated Voyager AI Provider',
                  ),
                  value: AiProviderType.cloudGemini,
                ),
                RadioListTile<AiProviderType>(
                  title: Text('Local Ollama Instance'),
                  subtitle: Text('Connect to http://localhost:11434'),
                  value: AiProviderType.localOllama,
                ),
                RadioListTile<AiProviderType>(
                  title: Text('Local On-Device Rule Engine'),
                  subtitle: Text('100% Offline & Private Fallback'),
                  value: AiProviderType.localRuleEngine,
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'ASSISTANT FEATURES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Smart Reply Suggestions'),
            subtitle: const Text(
              'Suggest quick response chips based on last message',
            ),
            value: _config.enableSmartReplies,
            onChanged: (val) {
              _updateConfig(
                AiConfig(
                  provider: _config.provider,
                  enableSmartReplies: val,
                  enableAutoSummarization: _config.enableAutoSummarization,
                  allowCloudE2eeProcessing: _config.allowCloudE2eeProcessing,
                ),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Auto-Summarization'),
            subtitle: const Text(
              'Generate quick chat summaries in group details',
            ),
            value: _config.enableAutoSummarization,
            onChanged: (val) {
              _updateConfig(
                AiConfig(
                  provider: _config.provider,
                  enableSmartReplies: _config.enableSmartReplies,
                  enableAutoSummarization: val,
                  allowCloudE2eeProcessing: _config.allowCloudE2eeProcessing,
                ),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'E2EE PRIVACY GUARD',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Allow Cloud Processing for E2EE Messages'),
            subtitle: const Text(
              'Default is OFF. When OFF, encrypted messages are strictly processed by local AI.',
            ),
            value: _config.allowCloudE2eeProcessing,
            onChanged: (val) {
              _updateConfig(
                AiConfig(
                  provider: _config.provider,
                  enableSmartReplies: _config.enableSmartReplies,
                  enableAutoSummarization: _config.enableAutoSummarization,
                  allowCloudE2eeProcessing: val,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
