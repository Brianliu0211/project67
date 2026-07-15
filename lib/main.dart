// Force Vercel rebuild - 2026-07-15
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

// Global flag to track if we are in offline preview mode
bool isOfflineMode = false;
String offlineReason = '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
    // High-end dark theme configuration with business teal tone
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF00ADB5), // Teal / Blue-green
      scaffoldBackgroundColor: const Color(0xFF0D1117), // Deep Dark Slate Blue
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00ADB5),
        secondary: Color(0xFF00F5FF), // Ice Blue
        surface: Color(0xFF161B22), // Card grey-blue
        background: Color(0xFF0D1117),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF161B22),
        elevation: 0,
      ),
      cardTheme: const CardTheme(
        color: Color(0xFF161B22),
        elevation: 2,
      ),
    );

    return MaterialApp(
      title: '保險客戶管理助手',
      debugShowCheckedModeBanner: false,
      theme: darkTheme,
      home: const AuthGateway(),
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

    // In online mode, check Supabase Auth session
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        return const HomeScreen();
      } else {
        return const LoginScreen();
      }
    } catch (_) {
      // Fallback in case of Auth error
      return const LoginScreen();
    }
  }
}
