// Force Vercel rebuild - 2026-07-15 17:38
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/app_settings.dart';

// Global flag to track if we are in offline preview mode
bool isOfflineMode = false;
String offlineReason = '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load AppSettings
  await AppSettings.instance.loadSettings();

  // Try loading dotenv
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    isOfflineMode = true;
    offlineReason = '找不到 .env 檔案';
  }

  if (!isOfflineMode) {
    final supabaseUrl = dotenv.maybeGet('SUPABASE_URL');
    final supabaseKey = dotenv.maybeGet('SUPABASE_ANON_KEY');

    // If placeholders or empty values are detected, fall back to offline preview
    if (supabaseUrl == null || 
        supabaseKey == null || 
        supabaseUrl.isEmpty ||
        supabaseKey.isEmpty ||
        supabaseUrl.contains('your-project-id')) {
      isOfflineMode = true;
      offlineReason = '檢測到預設金鑰占位字串';
    } else {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
        );
      } catch (e) {
        isOfflineMode = true;
        offlineReason = 'Supabase 初始化連線失敗';
      }
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
          home: const AuthGateway(),
        );
      },
    );
  }
}

class AuthGateway extends StatelessWidget {
  const AuthGateway({super.key});

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

        final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
