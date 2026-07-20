import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

/// Available primary theme colors for personalization
class AppThemeColors {
  static const Color tealCyan = Color(0xFF00ADB5);
  static const Color royalBlue = Color(0xFF2563EB);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color royalPurple = Color(0xFF8B5CF6);
  static const Color amberGold = Color(0xFFF59E0B);

  static const List<Map<String, dynamic>> palette = [
    {'name': '商務青藍', 'color': tealCyan},
    {'name': '皇家寶藍', 'color': royalBlue},
    {'name': '翡翠鮮綠', 'color': emeraldGreen},
    {'name': '高雅奢紫', 'color': royalPurple},
    {'name': '暖陽琥珀', 'color': amberGold},
  ];
}

class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._internal();
  AppSettings._internal();

  // Settings State
  ThemeMode _themeMode = ThemeMode.dark;
  Color _primaryColor = AppThemeColors.tealCyan;
  String _defaultCustomerViewMode = 'card'; // 'card' or 'list'
  bool _isSidebarCollapsedByDefault = false;
  String _language = 'zh_TW';

  // Getters
  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
  String get defaultCustomerViewMode => _defaultCustomerViewMode;
  bool get isSidebarCollapsedByDefault => _isSidebarCollapsedByDefault;
  String get language => _language;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Load settings from SharedPreferences and optionally sync with Supabase Cloud
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Theme Mode
      final themeStr = prefs.getString('prefs_theme_mode') ?? 'dark';
      if (themeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else if (themeStr == 'system') {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.dark;
      }

      // Load Primary Color
      final colorInt = prefs.getInt('prefs_primary_color');
      if (colorInt != null) {
        _primaryColor = Color(colorInt);
      }

      // Load Customer View Mode
      _defaultCustomerViewMode = prefs.getString('prefs_customer_view_mode') ?? 'card';

      // Load Sidebar Preference
      _isSidebarCollapsedByDefault = prefs.getBool('prefs_sidebar_collapsed') ?? false;

      // Load Language
      _language = prefs.getString('prefs_language') ?? 'zh_TW';

      _isInitialized = true;
      notifyListeners();

      // Async sync with Supabase User Metadata if user is logged in
      _syncWithCloudOnStartup();
    } catch (e) {
      debugPrint('Error loading settings from SharedPreferences: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Sync settings with Supabase Cloud User Metadata
  Future<void> _syncWithCloudOnStartup() async {
    if (isOfflineMode) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.userMetadata != null && user.userMetadata!['app_settings'] != null) {
        final Map<String, dynamic> cloudData = Map<String, dynamic>.from(user.userMetadata!['app_settings']);
        
        bool hasChanges = false;

        if (cloudData.containsKey('theme_mode')) {
          final cloudTheme = cloudData['theme_mode'];
          final newTheme = cloudTheme == 'light'
              ? ThemeMode.light
              : cloudTheme == 'system'
                  ? ThemeMode.system
                  : ThemeMode.dark;
          if (_themeMode != newTheme) {
            _themeMode = newTheme;
            hasChanges = true;
          }
        }

        if (cloudData.containsKey('primary_color_value')) {
          final colorValue = cloudData['primary_color_value'] as int;
          if (_primaryColor.value != colorValue) {
            _primaryColor = Color(colorValue);
            hasChanges = true;
          }
        }

        if (cloudData.containsKey('customer_view_mode')) {
          final viewMode = cloudData['customer_view_mode'] as String;
          if (_defaultCustomerViewMode != viewMode) {
            _defaultCustomerViewMode = viewMode;
            hasChanges = true;
          }
        }

        if (cloudData.containsKey('sidebar_collapsed')) {
          final sidebarCol = cloudData['sidebar_collapsed'] as bool;
          if (_isSidebarCollapsedByDefault != sidebarCol) {
            _isSidebarCollapsedByDefault = sidebarCol;
            hasChanges = true;
          }
        }

        if (cloudData.containsKey('language')) {
          final lang = cloudData['language'] as String;
          if (_language != lang) {
            _language = lang;
            hasChanges = true;
          }
        }

        if (hasChanges) {
          await _saveToLocalPrefs();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Cloud sync on startup failed: $e');
    }
  }

  /// Update Theme Mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _saveAndSync();
  }

  /// Update Primary Accent Color
  Future<void> setPrimaryColor(Color color) async {
    if (_primaryColor.value == color.value) return;
    _primaryColor = color;
    notifyListeners();
    await _saveAndSync();
  }

  /// Update Customer View Mode Preference
  Future<void> setDefaultCustomerViewMode(String mode) async {
    if (_defaultCustomerViewMode == mode) return;
    _defaultCustomerViewMode = mode;
    notifyListeners();
    await _saveAndSync();
  }

  /// Update Sidebar Collapsed Preference
  Future<void> setSidebarCollapsedByDefault(bool collapsed) async {
    if (_isSidebarCollapsedByDefault == collapsed) return;
    _isSidebarCollapsedByDefault = collapsed;
    notifyListeners();
    await _saveAndSync();
  }

  /// Update Language
  Future<void> setLanguage(String lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    await _saveAndSync();
  }

  /// Reset to factory default settings
  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.dark;
    _primaryColor = AppThemeColors.tealCyan;
    _defaultCustomerViewMode = 'card';
    _isSidebarCollapsedByDefault = false;
    _language = 'zh_TW';
    notifyListeners();
    await _saveAndSync();
  }

  /// Save settings to SharedPreferences
  Future<void> _saveToLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('prefs_theme_mode', _themeMode.name);
      await prefs.setInt('prefs_primary_color', _primaryColor.value);
      await prefs.setString('prefs_customer_view_mode', _defaultCustomerViewMode);
      await prefs.setBool('prefs_sidebar_collapsed', _isSidebarCollapsedByDefault);
      await prefs.setString('prefs_language', _language);
    } catch (e) {
      debugPrint('Error saving settings to SharedPreferences: $e');
    }
  }

  /// Save to local prefs AND sync with Supabase User Metadata
  Future<void> _saveAndSync() async {
    await _saveToLocalPrefs();

    if (isOfflineMode) return;

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        final settingsJson = {
          'theme_mode': _themeMode.name,
          'primary_color_value': _primaryColor.value,
          'customer_view_mode': _defaultCustomerViewMode,
          'sidebar_collapsed': _isSidebarCollapsedByDefault,
          'language': _language,
          'updated_at': DateTime.now().toIso8601String(),
        };

        await supabase.auth.updateUser(
          UserAttributes(
            data: {
              ...?user.userMetadata,
              'app_settings': settingsJson,
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Error syncing settings to Supabase: $e');
    }
  }
}
