import 'package:flutter/material.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/supabase_config.dart';
import 'pages/auth_page.dart';
import 'pages/main_navigation.dart';
import 'pages/reset_password_page.dart';
import 'services/widget_service.dart';
import 'services/notification_service.dart';
import 'providers/connectivity_provider.dart';
import 'providers/ble_provider.dart';
import 'providers/locale_provider.dart';
import 'services/sync_service.dart';
import 'services/user_verification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Initialize widget service
  final widgetService = WidgetService();
  await widgetService.initialize();

  // Initialize notification service (non-blocking, handles errors internally)
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
  } catch (e) {
    debugPrint('Failed to initialize notification service: $e');
    // Continue app startup even if notifications fail
  }

  runApp(const ProviderScope(child: TicketMania()));
}

final supabase = Supabase.instance.client;

class TicketMania extends ConsumerStatefulWidget {
  const TicketMania({super.key});

  @override
  ConsumerState<TicketMania> createState() => _TicketManiaState();
}

class _TicketManiaState extends ConsumerState<TicketMania> {
  final UserVerificationService _userVerificationService =
      UserVerificationService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Initialize sync service and verify user when online
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSync();
      _verifyUserOnStartup();
      _handleInitialDeepLink();
    });

    // Listen for deep links when app is running
    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        // Handle password recovery deep link
        _handlePasswordRecovery();
      }
    });
  }

  /// Handle initial deep link when app is opened from email
  /// Supabase automatically handles deep links through onAuthStateChange
  Future<void> _handleInitialDeepLink() async {
    // Supabase Flutter SDK automatically handles deep links
    // The onAuthStateChange listener will catch password recovery events
    // This method is called on app startup to check for any pending recovery sessions
  }

  /// Handle password recovery from auth state change
  void _handlePasswordRecovery() {
    if (_navigatorKey.currentContext != null) {
      // Navigate to reset password page
      // Use pushReplacement to replace the current route
      Navigator.of(_navigatorKey.currentContext!).pushReplacement(
        MaterialPageRoute(builder: (context) => const ResetPasswordPage()),
      );
    }
  }

  void _setupSync() {
    final isOnline = ref.read(isOnlineProvider);
    if (isOnline) {
      final syncService = ref.read(syncServiceProvider);
      syncService.syncQueuedOperations().catchError((e) {
        debugPrint('Error syncing queued operations: $e');
      });
    }
  }

  /// Verify user exists in database on app startup
  Future<void> _verifyUserOnStartup() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final isOnline = ref.read(isOnlineProvider);
    if (isOnline) {
      // Only verify when online
      final exists = await _userVerificationService.verifyAndLogoutIfNeeded();
      if (!exists) {
        debugPrint('User was logged out due to account deletion');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeService = ref.watch(localeServiceProvider);

    // Listen to connectivity changes and verify user when coming online
    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (next == true && (previous == false || previous == null)) {
        // Just came online, verify user
        final user = supabase.auth.currentUser;
        if (user != null) {
          _userVerificationService.verifyAndLogoutIfNeeded().then((exists) {
            if (!exists) {
              debugPrint(
                'User was logged out after coming online - account deleted',
              );
            }
          });
        }
      }
    });

    return MaterialApp(
      navigatorKey: _navigatorKey,
      key: ValueKey('locale_${localeService.locale.languageCode}'),
      title: 'Ticket Mania',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BF63),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      locale: localeService.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StreamBuilder<AuthState>(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final session = snapshot.data?.session;
            if (session != null) {
              // Initialize BLE service when user is authenticated
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _initializeBLEService();
              });
              return const MainNavigation();
            }
            // Check if onboarding is completed
            return FutureBuilder<bool>(
              future: _checkOnboardingStatus(),
              builder: (context, onboardingSnapshot) {
                if (onboardingSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return const AuthPage();
              },
            );
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }

  void _initializeBLEService() {
    final bleService = ref.read(bleServiceProvider);
    bleService.initialize().then((initialized) async {
      if (initialized) {
        // Only start advertising if auto-validation is enabled in preferences
        final isAutoValidationEnabled = await bleService
            .isAutoValidationEnabled();
        if (isAutoValidationEnabled) {
          bleService.startAdvertising();
        } else {
          debugPrint('Auto-validation is disabled, skipping BLE advertising');
        }
      }
    });
  }

  Future<bool> _checkOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('onboarding_completed') ?? false;
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
      return false;
    }
  }
}
