import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_settings.dart';
import '../services/app_localizations.dart';
import '../widgets/google_sign_in_button.dart';
import '../main.dart';
import 'tag_manager_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final settings = AppSettings.instance;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final primaryColor = settings.primaryColor;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        context.l10n('system_settings_title'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n('system_settings_subtitle'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Cloud Sync Banner
                  _buildCloudSyncBanner(context, isDark, primaryColor),
                  const SizedBox(height: 24),

                  // Section 1: Appearance & Theme
                  _buildSectionHeader(context, Icons.palette_outlined, context.l10n('appearance_theme'), primaryColor),
                  const SizedBox(height: 12),
                  _buildCardContainer(
                    context,
                    isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Theme Mode Selector
                        Text(
                          context.l10n('theme_mode'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildThemeModeCard(
                                context,
                                mode: ThemeMode.dark,
                                title: context.l10n('theme_dark'),
                                icon: Icons.dark_mode_outlined,
                                isSelected: settings.themeMode == ThemeMode.dark,
                                isDark: isDark,
                                primaryColor: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildThemeModeCard(
                                context,
                                mode: ThemeMode.light,
                                title: context.l10n('theme_light'),
                                icon: Icons.light_mode_outlined,
                                isSelected: settings.themeMode == ThemeMode.light,
                                isDark: isDark,
                                primaryColor: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildThemeModeCard(
                                context,
                                mode: ThemeMode.system,
                                title: context.l10n('theme_system'),
                                icon: Icons.brightness_auto_outlined,
                                isSelected: settings.themeMode == ThemeMode.system,
                                isDark: isDark,
                                primaryColor: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 24),

                        // Accent Color Selector
                        Text(
                          context.l10n('accent_color'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: AppThemeColors.palette.map((item) {
                            final String name = item['name'];
                            final Color color = item['color'];
                            final bool isSelected = settings.primaryColor.value == color.value;

                            String displayName = name;
                            if (name == '商務青藍') {
                              displayName = context.l10n('accent_teal');
                            } else if (name == '皇家寶藍') {
                              displayName = context.l10n('accent_blue');
                            } else if (name == '翡翠鮮綠') {
                              displayName = context.l10n('accent_green');
                            } else if (name == '高雅奢紫') {
                              displayName = context.l10n('accent_purple');
                            } else if (name == '暖陽琥珀') {
                              displayName = context.l10n('accent_amber');
                            }

                            return InkWell(
                              onTap: () => settings.setPrimaryColor(color),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color.withOpacity(0.15)
                                      : (isDark ? const Color(0xFF21262D) : Colors.grey.shade100),
                                  border: Border.all(
                                    color: isSelected ? color : Colors.transparent,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: color.withOpacity(0.6),
                                                  blurRadius: 6,
                                                  spreadRadius: 1,
                                                )
                                              ]
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      displayName,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 2: View Preferences
                  _buildSectionHeader(context, Icons.dashboard_customize_outlined, context.l10n('operation_preferences'), primaryColor),
                  const SizedBox(height: 12),
                  _buildCardContainer(
                    context,
                    isDark,
                    child: Column(
                      children: [
                        // Default Customer View Mode
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.style_outlined, color: primaryColor, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.l10n('customer_view_mode'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(context.l10n('customer_view_mode_desc'), style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 260,
                              child: SegmentedButton<String>(
                                segments: [
                                  ButtonSegment(
                                    value: 'card',
                                    label: Text(context.l10n('view_3d_card')),
                                    icon: const Icon(Icons.view_carousel_outlined, size: 16),
                                  ),
                                  ButtonSegment(
                                    value: 'list',
                                    label: Text(context.l10n('view_list_view')),
                                    icon: const Icon(Icons.table_rows_outlined, size: 16),
                                  ),
                                ],
                                selected: {settings.defaultCustomerViewMode},
                                onSelectionChanged: (Set<String> newSelection) {
                                  settings.setDefaultCustomerViewMode(newSelection.first);
                                },
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Sidebar Collapsed Preference
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.view_sidebar_outlined, color: primaryColor, size: 20),
                          ),
                          title: Text(context.l10n('auto_collapse_sidebar'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: Text(context.l10n('auto_collapse_sidebar_desc'), style: const TextStyle(fontSize: 12)),
                          value: settings.isSidebarCollapsedByDefault,
                          activeColor: primaryColor,
                          onChanged: (bool value) {
                            settings.setSidebarCollapsedByDefault(value);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 2.5: Tag & Folder Management
                  _buildSectionHeader(context, Icons.local_offer_outlined, '🏷️ 標籤字典與資料夾管理', primaryColor),
                  const SizedBox(height: 12),
                  _buildCardContainer(
                    context,
                    isDark,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.folder_special_outlined, color: primaryColor, size: 20),
                      ),
                      title: const Text('標籤與資料夾管理器', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('管理 5 大資料夾分類、標籤手動新增/編輯與一鍵合併功能', style: TextStyle(fontSize: 12)),
                      trailing: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TagManagerScreen()),
                          );
                        },
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text('開啟管理'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 3: Language & Localization (Phase 6 i18n Prep)
                  _buildSectionHeader(context, Icons.language_outlined, context.l10n('language_title'), primaryColor),
                  const SizedBox(height: 12),
                  _buildCardContainer(
                    context,
                    isDark,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.translate_outlined, color: primaryColor, size: 20),
                      ),
                      title: Text(context.l10n('pref_language'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: Text(context.l10n('pref_language_desc'), style: const TextStyle(fontSize: 12)),
                      trailing: DropdownButton<String>(
                        value: settings.language,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                            value: 'zh_TW',
                            child: Row(
                              children: [
                                Text('🇹🇼 繁體中文'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'en_US',
                            child: Row(
                              children: [
                                Text('🇺🇸 English'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            settings.setLanguage(value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 3.5: Third-Party Account & Service Connection
                  _buildSectionHeader(context, Icons.account_tree_outlined, '🔗 第三方帳號與服務連線管理', primaryColor),
                  const SizedBox(height: 12),
                  _buildCardContainer(
                    context,
                    isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA4335).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const GoogleGLogoIcon(size: 22),
                          ),
                          title: const Text('Google 帳號連線與授權', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: const Text('用於雙向同步 Google 行事曆拜訪行程與 Google Drive 雲端備份', style: TextStyle(fontSize: 12)),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isOfflineMode ? Colors.grey : primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: isOfflineMode
                                ? null
                                : () async {
                                    try {
                                      final supabase = Supabase.instance.client;
                                      String? redirectTo;
                                      if (kIsWeb) {
                                        final origin = Uri.base.origin;
                                        redirectTo = (origin.contains('localhost') && !origin.contains(':8080'))
                                            ? 'http://localhost:8080'
                                            : origin;
                                      } else {
                                        redirectTo = 'http://localhost:8080';
                                      }
                                      await supabase.auth.signInWithOAuth(
                                        OAuthProvider.google,
                                        redirectTo: redirectTo,
                                        queryParams: {
                                          'prompt': 'select_account',
                                        },
                                      );
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('連線發起失敗: $e'), backgroundColor: Colors.redAccent),
                                        );
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.link, size: 16),
                            label: Text(Supabase.instance.client.auth.currentUser?.appMetadata['provider'] == 'google' ? '已連線' : '重新連結 / 授權'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Reset Defaults Button
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmResetDialog(context, settings, primaryColor),
                      icon: const Icon(Icons.restart_alt_outlined, color: Colors.redAccent, size: 18),
                      label: Text(context.l10n('reset_defaults'), style: const TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Cloud Sync Banner
  Widget _buildCloudSyncBanner(BuildContext context, bool isDark, Color primaryColor) {
    final bool isOffline = isOfflineMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOffline
            ? Colors.amber.shade900.withOpacity(0.15)
            : primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOffline ? Colors.amber.shade700 : primaryColor.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOffline ? Icons.offline_pin_outlined : Icons.cloud_done_outlined,
            color: isOffline ? Colors.amber : primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOffline ? context.l10n('cloud_sync_offline') : context.l10n('cloud_sync_synced'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isOffline ? Colors.amber : primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOffline
                      ? context.l10n('cloud_sync_offline_desc')
                      : context.l10n('cloud_sync_synced_desc'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Section Header Helper
  Widget _buildSectionHeader(BuildContext context, IconData icon, String title, Color primaryColor) {
    return Row(
      children: [
        Icon(icon, size: 20, color: primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Card Container Helper
  Widget _buildCardContainer(BuildContext context, bool isDark, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF21262D) : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  // Theme Mode Card Item
  Widget _buildThemeModeCard(
    BuildContext context, {
    required ThemeMode mode,
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required Color primaryColor,
  }) {
    return InkWell(
      onTap: () => AppSettings.instance.setThemeMode(mode),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.12)
              : (isDark ? const Color(0xFF21262D) : Colors.grey.shade100),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : (isDark ? Colors.white54 : Colors.black54),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primaryColor : (isDark ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reset Confirmation Dialog
  void _confirmResetDialog(BuildContext context, AppSettings settings, Color primaryColor) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber),
              const SizedBox(width: 8),
              Text(context.l10n('reset_dialog_title')),
            ],
          ),
          content: Text(context.l10n('reset_dialog_content')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await settings.resetToDefaults();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n('reset_success'))),
                  );
                }
              },
              child: Text(context.l10n('confirm')),
            ),
          ],
        );
      },
    );
  }
}
