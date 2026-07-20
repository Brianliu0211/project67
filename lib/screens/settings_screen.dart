import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import '../main.dart';

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
                      const Text(
                        '系統個性化與偏好設定',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '自訂專屬您的工作介面風格、視圖習慣與跨裝置備份機制',
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
                  _buildSectionHeader(context, Icons.palette_outlined, '外觀與風格主題', primaryColor),
                  const SizedBox(height: 12),
                  _buildCardContainer(
                    context,
                    isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Theme Mode Selector
                        const Text(
                          '色彩模式 (Theme Mode)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildThemeModeCard(
                                context,
                                mode: ThemeMode.dark,
                                title: '深色模式',
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
                                title: '淺色模式',
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
                                title: '跟隨系統',
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
                        const Text(
                          '系統強調色 (Accent Color)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: AppThemeColors.palette.map((item) {
                            final String name = item['name'];
                            final Color color = item['color'];
                            final bool isSelected = settings.primaryColor.value == color.value;

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
                                      name,
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
                  _buildSectionHeader(context, Icons.dashboard_customize_outlined, '操作與檢視偏好', primaryColor),
                  const SizedBox(height: 12),
                  _buildCardContainer(
                    context,
                    isDark,
                    child: Column(
                      children: [
                        // Default Customer View Mode
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.style_outlined, color: primaryColor, size: 20),
                          ),
                          title: const Text('客戶卡片預設檢視模式', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: const Text('設定進入客戶管理頁面時的預設展現方式', style: TextStyle(fontSize: 12)),
                          trailing: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'card',
                                label: Text('3D名片'),
                                icon: Icon(Icons.view_carousel_outlined, size: 16),
                              ),
                              ButtonSegment(
                                value: 'list',
                                label: Text('條列清單'),
                                icon: Icon(Icons.table_rows_outlined, size: 16),
                              ),
                            ],
                            selected: {settings.defaultCustomerViewMode},
                            onSelectionChanged: (Set<String> newSelection) {
                              settings.setDefaultCustomerViewMode(newSelection.first);
                            },
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
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
                          title: const Text('預設自動折疊側邊欄', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: const Text('啟動或載入系統時，自動保持側邊導覽列為精簡圖示模式', style: TextStyle(fontSize: 12)),
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

                  // Section 3: Language & Localization (Phase 6 i18n Prep)
                  _buildSectionHeader(context, Icons.language_outlined, '多國語系 (Language)', primaryColor),
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
                      title: const Text('顯示語言 Preference Language', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('切換專案介面顯示之語言語系 (對齊 Phase 6 i18n)', style: TextStyle(fontSize: 12)),
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
                  const SizedBox(height: 32),

                  // Reset Defaults Button
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmResetDialog(context, settings, primaryColor),
                      icon: const Icon(Icons.restart_alt_outlined, color: Colors.redAccent, size: 18),
                      label: const Text('恢復系統預設值', style: TextStyle(color: Colors.redAccent)),
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
                  isOffline ? '離線偏好儲存模式 (Local Storage)' : 'Supabase 雲端偏好對齊 (Cloud Synced)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isOffline ? Colors.amber : primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOffline
                      ? '您的偏好設定目前安全儲存於本機 SharedPreferences 中。'
                      : '設定將同時更新至 SharedPreferences 與 Supabase 雲端 User Metadata，實現跨裝置自動同步。',
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
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('恢復預設設定'),
            ],
          ),
          content: const Text('確定要將主題顏色、色彩模式與檢視偏好恢復為系統預設值嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
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
                    const SnackBar(content: Text('已恢復系統預設設定')),
                  );
                }
              },
              child: const Text('確認重置'),
            ),
          ],
        );
      },
    );
  }
}
