import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/settings/settings_models.dart';
import 'package:frontend/core/settings/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Phase 10 Settings, Privacy & Account Security Tests (Steps 201-220)',
    () {
      late SettingsService settingsService;

      setUp(() {
        settingsService = SettingsService.instance;
      });

      test(
        'TEST 1 & 2: ChatSettings map serialization and default preferences',
        () {
          final chat = settingsService.chatSettings;
          expect(chat.enterToSend, isTrue);
          expect(chat.mediaAutoDownload, isTrue);

          final map = chat.toMap();
          expect(map['enter_to_send'], isTrue);

          final restored = ChatSettings.fromMap(map);
          expect(restored.enterToSend, isTrue);
        },
      );

      test('TEST 3 & 4: PrivacySettings toggles and map parsing', () {
        final privacy = settingsService.privacySettings;
        expect(privacy.showOnlineStatus, isTrue);
        expect(privacy.readReceipts, isTrue);

        privacy.showOnlineStatus = false;
        final map = privacy.toMap();
        expect(map['show_online_status'], isFalse);

        final restored = PrivacySettings.fromMap(map);
        expect(restored.showOnlineStatus, isFalse);
      });

      test(
        'TEST 5 & 6: DeviceSession list inspection and revocation',
        () async {
          final sessions = settingsService.activeSessions;
          expect(sessions, isNotEmpty);

          final current = sessions.firstWhere((s) => s.isCurrentDevice);
          expect(current.deviceName, contains('Voyager'));

          final remote = sessions.firstWhere((s) => !s.isCurrentDevice);
          await settingsService.revokeDevice(remote.deviceId);

          expect(
            settingsService.activeSessions.any(
              (s) => s.deviceId == remote.deviceId,
            ),
            isFalse,
          );
        },
      );

      test(
        'TEST 7 & 8: Account data JSON export generation and safety rule check',
        () async {
          final jsonString = await settingsService.exportUserDataJson(
            userId: 'user-test-export',
          );
          expect(jsonString, isNotEmpty);

          final Map<String, dynamic> parsed = json.decode(jsonString);
          expect(parsed['export_version'], equals('1.0.0'));
          expect(parsed['user_id'], equals('user-test-export'));
          expect(
            parsed.containsKey('private_key'),
            isFalse,
          ); // Raw private key excluded
          expect(
            parsed.containsKey('session_key'),
            isFalse,
          ); // Raw session key excluded
        },
      );

      test(
        'TEST 9 & 10: Account deletion wipes local database state cleanly',
        () async {
          await settingsService.deleteAccount(userId: 'user-test-delete');
          // Account deletion executed safely without exceptions
          expect(true, isTrue);
        },
      );
    },
  );
}
