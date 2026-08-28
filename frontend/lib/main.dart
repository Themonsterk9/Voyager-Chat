import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'core/auth/models/auth_user.dart';
import 'core/auth/services/auth_service.dart';
import 'core/auth/supabase_config.dart';
import 'core/media/media_models.dart';
import 'core/notifications/notification_manager.dart';
import 'core/security/e2ee_service.dart';
import 'core/theme/app_theme.dart';
import 'core/transport/transport_manager.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/calling/screens/call_history_screen.dart';
import 'features/calling/screens/video_call_screen.dart';
import 'features/calling/screens/voice_call_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/chat/screens/conversation_details_screen.dart';
import 'features/chat/services/connectivity_sync_service.dart';
import 'features/groups/screens/group_details_screen.dart';
import 'features/home/home_screen.dart';
import 'features/location/screens/map_screen.dart';
import 'features/media/screens/media_gallery_screen.dart';
import 'features/media/screens/media_viewer_screen.dart';
import 'features/meetings/screens/meeting_lobby_screen.dart';
import 'features/meetings/screens/meeting_room_screen.dart';
import 'features/search/screens/search_screen.dart';
import 'features/settings/screens/account_security_screen.dart';
import 'features/settings/screens/ai_settings_screen.dart';
import 'features/settings/screens/blocked_users_screen.dart';
import 'features/settings/screens/chat_settings_screen.dart';
import 'features/settings/screens/device_management_screen.dart';
import 'features/settings/screens/diagnostics_screen.dart';
import 'features/settings/screens/e2ee_screen.dart';
import 'features/settings/screens/enterprise_governance_screen.dart';
import 'features/settings/screens/nearby_screen.dart';
import 'features/settings/screens/notification_settings_screen.dart';
import 'features/settings/screens/operations_monitoring_screen.dart';
import 'features/settings/screens/privacy_settings_screen.dart';
import 'features/settings/screens/production_health_screen.dart';
import 'features/settings/screens/release_info_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/storage/screens/storage_backup_screen.dart';
import 'features/users/repositories/user_repository.dart';
import 'features/users/screens/create_group_screen.dart';
import 'features/users/screens/new_chat_screen.dart';
import 'features/users/screens/user_profile_screen.dart';
import 'features/welcome/welcome_screen.dart';

import 'features/onboarding/permission_onboarding_screen.dart';
import 'core/services/diagnostics_service.dart';
import 'features/diagnostics/startup_error_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Uncaught Flutter Error: ${details.exception}');
    DiagnosticsService.instance.recordStartupError(
      stage: 'flutter_runtime',
      error: details.exception,
      stack: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught Platform Error: $error');
    DiagnosticsService.instance.recordStartupError(
      stage: 'async_platform',
      error: error,
      stack: stack,
    );
    return true;
  };

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  } catch (e, stack) {
    debugPrint('Supabase Initialization Exception (non-fatal): $e');
    DiagnosticsService.instance.recordStartupError(
      stage: 'supabase_init',
      error: e,
      stack: stack,
    );
  }

  runApp(const VoyagerChatApp());
}

class VoyagerChatApp extends StatefulWidget {
  const VoyagerChatApp({super.key, this.testMode = false});

  final bool testMode;

  @override
  State<VoyagerChatApp> createState() => _VoyagerChatAppState();
}

class _VoyagerChatAppState extends State<VoyagerChatApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;
  _AuthRefreshNotifier? _authRefreshNotifier;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    try {
      E2eeService.instance.initialize(
        userId: 'local-user',
        deviceId: 'device-local-1',
      );
    } catch (e) {
      debugPrint('E2eeService initialization warning: $e');
    }

    try {
      NotificationManager.instance.initialize();
    } catch (e) {
      debugPrint('NotificationManager initialization warning: $e');
    }

    if (!widget.testMode) {
      try {
        UserRepository.instance.updatePresence('online');
      } catch (e) {
        debugPrint('UserRepository presence update warning: $e');
      }
    }

    try {
      TransportManager.instance.initialize(myDeviceId: 'device-local-1');
    } catch (e) {
      debugPrint('TransportManager initialization warning: $e');
    }

    try {
      ConnectivitySyncService.instance.start();
    } catch (e) {
      debugPrint('ConnectivitySyncService start warning: $e');
    }

    if (!widget.testMode) {
      _authRefreshNotifier = _AuthRefreshNotifier();
    }

    _router = GoRouter(
      initialLocation: widget.testMode ? '/welcome' : '/splash',
      refreshListenable: _authRefreshNotifier,
      redirect: widget.testMode
          ? null
          : (context, state) {
              final isAuthenticated = AuthService.instance.isAuthenticated;

              final isAuthRoute =
                  state.matchedLocation == '/login' ||
                  state.matchedLocation == '/register' ||
                  state.matchedLocation == '/otp';

              final isPublicRoute = state.matchedLocation == '/splash' ||
                  state.matchedLocation == '/welcome' ||
                  isAuthRoute;

              if (isAuthenticated && isPublicRoute) {
                return '/home';
              }

              if (!isAuthenticated && !isPublicRoute && state.matchedLocation != '/permission-onboarding') {
                return '/login';
              }

              return null;
            },
      routes: [
        GoRoute(
          path: '/permission-onboarding',
          builder: (context, state) => const PermissionOnboardingScreen(),
        ),
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/chat/:conversationId',
          builder: (context, state) {
            final conversationId = state.pathParameters['conversationId']!;
            return ChatScreen(conversationId: conversationId);
          },
        ),
        GoRoute(
          path: '/chat-details/:conversationId',
          builder: (context, state) {
            final conversationId = state.pathParameters['conversationId']!;
            return ConversationDetailsScreen(conversationId: conversationId);
          },
        ),
        GoRoute(
          path: '/group-details/:conversationId',
          builder: (context, state) {
            final conversationId = state.pathParameters['conversationId']!;
            return GroupDetailsScreen(conversationId: conversationId);
          },
        ),
        GoRoute(
          path: '/meeting/lobby/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return MeetingLobbyScreen(meetingId: id);
          },
        ),
        GoRoute(
          path: '/meeting/room/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return MeetingRoomScreen(meetingId: id);
          },
        ),
        GoRoute(
          path: '/media/gallery/:conversationId',
          builder: (context, state) {
            final conversationId = state.pathParameters['conversationId']!;
            return MediaGalleryScreen(conversationId: conversationId);
          },
        ),
        GoRoute(
          path: '/media/view',
          builder: (context, state) {
            final attachment =
                state.extra as MediaAttachment? ??
                const MediaAttachment(
                  id: 'demo',
                  messageId: 'demo',
                  fileName: 'attachment.png',
                  fileSize: 1024,
                  mimeType: 'image/png',
                );
            return MediaViewerScreen(attachment: attachment);
          },
        ),
        GoRoute(
          path: '/profile/:userId',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return UserProfileScreen(userId: userId);
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => SettingsScreen(
            currentThemeMode: _themeMode,
            onThemeModeChanged: (mode) {
              setState(() {
                _themeMode = mode;
              });
            },
          ),
        ),
        GoRoute(
          path: '/settings/ai-preferences',
          builder: (context, state) => const AiSettingsScreen(),
        ),
        GoRoute(
          path: '/settings/production-health',
          builder: (context, state) => const ProductionHealthScreen(),
        ),
        GoRoute(
          path: '/settings/release-info',
          builder: (context, state) => const ReleaseInfoScreen(),
        ),
        GoRoute(
          path: '/settings/enterprise-governance',
          builder: (context, state) => const EnterpriseGovernanceScreen(),
        ),
        GoRoute(
          path: '/settings/operations-monitoring',
          builder: (context, state) => const OperationsMonitoringScreen(),
        ),
        GoRoute(
          path: '/settings/blocked-users',
          builder: (context, state) => const BlockedUsersScreen(),
        ),
        GoRoute(
          path: '/settings/diagnostics',
          builder: (context, state) => const DiagnosticsScreen(),
        ),
        GoRoute(
          path: '/startup-error',
          builder: (context, state) => const StartupErrorScreen(),
        ),
        GoRoute(
          path: '/settings/nearby',
          builder: (context, state) => const NearbyScreen(),
        ),
        GoRoute(
          path: '/settings/e2ee',
          builder: (context, state) => const E2eeScreen(),
        ),
        GoRoute(
          path: '/settings/map',
          builder: (context, state) => const MapScreen(),
        ),
        GoRoute(
          path: '/settings/notifications',
          builder: (context, state) => const NotificationSettingsScreen(),
        ),
        GoRoute(
          path: '/settings/call-history',
          builder: (context, state) => const CallHistoryScreen(),
        ),
        GoRoute(
          path: '/settings/privacy',
          builder: (context, state) => const PrivacySettingsScreen(),
        ),
        GoRoute(
          path: '/settings/chat-preferences',
          builder: (context, state) => const ChatSettingsScreen(),
        ),
        GoRoute(
          path: '/settings/devices',
          builder: (context, state) => const DeviceManagementScreen(),
        ),
        GoRoute(
          path: '/settings/security',
          builder: (context, state) => const AccountSecurityScreen(),
        ),
        GoRoute(
          path: '/settings/storage-backup',
          builder: (context, state) => const StorageBackupScreen(),
        ),
        GoRoute(
          path: '/call/voice',
          builder: (context, state) {
            final name =
                (state.extra as Map<String, dynamic>?)?['recipientName']
                    as String? ??
                'Contact';
            return VoiceCallScreen(recipientName: name);
          },
        ),
        GoRoute(
          path: '/call/video',
          builder: (context, state) {
            final name =
                (state.extra as Map<String, dynamic>?)?['recipientName']
                    as String? ??
                'Contact';
            return VideoCallScreen(recipientName: name);
          },
        ),
        GoRoute(
          path: '/new-chat',
          builder: (context, state) => const NewChatScreen(),
        ),
        GoRoute(
          path: '/create-group',
          builder: (context, state) => const CreateGroupScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/otp',
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            final purpose = state.uri.queryParameters['purpose'] ?? 'LOGIN';
            final newPassword = state.uri.queryParameters['newPassword'];
            final displayName = state.uri.queryParameters['displayName'];
            return OtpScreen(
              email: email,
              purpose: purpose,
              newPassword: newPassword,
              displayName: displayName,
            );
          },
        ),
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.testMode) return;

    if (state == AppLifecycleState.resumed) {
      UserRepository.instance.updatePresence('online');
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      UserRepository.instance.updatePresence('offline');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!widget.testMode) {
      UserRepository.instance.updatePresence('offline');
    }
    ConnectivitySyncService.instance.stop();
    TransportManager.instance.dispose();
    NotificationManager.instance.dispose();

    _authRefreshNotifier?.dispose();
    _router.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Voyager Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    _subscription = AuthService.instance.authStateChanges.listen((user) {
      if (user != null) {
        UserRepository.instance.updatePresence('online');
      } else {
        UserRepository.instance.updatePresence('offline');
      }
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthUser?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
