import 'package:flutter/material.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'config/supabase_config.dart';
import 'pages/auth_page.dart';
import 'pages/main_navigation.dart';
import 'services/booking_service.dart';
import 'services/wallet_service.dart';
import 'services/widget_service.dart';
import 'services/ble_service.dart';
import 'services/locale_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Initialize widget service
  final widgetService = WidgetService();
  await widgetService.initialize();

  runApp(const TicketMania());
}

final supabase = Supabase.instance.client;

class TicketMania extends StatefulWidget {
  const TicketMania({super.key});

  @override
  State<TicketMania> createState() => _TicketManiaState();
}

class _TicketManiaState extends State<TicketMania> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => BookingService()),
        Provider(create: (_) => WalletService()),
        ChangeNotifierProvider(create: (_) => BLEService()),
        ChangeNotifierProvider(create: (_) => LocaleService()),
      ],
      child: Consumer<LocaleService>(
        builder: (context, localeService, _) {
          return MaterialApp(
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
                      _initializeBLEService(context);
                    });
                    return const MainNavigation();
                  }
                  return const AuthPage();
                }
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _initializeBLEService(BuildContext context) {
    final bleService = Provider.of<BLEService>(context, listen: false);
    bleService.initialize().then((initialized) {
      if (initialized) {
        bleService.startAdvertising();
      }
    });
  }
}
