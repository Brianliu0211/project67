// Force Vercel rebuild - 2026-07-15 17:38
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/pending_approval_screen.dart';
import 'screens/reset_password_screen.dart';
import 'services/app_settings.dart';
import 'services/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

// Global flag to track if we are in offline preview mode
bool isOfflineMode = false;
String offlineReason = '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_TW', null);
  await initializeDateFormatting('en_US', null);
  
  // Load AppSettings
  await AppSettings.instance.loadSettings();

  // Try loading dotenv
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // If dotenv.load fails, it might still have environment defines
  }

  // Dual-track fallback: check dotenv first, then const String.fromEnvironment, then project defaults
  String? supabaseUrl = dotenv.maybeGet('SUPABASE_URL');
  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  }
  if (supabaseUrl.isEmpty) {
    supabaseUrl = 'https://algufuoxkeizxwkofmmp.supabase.co';
  }

  String? supabaseKey = dotenv.maybeGet('SUPABASE_ANON_KEY');
  if (supabaseKey == null || supabaseKey.isEmpty) {
    supabaseKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
  }
  if (supabaseKey.isEmpty) {
    supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFsZ3VmdW94a2Vpenh3a29mbW1wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0OTU2NzgsImV4cCI6MjA5OTA3MTY3OH0.QMEU47EHuLwEr7ok7O28h6U7Sh-geldoTQ5eZfI5tBA';
  }

  // If placeholders or empty values are detected, fall back to offline preview
  if (supabaseUrl.isEmpty || 
      supabaseKey.isEmpty || 
      supabaseUrl.contains('your-project-id')) {
    isOfflineMode = true;
    offlineReason = '未檢測到有效的 Supabase URL 或 ANON KEY';
  } else {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
      isOfflineMode = false;
    } catch (e) {
      isOfflineMode = true;
      offlineReason = 'Supabase 初始化連線失敗: $e';
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, child) {
        final primaryColor = AppSettings.instance.primaryColor;

        // Dark Theme
        final darkTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          primaryColor: primaryColor,
          scaffoldBackgroundColor: const Color(0xFF0D1117),
          colorScheme: ColorScheme.dark(
            primary: primaryColor,
            secondary: primaryColor.withOpacity(0.8),
            surface: const Color(0xFF161B22),
            background: const Color(0xFF0D1117),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF161B22),
            elevation: 0,
          ),
          cardTheme: const CardThemeData(
            color: Color(0xFF161B22),
            elevation: 2,
          ),
        );

        // Light Theme
        final lightTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          primaryColor: primaryColor,
          scaffoldBackgroundColor: const Color(0xFFF6F8FA),
          colorScheme: ColorScheme.light(
            primary: primaryColor,
            secondary: primaryColor.withOpacity(0.8),
            surface: Colors.white,
            background: const Color(0xFFF6F8FA),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 1,
            iconTheme: IconThemeData(color: primaryColor),
            titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          cardTheme: const CardThemeData(
            color: Colors.white,
            elevation: 2,
          ),
        );

        return MaterialApp(
          title: '保險客戶管理助手',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: AppSettings.instance.themeMode,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'TW'),
            Locale('en', 'US'),
          ],
          locale: AppSettings.instance.language == 'zh_TW'
              ? const Locale('zh', 'TW')
              : const Locale('en', 'US'),
          localeResolutionCallback: (locale, supportedLocales) {
            return AppSettings.instance.language == 'zh_TW'
                ? const Locale('zh', 'TW')
                : const Locale('en', 'US');
          },
          home: const AuthGateway(),
        );
      },
    );
  }
}

class AuthGateway extends StatefulWidget {
  const AuthGateway({super.key});

  @override
  State<AuthGateway> createState() => _AuthGatewayState();
}

class _AuthGatewayState extends State<AuthGateway> {
  bool _isPasswordRecovery = false;

  @override
  Widget build(BuildContext context) {
    if (isOfflineMode) {
      // In offline mode, route directly to LoginScreen which shows the skip button
      return const LoginScreen();
    }

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00ADB5),
              ),
            ),
          );
        }

        final event = snapshot.data?.event;
        if (event == AuthChangeEvent.passwordRecovery) {
          _isPasswordRecovery = true;
        }

        // Full-screen dedicated reset password screen (Isolated & Non-bypassable)
        if (_isPasswordRecovery) {
          return ResetPasswordScreen(
            onCompleted: () {
              if (mounted) {
                setState(() {
                  _isPasswordRecovery = false;
                });
              }
            },
          );
        }

        final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
        if (session != null) {
          // Check profile status from Supabase to enforce pending approval gate
          return FutureBuilder<Map<String, dynamic>?>(
            future: Supabase.instance.client
                .from('profiles')
                .select('status, role')
                .eq('id', session.user.id)
                .maybeSingle(),
            builder: (context, profileSnap) {
              if (profileSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFF00ADB5)),
                  ),
                );
              }
              final profileData = profileSnap.data;
              final status = profileData?['status'] as String? ?? 'active';
              final role = profileData?['role'] as String? ?? 'agent';

              // If status is pending and user is not dev, block access and route to PendingApprovalScreen
              if (status == 'pending' && role != 'dev') {
                return PendingApprovalScreen(
                  userEmail: session.user.email ?? '',
                  onRefreshStatus: () {
                    if (mounted) setState(() {});
                  },
                );
              }
              return const HomeScreen();
            },
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class OfflineDataStore {
  static List<Map<String, dynamic>> customers = [];
  static List<Map<String, dynamic>> customerRelationships = [];
}

