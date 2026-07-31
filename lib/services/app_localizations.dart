import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// AppLocalizations handles standard i18n without requiring code generation.
/// This makes building/deploying on environments like Vercel and GitHub Actions extremely robust.
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  // Dictionary containing translations
  static final Map<String, Map<String, String>> _localizedValues = {
    'zh': {
      'app_title': '保險客戶管理助手',
      'today_schedule': '今日行程',
      'customer_mgmt': '客戶管理',
      'project_visits': '專案拜訪',
      'relationship_topology': '人脈拓撲',
      'data_dashboard': '數據戰情',
      'personal_account': '個人帳號',
      'system_settings': '系統設定',
      'logout_system': '登出系統',
      'trash_bin': '垃圾桶',
      
      // Project Visits Page
      'pv_description': '建立專案來追蹤特定議題（如法規修訂、防灶關怀）的批次客戶拜訪進度。',
      'pv_list_count': '名單數',
      'pv_purpose': '專案目的',
      'pv_delete_tooltip': '刪除專案',
      'pv_no_customers': '無客戶名单',
      'pv_confirm_delete_title': '確認刪除專案',
      'pv_confirm_delete_body': '確定要刪除此拜訪專案嗎？此操作將同時清除該專案的拜訪 Checklist，但不會影響客戶的基本資料。',
      'pv_cancel': '取消',
      'pv_delete': '刪除',
      'pv_delete_success': '專案已刪除',
      'pv_delete_fail': '刪除失敗',
      'pv_load_fail': '載入專案失敗',
      'pv_user_not_logged_in': '使用者未登入',
      'pv_visit_marked': '已完成拜訪客戶',
      'pv_visit_unmarked': '已取消標記拜訪',
      'pv_update_fail': '更新失敗',
      'pv_customer_info': '客戶基本資訊',
      'pv_tags': '標籤分類',
      'pv_no_tags': '暫無標籤',
      'pv_notes': '備註說明',
      'pv_no_notes': '暫無備註記錄',
      'pv_empty_title': '尚未建立任何拜訪專案',
      'pv_empty_body': '您可以前往「客戶管理」分頁，使用搜尋欄或篩選器篩選出目標名单，\n並點選「建立專案」以追蹤特定拜訪議題！',
      
      // Settings Page Translations
      'system_settings_title': '系統個性化與偏好設定',
      'system_settings_subtitle': '自訂專屬您的工作介面風格、視圖習慣與跨裝置備份機制',
      'appearance_theme': '外觀與風格主題',
      'theme_mode': '色彩模式',
      'theme_light': '明亮模式',
      'theme_dark': '深暗模式',
      'theme_system': '跟隨系統',
      'accent_color': '主題色調',
      'operation_preferences': '操作與檢視偏好',
      'customer_view_mode': '客戶卡片預設檢視模式',
      'customer_view_mode_desc': '設定進入客戶管理頁面時的預設展現方式',
      'view_3d_card': '3D名片',
      'view_list_view': '條列清單',
      'auto_collapse_sidebar': '預設自動折疊邊欄',
      'auto_collapse_sidebar_desc': '啟動或進入系統時，自動保持側邊導覽列為精簡圖示模式',
      'sidebar_hover_expand': '懸停自動展開邊欄',
      'sidebar_hover_expand_desc': '當選單收折時，滑鼠懸停於其上自動展開，移開後自動合起',
      'language_title': '多國語系 (Language)',
      'pref_language': '顯示語言 Preference Language',
      'pref_language_desc': '切換專案介面顯示之語言語系 (對齊 Phase 6 i18n)',
      
      // Color Palettes
      'accent_teal': '商務青藍',
      'accent_blue': '皇家寶藍',
      'accent_green': '翡翠鮮綠',
      'accent_purple': '高雅奢紫',
      'accent_amber': '暖陽琥珀',
      
      // Cloud Sync Banners
      'cloud_sync_synced': 'Supabase 雲端偏好對齊 (Cloud Synced)',
      'cloud_sync_offline': '離線偏好儲存模式 (Local Storage)',
      'cloud_sync_synced_desc': '設定將同時更新至 SharedPreferences 與 Supabase 雲端 User Metadata，實現跨裝置自動同步。',
      'cloud_sync_offline_desc': '您的偏好設定目前安全儲存於本機 SharedPreferences 中。',
      
      // Action Buttons
      'reset_defaults': '恢復系統預設值',
      'reset_dialog_title': '恢復預設設定',
      'reset_dialog_content': '確定要將主題顏色、色彩模式與檢視偏好恢復為系統預設值嗎？',
      'cancel': '取消',
      'confirm': '確認',
      'reset_success': '已恢復系統預設設定',
      'offline_preview': '離線預覽',
      'offline_preview_mode': '離線預覽模式',
      'client_helper_v': '保險客戶管理助手 v1.0.0',
      
      // Customers Page Translations
      'customer_search_hint': '搜尋客戶姓名或標籤...',
      'customer_add_btn': '新增客戶',
      'customer_add_title': '新增客戶檔案',
      'customer_edit_title': '編輯客戶檔案',
      'customer_empty_title': '尚未建立客戶或查無此人',
      'customer_empty_desc': '點選右上角的「新增客戶」按鈕開始建立客戶資料。\n您也可以輸入其他關鍵字搜尋。',
      
      // Profile Page Translations
      'profile_title': '個人帳號',
      'profile_basic_info': '基本資料設定',
      'profile_name': '個人姓名',
      'profile_name_required': '請輸入您的姓名',
      'profile_phone': '聯絡電話',
      'profile_business_info': '商務與名片資訊',
      'profile_company': '所屬公司',
      'profile_job_title': '專業職稱',
      'profile_website': '公司 / 個人網站',
      'profile_website_eg': '例如: www.mywebsite.com',
      'profile_address': '服務地址',
      'profile_bio_hint': '個人簡介 (會顯示在名片背面或詳細資訊中)',
      'profile_save_changes': '儲存變更',
      'profile_saving': '正在儲存...',
      'profile_clear_avatar': '清除頭像',
      'profile_your_name': '您的姓名',
      'profile_no_title': '尚未設定職稱',
      'profile_save_success_offline': '成功儲存變更 (離線暫存)',
      'profile_save_success': '個人資料已更新',
      'profile_save_failed': '儲存個人資料失敗',
      'profile_avatar_upload_failed': '頭像上傳失敗',
      'profile_load_failed': '載入個人資料失敗',
      'customer_clear_photo': '清除照片',
      'customer_name_label': '客戶姓名 (必填)',
      'customer_nickname_label': '客戶綽號',
      'customer_phone_label': '電話號碼',
      'customer_email_label': 'Email 信箱',
      'customer_tags_label': '標籤 (逗號區隔)',
      'customer_tags_eg': '例如: 高意願, 醫療險, 車險',
      'customer_notes_label': '備註紀錄',
      'customer_delete_title': '確認刪除',
      'customer_delete_confirm_p1': '確定要刪除客戶「',
      'customer_delete_confirm_p2': '」嗎？資料將會移至垃圾桶並保留 30 天。',
      'delete': '刪除',
      'save': '儲存',
      'customer_card_notes_title': '備註',
      'customer_card_no_notes': '無備註資訊。',
      'customer_card_zoom_tooltip': '放大詳情',
      'customer_card_no_tags': '暫無標籤',
      'customer_card_notes_detail_title': '備註說明',
      'customer_card_not_filled': '未填寫',
      'customer_real_name': '本名',
      'customer_action_call': '撥打',
      'customer_action_email': '郵件',
      'customer_phone_copied': '已複製電話號碼至剪貼簿',
      'customer_phone_empty': '電話未填寫',
      'customer_email_copied': '已複製電子信箱至剪貼簿',
      'customer_email_empty': '信箱未填寫',
      'customer_phone_title': '電話',
      'customer_tags_classification': '標籤分類',
      'trash_bin': '垃圾桶',
      'trash_bin_empty': '垃圾桶是空的',
      'trash_bin_desc': '這裡會顯示已刪除的客戶檔案。資料將保留 30 天，之後會被自動永久刪除。',
      'trash_bin_restore': '復原',
      'trash_bin_delete_forever': '徹底刪除',
      'trash_bin_confirm_delete_forever_title': '確認徹底刪除',
      'trash_bin_confirm_delete_forever_desc': '確定要永久刪除該客戶的所有資料與上傳照片嗎？此操作將無法還原。',
      'trash_bin_restore_success': '成功復原客戶資料',
      'trash_bin_delete_forever_success': '已永久刪除客戶資料與相關照片',
      'trash_bin_days_left': '天後刪除',
      'trash_bin_soft_delete_success': '客戶已移至垃圾桶',
      'trash_bin_goto': '前往垃圾桶',
    },
    'en': {
      'app_title': 'Insurance Customer Assistant',
      'today_schedule': 'Today\'s Schedule',
      'customer_mgmt': 'Customers',
      'project_visits': 'Project Visits',
      'relationship_topology': 'Connections',
      'data_dashboard': 'Dashboard',
      'personal_account': 'Profile',
      'system_settings': 'Settings',
      'logout_system': 'Logout',
      'trash_bin': 'Trash Bin',
      
      // Project Visits Page
      'pv_description': 'Create projects to track batch customer visits for specific topics (e.g. regulation updates, care initiatives).',
      'pv_list_count': 'Count',
      'pv_purpose': 'Purpose',
      'pv_delete_tooltip': 'Delete Project',
      'pv_no_customers': 'No customers in list',
      'pv_confirm_delete_title': 'Confirm Delete Project',
      'pv_confirm_delete_body': 'Are you sure you want to delete this visit project? This will also remove the checklist, but customer profiles will not be affected.',
      'pv_cancel': 'Cancel',
      'pv_delete': 'Delete',
      'pv_delete_success': 'Project deleted',
      'pv_delete_fail': 'Delete failed',
      'pv_load_fail': 'Failed to load projects',
      'pv_user_not_logged_in': 'User not logged in',
      'pv_visit_marked': 'Visit marked as completed',
      'pv_visit_unmarked': 'Visit mark removed',
      'pv_update_fail': 'Update failed',
      'pv_customer_info': 'Customer Profile',
      'pv_tags': 'Tags',
      'pv_no_tags': 'No tags',
      'pv_notes': 'Notes',
      'pv_no_notes': 'No notes recorded',
      'pv_empty_title': 'No visit projects yet',
      'pv_empty_body': 'Go to "Customers" and use the search bar or filters to select a target list,\nthen click "Create Project" to track a specific visit topic!',
      
      // Settings Page Translations
      'system_settings_title': 'System Personalization & Preferences',
      'system_settings_subtitle': 'Customize your workflow interface, view preferences, and cloud synchronization',
      'appearance_theme': 'Appearance & Theme',
      'theme_mode': 'Theme Mode',
      'theme_light': 'Light Mode',
      'theme_dark': 'Dark Mode',
      'theme_system': 'System Default',
      'accent_color': 'Accent Color',
      'operation_preferences': 'Preferences & View Options',
      'customer_view_mode': 'Default View Mode',
      'customer_view_mode_desc': 'Set the default view mode when entering the customer manager',
      'view_3d_card': '3D Card',
      'view_list_view': 'List View',
      'auto_collapse_sidebar': 'Collapse Sidebar by Default',
      'auto_collapse_sidebar_desc': 'Automatically collapse the navigation drawer to icon-only mode upon startup',
      'sidebar_hover_expand': 'Hover to Auto-Expand Sidebar',
      'sidebar_hover_expand_desc': 'Automatically expand the collapsed sidebar on hover and collapse on leave',
      'language_title': 'Language & Localization',
      'pref_language': 'Preference Language',
      'pref_language_desc': 'Switch application interface display language (Align with Phase 6 i18n)',
      
      // Color Palettes
      'accent_teal': 'Teal Cyan',
      'accent_blue': 'Royal Blue',
      'accent_green': 'Emerald Green',
      'accent_purple': 'Royal Purple',
      'accent_amber': 'Amber Gold',
      
      // Cloud Sync Banners
      'cloud_sync_synced': 'Supabase Cloud Synced',
      'cloud_sync_offline': 'Local Storage Mode',
      'cloud_sync_synced_desc': 'Settings will be updated to both SharedPreferences and Supabase Cloud User Metadata for cross-device synchronization.',
      'cloud_sync_offline_desc': 'Your preference settings are currently saved securely in local SharedPreferences.',
      
      // Action Buttons
      'reset_defaults': 'Reset to Defaults',
      'reset_dialog_title': 'Reset Settings',
      'reset_dialog_content': 'Are you sure you want to reset theme color, color mode, and view preferences to system defaults?',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'reset_success': 'System settings restored to defaults',
      'offline_preview': 'Offline Preview',
      'offline_preview_mode': 'Offline Preview Mode',
      'client_helper_v': 'Insurance Helper v1.0.0',
      
      // Customers Page Translations
      'customer_search_hint': 'Search customers by name or tag...',
      'customer_add_btn': 'Add Customer',
      'customer_add_title': 'Add Customer File',
      'customer_edit_title': 'Edit Customer File',
      'customer_empty_title': 'No Customers Found',
      'customer_empty_desc': 'Click the \'Add Customer\' button in the upper right to start creating customer profiles.\nYou can also search for other keywords.',
      
      // Profile Page Translations
      'profile_title': 'Profile',
      'profile_basic_info': 'Basic Information Settings',
      'profile_name': 'Full Name',
      'profile_name_required': 'Please enter your name',
      'profile_phone': 'Contact Phone',
      'profile_business_info': 'Business & Card Details',
      'profile_company': 'Company',
      'profile_job_title': 'Job Title',
      'profile_website': 'Company / Personal Website',
      'profile_website_eg': 'e.g., www.mywebsite.com',
      'profile_address': 'Service Address',
      'profile_bio_hint': 'Short Biography (will be shown on the back of the card)',
      'profile_save_changes': 'Save Changes',
      'profile_saving': 'Saving...',
      'profile_clear_avatar': 'Clear Avatar',
      'profile_your_name': 'Your Name',
      'profile_no_title': 'No Job Title Set',
      'profile_save_success_offline': 'Changes saved successfully (offline cached)',
      'profile_save_success': 'Profile updated successfully',
      'profile_save_failed': 'Failed to save profile',
      'profile_avatar_upload_failed': 'Failed to upload avatar',
      'profile_load_failed': 'Failed to load profile',
      'customer_clear_photo': 'Clear Photo',
      'customer_name_label': 'Customer Name (Required)',
      'customer_nickname_label': 'Nickname',
      'customer_phone_label': 'Phone Number',
      'customer_email_label': 'Email Address',
      'customer_tags_label': 'Tags (comma-separated)',
      'customer_tags_eg': 'e.g., High Intent, Medical, Auto',
      'customer_notes_label': 'Notes & Remarks',
      'customer_delete_title': 'Confirm Delete',
      'customer_delete_confirm_p1': 'Are you sure you want to delete customer "',
      'customer_delete_confirm_p2': '"? This will move them to the Trash Bin for 30 days.',
      'delete': 'Delete',
      'save': 'Save',
      'customer_card_notes_title': 'Notes',
      'customer_card_no_notes': 'No notes available.',
      'customer_card_zoom_tooltip': 'Zoom Details',
      'customer_card_no_tags': 'No tags',
      'customer_card_notes_detail_title': 'Notes Detail',
      'customer_card_not_filled': 'Not Filled',
      'customer_real_name': 'Real Name',
      'customer_action_call': 'Call',
      'customer_action_email': 'Email',
      'customer_phone_copied': 'Phone number copied to clipboard',
      'customer_phone_empty': 'Phone number not set',
      'customer_email_copied': 'Email address copied to clipboard',
      'customer_email_empty': 'Email address not set',
      'customer_phone_title': 'Phone',
      'customer_tags_classification': 'Tags',
      'trash_bin': 'Trash Bin',
      'trash_bin_empty': 'Trash Bin is empty',
      'trash_bin_desc': 'Deleted customer profiles are kept here for 30 days before being permanently deleted.',
      'trash_bin_restore': 'Restore',
      'trash_bin_delete_forever': 'Delete Forever',
      'trash_bin_confirm_delete_forever_title': 'Confirm Delete Forever',
      'trash_bin_confirm_delete_forever_desc': 'Are you sure you want to permanently delete this customer and their photos? This action cannot be undone.',
      'trash_bin_restore_success': 'Customer profile restored successfully',
      'trash_bin_delete_forever_success': 'Customer and photos permanently deleted',
      'trash_bin_days_left': 'days left',
      'trash_bin_soft_delete_success': 'Customer moved to Trash Bin',
      'trash_bin_goto': 'Go to Trash',
    }
  };

  /// Translate the given key into target language
  String translate(String key) {
    final languageCode = locale.languageCode;
    return _localizedValues[languageCode]?[key] ?? _localizedValues['zh']?[key] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['zh', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Helper extension on BuildContext to quickly access translations
extension LocalizationsX on BuildContext {
  String l10n(String key) {
    return AppLocalizations.of(this)?.translate(key) ?? key;
  }
}
