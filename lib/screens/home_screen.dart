import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../main.dart';
import '../services/app_settings.dart';
import '../services/app_localizations.dart';
import '../models/schedule_event.dart';
import '../widgets/schedule_event_dialog.dart';
import '../widgets/custom_toast.dart';
import '../widgets/voice_scheduler_overlay.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'customer_management_tab.dart';
import 'visit_projects_tab.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'trash_bin_screen.dart';
import 'insurance_news_tab.dart';
import '../widgets/route_planner_dialog.dart';
import '../widgets/responsive_layout.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now(); // Default to dynamic current time
  String _activeMenu = '今日行程';

  String _getLocalizedMenuTitle(String menu) {
    if (menu == '今日行程') return context.l10n('today_schedule');
    if (menu == '客戶管理') return context.l10n('customer_mgmt');
    if (menu == '專案拜訪') return context.l10n('project_visits');
    if (menu == '人脈拓撲') return context.l10n('relationship_topology');
    if (menu == '數據戰情') return context.l10n('data_dashboard');
    if (menu == '個人帳號') return context.l10n('personal_account');
    if (menu == '系統設定') return context.l10n('system_settings');
    if (menu == '垃圾桶') return context.l10n('trash_bin');
    return menu;
  }
  bool _isSidebarCollapsed = false;
  bool _isSidebarHovered = false;

  bool get _effectiveSidebarCollapsed {
    final bool isHoverExpandActive = AppSettings.instance.isSidebarHoverExpandEnabled;
    return _isSidebarCollapsed && !(isHoverExpandActive && _isSidebarHovered);
  }

  String _userName = '載入中...';
  String _userEmail = '';
  String _userAvatarUrl = '';

  List<ScheduleEvent> _events = [];
  bool _isLoadingEvents = false;
  String _calendarViewMode = 'timeline'; // 'timeline' (日時間軸) 或 'month_grid' (月網格)

  @override
  void initState() {
    super.initState();
    _isSidebarCollapsed = AppSettings.instance.isSidebarCollapsedByDefault;
    AppSettings.instance.addListener(_handleSettingsChanged);
    _loadUserProfile();
    _loadSavedMenu();
    _fetchEventsForSelectedDate();
  }

  Future<void> _fetchEventsForSelectedDate({bool silent = false}) async {
    if (isOfflineMode) {
      setState(() {
        _events = [
          ScheduleEvent(
            id: 'demo-1',
            profileId: 'offline',
            title: '穿黑色衣服 (範例)',
            startAt: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 9, 0),
            endAt: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 10, 0),
            eventType: 'personal',
          ),
          ScheduleEvent(
            id: 'demo-2',
            profileId: 'offline',
            title: '服學 正式活動 (範例)',
            startAt: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 14, 30),
            endAt: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 17, 30),
            location: '台大第一學生活動中心',
            eventType: 'visit',
          ),
        ];
      });
      return;
    }

    if (!silent && _events.isEmpty) {
      setState(() => _isLoadingEvents = true);
    }
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        DateTime rangeStart;
        DateTime rangeEnd;

        if (_calendarViewMode == 'month_grid') {
          // 月網格模式：查詢全月份資料 (延伸前後各 7 天以蓋過跨月週格)
          rangeStart = DateTime(_selectedDate.year, _selectedDate.month, 1, 0, 0, 0).subtract(const Duration(days: 7)).toUtc();
          rangeEnd = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59).add(const Duration(days: 7)).toUtc();
        } else {
          // 日時間軸模式：查詢單日涵蓋行程
          rangeStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0).toUtc();
          rangeEnd = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59).toUtc();
        }

        final data = await Supabase.instance.client
            .from('schedule_events')
            .select()
            .eq('profile_id', user.id)
            .lte('start_at', rangeEnd.toIso8601String())
            .gte('end_at', rangeStart.toIso8601String())
            .order('start_at');

        if (mounted) {
          setState(() {
            _events = (data as List).map((json) => ScheduleEvent.fromJson(json)).toList();
          });
        }
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  Future<void> _openAddEditEventDialog([ScheduleEvent? event]) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (ctx) => ScheduleEventDialog(
        initialDate: _selectedDate,
        eventToEdit: event,
      ),
    );

    if (result != null && mounted) {
      _fetchEventsForSelectedDate();

      if (result == 'created') {
        CustomToast.show(context, '行程已成功新增！', ToastType.success);
      } else if (result == 'updated') {
        CustomToast.show(context, '行程變更已儲存！', ToastType.success);
      } else if (result == 'deleted') {
        CustomToast.show(context, '行程已成功刪除！', ToastType.warning);
      }
    }
  }

  Future<void> _openVoiceSchedulerDialog() async {
    final result = await showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'VoiceScheduler',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const VoiceSchedulerOverlay();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: child,
        );
      },
    );

    if (result != null && mounted) {
      final status = result['status'] as String? ?? 'green';
      final eventMap = result['event'] as Map<String, dynamic>?;

      if (eventMap != null) {
        final event = ScheduleEvent.fromJson(eventMap);
        if (status == 'yellow') {
          CustomToast.show(context, '行程資訊有所遺漏，請手動補完！', ToastType.warning);
          await _openAddEditEventDialog(event);
        } else {
          CustomToast.show(context, '已成功自動建立行程：「${event.title}」', ToastType.success);
          _fetchEventsForSelectedDate();
        }
      }
    }
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  void _handleSettingsChanged() {
    if (mounted) {
      setState(() {
        _isSidebarCollapsed = AppSettings.instance.isSidebarCollapsedByDefault;
      });
    }
  }

  Future<void> _loadSavedMenu() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMenu = prefs.getString('last_active_menu');
      final savedViewMode = prefs.getString('calendar_view_mode');
      if (savedMenu != null && mounted) {
        setState(() {
          _activeMenu = savedMenu;
        });
      }
      if (savedViewMode != null && mounted) {
        setState(() {
          _calendarViewMode = savedViewMode;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  void _updateCalendarViewMode(String mode) {
    if (_calendarViewMode != mode) {
      setState(() {
        _calendarViewMode = mode;
      });
      _fetchEventsForSelectedDate(silent: true);
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('calendar_view_mode', mode);
      });
    }
  }

  void _changeActiveMenu(String menu) async {
    if (!mounted) return;
    setState(() {
      _activeMenu = menu;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_active_menu', menu);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadUserProfile() async {
    if (isOfflineMode) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userName = prefs.getString('profile_name') ?? '王大同 業務代表';
        _userEmail = 'offline@insurance.helper';
        _userAvatarUrl = prefs.getString('profile_avatar_url') ?? '';
      });
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        // Query from profiles table
        final data = await supabase
            .from('profiles')
            .select('full_name, email, avatar_url')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            if (data != null && data['full_name'] != null) {
              _userName = data['full_name'];
            } else {
              _userName = user.userMetadata?['full_name'] ?? '新業務代表';
            }
            _userEmail = data?['email'] ?? user.email ?? '';
            _userAvatarUrl = data?['avatar_url'] ?? '';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final user = Supabase.instance.client.auth.currentUser;
        setState(() {
          _userName = user?.userMetadata?['full_name'] ?? user?.email ?? '業務代表';
          _userEmail = user?.email ?? '';
          _userAvatarUrl = '';
        });
      }
    }
  }

  // Sign out handler
  Future<void> _handleSignOut() async {
    if (isOfflineMode) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    try {
      await Supabase.instance.client.auth.signOut();
      // AuthGateway reactively handles returning to LoginScreen.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登出失敗: $e')),
        );
      }
    }
  }

  // Show date picker and update selected date
  Future<void> _selectDate(BuildContext context) async {
    final primaryColor = AppSettings.instance.primaryColor;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF161B22),
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Get week dates based on selected date
  List<DateTime> _getWeekDates(DateTime date) {
    final int daysFromMonday = date.weekday - 1;
    final DateTime monday = date.subtract(Duration(days: daysFromMonday));
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= 768;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;

    final Color sidebarBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF21262D) : Colors.grey.shade200;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white54 : Colors.black54;

    // Sidebar navigation content
    Widget sidebarContent() {
      final isHoverExpandActive = AppSettings.instance.isSidebarHoverExpandEnabled;
      return MouseRegion(
        onEnter: (_) {
          if (isHoverExpandActive && _isSidebarCollapsed && !_isSidebarHovered) {
            setState(() {
              _isSidebarHovered = true;
            });
          }
        },
        onExit: (_) {
          if (isHoverExpandActive && _isSidebarHovered) {
            setState(() {
              _isSidebarHovered = false;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          color: sidebarBg,
          width: _effectiveSidebarCollapsed ? 80 : 260,
          child: Column(
            children: [
              // Header Profile Area
              InkWell(
                onTap: () {
                  _changeActiveMenu('個人帳號');
                  if (MediaQuery.of(context).size.width < 768) {
                    Navigator.of(context).pop(); // Close drawer on mobile
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: borderColor, width: 1),
                    ),
                  ),
                  child: _effectiveSidebarCollapsed
                      ? Center(
                          child: CircleAvatar(
                            backgroundColor: primaryColor,
                            radius: 20,
                            backgroundImage: _getAvatarProvider(_userAvatarUrl),
                            child: _userAvatarUrl.isEmpty
                                ? Text(
                                    _userName.isNotEmpty ? _userName.substring(0, 1) : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        )
                      : Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: primaryColor,
                              radius: 20,
                              backgroundImage: _getAvatarProvider(_userAvatarUrl),
                              child: _userAvatarUrl.isEmpty
                                  ? Text(
                                      _userName.isNotEmpty ? _userName.substring(0, 1) : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userName,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isOfflineMode ? '離線模式' : _userEmail,
                                    style: TextStyle(
                                      color: isOfflineMode ? Colors.amber : subTextColor,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 16),

              // Navigation Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    _buildSidebarItem(Icons.calendar_today_outlined, '今日行程', isDark, primaryColor),
                    _buildSidebarItem(Icons.newspaper_outlined, '新聞頭條', isDark, primaryColor),
                    _buildSidebarItem(Icons.people_outline, '客戶管理', isDark, primaryColor),
                    _buildSidebarItem(Icons.assignment_outlined, '專案拜訪', isDark, primaryColor),
                    _buildSidebarItem(Icons.hub_outlined, '人脈拓撲', isDark, primaryColor),
                    _buildSidebarItem(Icons.bar_chart_outlined, '數據戰情', isDark, primaryColor),
                    _buildSidebarItem(Icons.account_circle_outlined, '個人帳號', isDark, primaryColor),
                    _buildSidebarItem(Icons.delete_outline, '垃圾桶', isDark, primaryColor),
                    _buildSidebarItem(Icons.settings_outlined, '系統設定', isDark, primaryColor),
                  ],
                ),
              ),

              // Collapse button (Desktop only)
              if (isWideScreen)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isSidebarCollapsed = !_isSidebarCollapsed;
                      _isSidebarHovered = false; // Reset hover if manually toggled
                    });
                  },
                  icon: Icon(
                    _effectiveSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                    color: subTextColor,
                  ),
                ),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: _effectiveSidebarCollapsed
                    ? IconButton(
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                        onPressed: _handleSignOut,
                      )
                    : Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: const Icon(Icons.logout, color: Colors.redAccent),
                          title: Text(context.l10n('logout_system'), style: const TextStyle(color: Colors.redAccent)),
                          onTap: _handleSignOut,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      drawer: isWideScreen ? null : Drawer(child: sidebarContent()),
      appBar: isWideScreen
          ? null
          : AppBar(
              title: Text(_getLocalizedMenuTitle(_activeMenu)),
              backgroundColor: sidebarBg,
              actions: [
                if (isOfflineMode)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      context.l10n('offline_preview'),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
      body: Row(
        children: [
          if (isWideScreen) sidebarContent(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Wide Screen Header
                if (isWideScreen) _buildWebHeader(isDark, textColor, subTextColor, borderColor),
                
                // Main Working Area
                Expanded(
                  child: _activeMenu == '今日行程'
                      ? _buildScheduleView(isWideScreen, isDark, textColor, subTextColor, borderColor, primaryColor)
                      : _activeMenu == '新聞頭條'
                          ? const InsuranceNewsTab()
                              : _activeMenu == '客戶管理'
                                  ? CustomerManagementTab(
                                      onMenuChanged: (menu) {
                                        setState(() {
                                          _activeMenu = menu;
                                        });
                                      },
                                    )
                                  : _activeMenu == '專案拜訪'
                                      ? const VisitProjectsTab()
                                      : _activeMenu == '個人帳號'
                                          ? ProfileScreen(onProfileUpdated: _loadUserProfile)
                                          : _activeMenu == '垃圾桶'
                                              ? const TrashBinScreen()
                                          : _activeMenu == '系統設定'
                                              ? const SettingsScreen()
                                              : _buildFallbackScreen(),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _activeMenu == '今日行程'
          ? _VoiceSchedulerFAB(
              onPressed: _openVoiceSchedulerDialog,
              isDark: isDark,
              primaryColor: primaryColor,
            )
          : null,
    );
  }

  // Helper to build sidebar item
  Widget _buildSidebarItem(IconData icon, String title, bool isDark, Color primaryColor) {
    final bool isActive = _activeMenu == title;
    final Color activeBg = primaryColor.withOpacity(0.15);
    final Color inactiveText = isDark ? Colors.white70 : Colors.black87;

    final String displayTitle = _getLocalizedMenuTitle(title);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          _changeActiveMenu(title);
          if (MediaQuery.of(context).size.width < 768) {
            Navigator.of(context).pop(); // Close drawer on mobile
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: _effectiveSidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isActive ? primaryColor : inactiveText,
                size: 20,
              ),
              if (!_effectiveSidebarCollapsed) ...[
                const SizedBox(width: 16),
                Text(
                  displayTitle,
                  style: TextStyle(
                    color: isActive ? primaryColor : inactiveText,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Web Header (Desktop top bar)
  Widget _buildWebHeader(bool isDark, Color textColor, Color subTextColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : Colors.white,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _getLocalizedMenuTitle(_activeMenu),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Row(
            children: [
              if (isOfflineMode)
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withOpacity(0.3),
                    border: Border.all(color: Colors.amber.shade700, width: 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.offline_bolt_outlined, size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n('offline_preview_mode'),
                        style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          )
        ],
      ),
    );
  }

  // Horizontal Weekly Calendar Strip
  Widget _buildWeeklyCalendarStrip(bool isDark, Color textColor, Color subTextColor, Color borderColor, Color primaryColor) {
    final List<DateTime> weekDates = _getWeekDates(_selectedDate);
    final String localeStr = AppSettings.instance.language;
    final String monthString = DateFormat.yMMMM(localeStr).format(_selectedDate);

    // Get narrow weekdays from date symbols (Sun, Mon, Tue...)
    final List<String> narrowWeekdays = DateFormat.E(localeStr).dateSymbols.NARROWWEEKDAYS;
    // Map to Mon-Sun
    final List<String> weekdays = [
      narrowWeekdays[1], // Mon
      narrowWeekdays[2], // Tue
      narrowWeekdays[3], // Wed
      narrowWeekdays[4], // Thu
      narrowWeekdays[5], // Fri
      narrowWeekdays[6], // Sat
      narrowWeekdays[0], // Sun
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Selector Title
          GestureDetector(
            onTap: () => _selectDate(context),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    monthString,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_drop_down, color: primaryColor, size: 24),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Weekly Row
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: primaryColor),
                tooltip: '上一週',
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(const Duration(days: 7));
                  });
                },
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final DateTime date = weekDates[index];
                    final bool isSelected = date.year == _selectedDate.year &&
                        date.month == _selectedDate.month &&
                        date.day == _selectedDate.day;
                    
                    final bool isToday = date.day == DateTime.now().day &&
                        date.month == DateTime.now().month &&
                        date.year == DateTime.now().year;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = date;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? primaryColor 
                                : isToday 
                                    ? primaryColor.withOpacity(0.1) 
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isToday && !isSelected
                                ? Border.all(color: primaryColor, width: 1)
                                : Border.all(color: Colors.transparent),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : null,
                          ),
                          child: Column(
                            children: [
                              Text(
                                weekdays[index],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : subTextColor,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: primaryColor),
                tooltip: '下一週',
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 7));
                  });
                },
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildScheduleView(
    bool isWideScreen,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color borderColor,
    Color primaryColor,
  ) {
    if (isWideScreen) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Calendar & Today Summary & Quick Actions
          SizedBox(
            width: 320,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Monthly Calendar Picker Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: borderColor),
                    ),
                    color: isDark ? const Color(0xFF161B22) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CalendarDatePicker(
                        key: ValueKey('${_selectedDate.year}-${_selectedDate.month}'),
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        onDateChanged: (newDate) {
                          final bool sameMonth = newDate.month == _selectedDate.month && newDate.year == _selectedDate.year;
                          setState(() => _selectedDate = newDate);
                          if (!sameMonth || _calendarViewMode == 'timeline') {
                            _fetchEventsForSelectedDate(silent: true);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Add Event Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _openAddEditEventDialog(),
                      icon: const Icon(Icons.add),
                      label: Text(context.l10n('event_add_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Summary Card
                  _buildTodaySummaryCard(isDark, borderColor, primaryColor),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: borderColor),
          // Right Column: Timeline Header + Dynamic Timeline / Month Grid List
          Expanded(
            child: Column(
              children: [
                _buildTimelineHeader(isDark, primaryColor),
                Expanded(
                  child: _calendarViewMode == 'month_grid'
                      ? _buildMonthGridView(isDark, borderColor, primaryColor)
                      : _buildScheduleTimeline(),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildWeeklyCalendarStrip(isDark, textColor, subTextColor, borderColor, primaryColor),
          _buildTimelineHeader(isDark, primaryColor),
          Expanded(
            child: _calendarViewMode == 'month_grid'
                ? _buildMonthGridView(isDark, borderColor, primaryColor)
                : _buildScheduleTimeline(),
          ),
        ],
      );
    }
  }

  Widget _buildTimelineHeader(bool isDark, Color primaryColor) {
    final bool isMobileScreen = context.isMobile;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobileScreen ? 12 : 20,
        vertical: isMobileScreen ? 8 : 12,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey.shade200)),
      ),
      child: isMobileScreen
          ? Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.today, color: primaryColor, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _calendarViewMode == 'month_grid'
                              ? DateFormat('yyyy/MM', AppSettings.instance.language).format(_selectedDate)
                              : DateFormat('yyyy/MM/dd (EEE)', AppSettings.instance.language).format(_selectedDate),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 24),
                          onPressed: () {
                            setState(() {
                              if (_calendarViewMode == 'month_grid') {
                                _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                              } else {
                                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                              }
                            });
                            _fetchEventsForSelectedDate(silent: true);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 24),
                          onPressed: () {
                            setState(() {
                              if (_calendarViewMode == 'month_grid') {
                                _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                              } else {
                                _selectedDate = _selectedDate.add(const Duration(days: 1));
                              }
                            });
                            _fetchEventsForSelectedDate(silent: true);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedDate = DateTime.now();
                            });
                            _fetchEventsForSelectedDate(silent: true);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text(context.l10n('calendar_back_to_today'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => RoutePlannerDialog(
                                selectedDate: _selectedDate,
                                events: _events,
                              ),
                            );
                          },
                          icon: const Icon(Icons.alt_route, size: 14, color: Colors.white),
                          label: const Text('路線規劃', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // View mode switcher on mobile
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161B22) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF30363D) : Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _updateCalendarViewMode('timeline'),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _calendarViewMode == 'timeline' ? primaryColor : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.view_day_outlined,
                                        size: 14,
                                        color: _calendarViewMode == 'timeline' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        context.l10n('calendar_view_timeline'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _calendarViewMode == 'timeline' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              InkWell(
                                onTap: () => _updateCalendarViewMode('month_grid'),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _calendarViewMode == 'month_grid' ? primaryColor : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.grid_on_outlined,
                                        size: 14,
                                        color: _calendarViewMode == 'month_grid' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        context.l10n('calendar_view_month'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _calendarViewMode == 'month_grid' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_isLoadingEvents)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.today, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _calendarViewMode == 'month_grid'
                          ? DateFormat('yyyy/MM', AppSettings.instance.language).format(_selectedDate)
                          : DateFormat('yyyy/MM/dd (EEE)', AppSettings.instance.language).format(_selectedDate),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 30),
                      onPressed: () {
                        setState(() {
                          if (_calendarViewMode == 'month_grid') {
                            _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                          } else {
                            _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                          }
                        });
                        _fetchEventsForSelectedDate(silent: true);
                      },
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 30),
                      onPressed: () {
                        setState(() {
                          if (_calendarViewMode == 'month_grid') {
                            _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                          } else {
                            _selectedDate = _selectedDate.add(const Duration(days: 1));
                          }
                        });
                        _fetchEventsForSelectedDate(silent: true);
                      },
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime.now();
                        });
                        _fetchEventsForSelectedDate(silent: true);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text(context.l10n('calendar_back_to_today'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // 路線規劃按鈕
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => RoutePlannerDialog(
                            selectedDate: _selectedDate,
                            events: _events,
                          ),
                        );
                      },
                      icon: const Icon(Icons.alt_route, size: 16, color: Colors.white),
                      label: const Text('路線規劃', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 視圖切換按鈕 (日時間軸 vs 月網格)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161B22) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF30363D) : Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _updateCalendarViewMode('timeline'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _calendarViewMode == 'timeline' ? primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.view_day_outlined,
                                    size: 16,
                                    color: _calendarViewMode == 'timeline' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    context.l10n('calendar_view_timeline'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _calendarViewMode == 'timeline' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _updateCalendarViewMode('month_grid'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _calendarViewMode == 'month_grid' ? primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.grid_on_outlined,
                                    size: 16,
                                    color: _calendarViewMode == 'month_grid' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    context.l10n('calendar_view_month'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _calendarViewMode == 'month_grid' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_isLoadingEvents)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _fetchEventsForSelectedDate,
                      tooltip: '重新整理行程',
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildTodaySummaryCard(bool isDark, Color borderColor, Color primaryColor) {
    final totalCount = _events.length;
    final completedCount = _events.where((e) => e.isCompleted).length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      color: isDark ? const Color(0xFF161B22) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_outline, size: 18, color: primaryColor),
                const SizedBox(width: 8),
                Text(context.l10n('today_summary'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat(context.l10n('stat_total'), '$totalCount', isDark),
                _buildSummaryStat(context.l10n('stat_completed'), '$completedCount', isDark),
                _buildSummaryStat(context.l10n('stat_pending'), '${totalCount - completedCount}', isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
      ],
    );
  }

  Widget _buildMonthGridView(bool isDark, Color borderColor, Color primaryColor) {
    if (_isLoadingEvents && _events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final DateTime firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final int leadingOffset = firstDayOfMonth.weekday % 7; // Sunday = 0
    final DateTime gridStartDate = firstDayOfMonth.subtract(Duration(days: leadingOffset));

    final bool isEn = AppSettings.instance.language == 'en_US';
    final List<String> weekHeaderLabels = isEn
        ? ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
        : ['日', '一', '二', '三', '四', '五', '六'];

    List<List<DateTime>> weekGrid = [];
    DateTime currDate = gridStartDate;

    while (true) {
      List<DateTime> week = [];
      for (int i = 0; i < 7; i++) {
        week.add(currDate);
        currDate = currDate.add(const Duration(days: 1));
      }
      weekGrid.add(week);
      if (currDate.month != _selectedDate.month && weekGrid.length >= 5) {
        break;
      }
    }

    return Column(
      children: [
        // Weekday Header Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: weekHeaderLabels.map((label) {
              final bool isWeekend = label == '日' || label == '六' || label == 'Sun' || label == 'Sat';
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isWeekend ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Month Grid Weeks List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: weekGrid.length,
            itemBuilder: (context, weekIdx) {
              final weekDays = weekGrid[weekIdx];
              final DateTime weekStart = DateTime(weekDays.first.year, weekDays.first.month, weekDays.first.day, 0, 0, 0);
              final DateTime weekEnd = DateTime(weekDays.last.year, weekDays.last.month, weekDays.last.day, 23, 59, 59);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                height: 110,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double colWidth = constraints.maxWidth / 7.0;

                    // Filter events overlapping this 7-day week
                    final List<ScheduleEvent> weekEvents = _events.where((e) {
                      final DateTime effectiveEnd = (e.endAt.hour == 0 && e.endAt.minute == 0 && e.endAt.second == 0 && e.endAt.isAfter(e.startAt))
                          ? e.endAt.subtract(const Duration(seconds: 1))
                          : e.endAt;

                      return !e.startAt.isAfter(weekEnd) && !effectiveEnd.isBefore(weekStart);
                    }).toList();

                    return Stack(
                      children: [
                        // Base 7 Grid Cells (Background)
                        Row(
                          children: List.generate(7, (colIdx) {
                            final DateTime cellDate = weekDays[colIdx];
                            final bool isCurrentMonthDay = cellDate.month == _selectedDate.month;
                            final bool isToday = cellDate.year == DateTime.now().year &&
                                cellDate.month == DateTime.now().month &&
                                cellDate.day == DateTime.now().day;
                            final bool isSelected = cellDate.year == _selectedDate.year &&
                                cellDate.month == _selectedDate.month &&
                                cellDate.day == _selectedDate.day;

                            return Expanded(
                              child: InkWell(
                                onTap: () {
                                  final bool sameMonth = cellDate.month == _selectedDate.month && cellDate.year == _selectedDate.year;
                                  setState(() => _selectedDate = cellDate);
                                  if (!sameMonth) {
                                    _fetchEventsForSelectedDate(silent: true);
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryColor.withValues(alpha: 0.08)
                                        : (isCurrentMonthDay
                                            ? (isDark ? const Color(0xFF161B22) : Colors.white)
                                            : (isDark ? const Color(0xFF0D1117).withValues(alpha: 0.3) : Colors.grey.shade50)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? primaryColor
                                          : isToday
                                              ? primaryColor.withValues(alpha: 0.5)
                                              : (isCurrentMonthDay ? borderColor : borderColor.withValues(alpha: 0.3)),
                                      width: isSelected ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: isToday
                                                ? BoxDecoration(
                                                    color: primaryColor,
                                                    shape: BoxShape.circle,
                                                  )
                                                : null,
                                            child: Text(
                                              '${cellDate.day}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isToday
                                                    ? Colors.white
                                                    : (isSelected
                                                        ? primaryColor
                                                        : (isCurrentMonthDay
                                                            ? (isDark ? Colors.white70 : Colors.black87)
                                                            : (isDark ? Colors.white30 : Colors.black38))),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        // Event Banners Overlay (Continuous Horizontal Banners Across Multi-Days)
                        ...List.generate(weekEvents.length > 3 ? 3 : weekEvents.length, (evtIdx) {
                          final event = weekEvents[evtIdx];
                          final DateTime effectiveEnd = (event.endAt.hour == 0 && event.endAt.minute == 0 && event.endAt.second == 0 && event.endAt.isAfter(event.startAt))
                              ? event.endAt.subtract(const Duration(seconds: 1))
                              : event.endAt;

                          final DateTime eventStartDate = DateTime(event.startAt.year, event.startAt.month, event.startAt.day);
                          final DateTime eventEndDate = DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day);

                          int startCol = -1;
                          int endCol = -1;

                          for (int c = 0; c < 7; c++) {
                            final date = DateTime(weekDays[c].year, weekDays[c].month, weekDays[c].day);
                            final bool overlaps = !date.isBefore(eventStartDate) && !date.isAfter(eventEndDate);

                            if (overlaps) {
                              if (startCol == -1) startCol = c;
                              endCol = c;
                            }
                          }

                          if (startCol == -1 || endCol == -1) return const SizedBox.shrink();

                          final double left = startCol * colWidth + 4.0;
                          final double width = (endCol - startCol + 1) * colWidth - 8.0;
                          final double top = 32.0 + evtIdx * 24.0;

                          final String displayTag = (event.tag != null && event.tag!.trim().isNotEmpty)
                              ? event.tag!.trim()
                              : event.title;

                          final Color bannerBg = _getEventTypeColor(event.eventType, primaryColor);

                          return Positioned(
                            top: top,
                            left: left,
                            width: width < 10.0 ? 10.0 : width,
                            height: 22.0,
                            child: InkWell(
                              onTap: () => _openAddEditEventDialog(event),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: bannerBg.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: bannerBg.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  displayTag,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Vertical Day Timeline Schedule
  Widget _buildScheduleTimeline() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;
    final Color gridColor = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;
    final Color hourTextColor = isDark ? Colors.white30 : Colors.black45;

    final List<int> hours = List.generate(19, (index) => index + 6); // 06:00 to 24:00

    if (_isLoadingEvents) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: primaryColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              '本日暫無排定行程',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '點擊左側或下方按鈕新增第一個行程',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white30 : Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openAddEditEventDialog(),
              icon: const Icon(Icons.add),
              label: Text(context.l10n('event_add_title')),
            ),
          ],
        ),
      );
    }

    final double totalGridHeight = hours.length * 60.0 + 80.0;

    final DateTime dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0);
    final DateTime dayEnd = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    final eventLayouts = _computeTimelineLayouts(_events, dayStart, dayEnd);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double availableWidth = (constraints.maxWidth - 70.0).clamp(100.0, 3000.0);

          return SizedBox(
            height: totalGridHeight,
            child: Stack(
              children: [
                // Timeline Base grid lines
                Column(
                  children: hours.map((hour) {
                    final String hourLabel = hour.toString().padLeft(2, '0') + ':00';
                    return SizedBox(
                      height: 60,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 50,
                            child: Text(
                              hourLabel,
                              style: TextStyle(
                                color: hourTextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Divider(
                                color: gridColor,
                                thickness: 1,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                // Render Dynamic Events Side-By-Side
                ...eventLayouts.map((layout) {
                  final event = layout.event;
                  final DateTime effectiveStart = event.startAt.isBefore(dayStart) ? dayStart : event.startAt;
                  final DateTime effectiveEnd = event.endAt.isAfter(dayEnd) ? dayEnd : event.endAt;

                  final double startHour = effectiveStart.hour + (effectiveStart.minute / 60.0);
                  final double endHour = effectiveEnd.hour + (effectiveEnd.minute / 60.0);

                  final double topOffset = (startHour - 6.0) * 60.0 + 8.0;
                  final double durationHours = (endHour - startHour).clamp(0.5, 18.0);
                  final double cardHeight = durationHours * 60.0;

                  final double colWidth = availableWidth / layout.totalCols;
                  final double left = 60.0 + layout.colIndex * colWidth;
                  final double width = colWidth - 4.0;

                  final String timeRange = '${DateFormat('HH:mm').format(event.startAt)} - ${DateFormat('HH:mm').format(event.endAt)}';
                  final bool isShort = cardHeight <= 55;
                  final String displayTag = (event.tag != null && event.tag!.trim().isNotEmpty)
                      ? event.tag!.trim()
                      : _getLocalizedEventType(event.eventType);

                  return Positioned(
                    top: topOffset < 8.0 ? 8.0 : topOffset,
                    left: left < 60.0 ? 60.0 : left,
                    width: width < 30.0 ? 30.0 : width,
                    height: cardHeight < 40.0 ? 40.0 : cardHeight,
                    child: InkWell(
                      onTap: () => _openAddEditEventDialog(event),
                      borderRadius: BorderRadius.circular(8),
                      child: isShort
                          ? _buildBulletSchedule(
                              title: event.title,
                              timeRange: timeRange,
                              bulletColor: _getEventTypeColor(event.eventType, primaryColor),
                              isDark: isDark,
                            )
                          : _buildCardSchedule(
                              title: event.title,
                              timeRange: timeRange,
                              location: event.location ?? '未指定地點',
                              tag: displayTag,
                              cardColor: _getEventTypeBgColor(event.eventType, isDark),
                              borderColor: _getEventTypeColor(event.eventType, primaryColor),
                              accentColor: _getEventTypeColor(event.eventType, primaryColor),
                              isDark: isDark,
                            ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_TimelineEventLayout> _computeTimelineLayouts(
      List<ScheduleEvent> events, DateTime dayStart, DateTime dayEnd) {
    if (events.isEmpty) return [];

    final dayEvents = events.where((e) {
      final DateTime effectiveEnd = (e.endAt.hour == 0 && e.endAt.minute == 0 && e.endAt.second == 0 && e.endAt.isAfter(e.startAt))
          ? e.endAt.subtract(const Duration(seconds: 1))
          : e.endAt;
      return !e.startAt.isAfter(dayEnd) && !effectiveEnd.isBefore(dayStart);
    }).toList();

    dayEvents.sort((a, b) => a.startAt.compareTo(b.startAt));

    List<List<ScheduleEvent>> clusters = [];
    for (final event in dayEvents) {
      bool addedToCluster = false;
      for (final cluster in clusters) {
        bool overlapsAny = cluster.any((e) {
          final DateTime eEffEnd = (e.endAt.hour == 0 && e.endAt.minute == 0 && e.endAt.second == 0 && e.endAt.isAfter(e.startAt))
              ? e.endAt.subtract(const Duration(seconds: 1))
              : e.endAt;
          final DateTime eventEffEnd = (event.endAt.hour == 0 && event.endAt.minute == 0 && event.endAt.second == 0 && event.endAt.isAfter(event.startAt))
              ? event.endAt.subtract(const Duration(seconds: 1))
              : event.endAt;

          return event.startAt.isBefore(eEffEnd) && eventEffEnd.isAfter(e.startAt);
        });
        if (overlapsAny) {
          cluster.add(event);
          addedToCluster = true;
          break;
        }
      }
      if (!addedToCluster) {
        clusters.add([event]);
      }
    }

    List<_TimelineEventLayout> layouts = [];

    for (final cluster in clusters) {
      List<DateTime> colEndTimes = [];
      List<int> eventCols = [];

      for (final event in cluster) {
        int assignedCol = -1;
        for (int c = 0; c < colEndTimes.length; c++) {
          if (!event.startAt.isBefore(colEndTimes[c])) {
            assignedCol = c;
            colEndTimes[c] = event.endAt;
            break;
          }
        }
        if (assignedCol == -1) {
          assignedCol = colEndTimes.length;
          colEndTimes.add(event.endAt);
        }
        eventCols.add(assignedCol);
      }

      final int numCols = colEndTimes.length;

      for (int i = 0; i < cluster.length; i++) {
        layouts.add(_TimelineEventLayout(cluster[i], eventCols[i], numCols));
      }
    }

    return layouts;
  }

  Color _getEventTypeColor(String type, Color defaultColor) {
    switch (type) {
      case 'meeting':
        return Colors.orange;
      case 'visit':
        return Colors.blue;
      case 'reminder':
        return Colors.purple;
      case 'personal':
      default:
        return defaultColor;
    }
  }

  Color _getEventTypeBgColor(String type, bool isDark) {
    switch (type) {
      case 'meeting':
        return isDark ? const Color(0xFF7C2D12).withOpacity(0.5) : const Color(0xFFFFEDD5);
      case 'visit':
        return isDark ? const Color(0xFF1E3A8A).withOpacity(0.5) : const Color(0xFFDBEAFE);
      case 'reminder':
        return isDark ? const Color(0xFF581C87).withOpacity(0.5) : const Color(0xFFF3E8FF);
      case 'personal':
      default:
        return isDark ? const Color(0xFF1F2937).withOpacity(0.5) : const Color(0xFFF3F4F6);
    }
  }

  String _getLocalizedEventType(String type) {
    switch (type) {
      case 'meeting':
        return '會議談判';
      case 'visit':
        return '客戶拜訪';
      case 'reminder':
        return '客戶拜訪';
      case 'personal':
      default:
        return '個人行程';
    }
  }

  // Bullet Schedule Item (打卡點樣式)
  Widget _buildBulletSchedule({
    required String title,
    required String timeRange,
    required Color bulletColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22).withOpacity(0.8) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF30363D) : Colors.grey.shade300, width: 1),
      ),
      child: Row(
        children: [
          // Glowing bullet point
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: bulletColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bulletColor.withOpacity(0.8),
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ]
            ),
          ),
          const SizedBox(width: 12),
          Text(
            timeRange,
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Full Card Schedule Item (滿版卡片樣式 - 具備邊界防溢與內容自適應)
  Widget _buildCardSchedule({
    required String title,
    required String timeRange,
    required String location,
    required String tag,
    required Color cardColor,
    required Color borderColor,
    required Color accentColor,
    required bool isDark,
  }) {
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 13, color: subTextColor),
                    const SizedBox(width: 4),
                    Text(
                      timeRange,
                      style: TextStyle(color: subTextColor, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: borderColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (location.isNotEmpty && location != '未指定地點')
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 12, color: subTextColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(color: subTextColor, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Fallback Placeholder screen for non-calendar sections
  Widget _buildFallbackScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _activeMenu == '客戶管理' 
                ? Icons.people_outline 
                : _activeMenu == '人脈拓撲' 
                    ? Icons.hub_outlined 
                    : Icons.bar_chart_outlined,
            size: 64,
            color: primaryColor.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '$_activeMenu 功能骨架',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '目前處於 Phase 1，此畫面為選單骨架頁面。\n後續 Phase 將逐步刻劃並串接資料庫實作。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white30 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper to parse Base64 or Network URL image provider
ImageProvider? _getAvatarProvider(String avatarUrl) {
  if (avatarUrl.isEmpty) return null;
  if (avatarUrl.startsWith('data:image/') || avatarUrl.startsWith('data:application/')) {
    try {
      final base64String = avatarUrl.split(',').last;
      return MemoryImage(base64Decode(base64String));
    } catch (e) {
      return null;
    }
  }
  return NetworkImage(avatarUrl);
}

class _TimelineEventLayout {
  final ScheduleEvent event;
  final int colIndex;
  final int totalCols;
  _TimelineEventLayout(this.event, this.colIndex, this.totalCols);
}

class _VoiceSchedulerFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isDark;
  final Color primaryColor;

  const _VoiceSchedulerFAB({
    Key? key,
    required this.onPressed,
    required this.isDark,
    required this.primaryColor,
  }) : super(key: key);

  @override
  State<_VoiceSchedulerFAB> createState() => _VoiceSchedulerFABState();
}

class _VoiceSchedulerFABState extends State<_VoiceSchedulerFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4.0, end: 16.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isDark) {
      return FloatingActionButton(
        onPressed: widget.onPressed,
        backgroundColor: widget.primaryColor.withOpacity(0.12),
        elevation: 0,
        highlightElevation: 2,
        hoverElevation: 1,
        shape: const CircleBorder(),
        child: Icon(
          Icons.mic,
          color: widget.primaryColor,
          size: 28,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withOpacity(0.35),
                blurRadius: _glowAnimation.value,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: FloatingActionButton(
        onPressed: widget.onPressed,
        backgroundColor: const Color(0xFF161B22),
        elevation: 4,
        shape: CircleBorder(
          side: BorderSide(color: widget.primaryColor.withOpacity(0.3), width: 1),
        ),
        child: Icon(
          Icons.mic,
          color: widget.primaryColor,
          size: 28,
        ),
      ),
    );
  }
}

