import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../main.dart';
import '../services/app_settings.dart';
import 'login_screen.dart';
import 'customer_management_tab.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now(); // Default to dynamic current time
  String _activeMenu = '今日行程';
  bool _isSidebarCollapsed = false;
  String _userName = '載入中...';
  String _userEmail = '';
  String _userAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _isSidebarCollapsed = AppSettings.instance.isSidebarCollapsedByDefault;
    _loadUserProfile();
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
      return Container(
        color: sidebarBg,
        width: _isSidebarCollapsed ? 80 : 260,
        child: Column(
          children: [
            // Header Profile Area
            InkWell(
              onTap: () {
                setState(() {
                  _activeMenu = '個人帳號';
                });
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
                child: _isSidebarCollapsed
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
                  _buildSidebarItem(Icons.people_outline, '客戶管理', isDark, primaryColor),
                  _buildSidebarItem(Icons.hub_outlined, '人脈拓撲', isDark, primaryColor),
                  _buildSidebarItem(Icons.bar_chart_outlined, '數據戰情', isDark, primaryColor),
                  _buildSidebarItem(Icons.account_circle_outlined, '個人帳號', isDark, primaryColor),
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
                  });
                },
                icon: Icon(
                  _isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                  color: subTextColor,
                ),
              ),

            // Sign out button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: _isSidebarCollapsed
                  ? IconButton(
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      onPressed: _handleSignOut,
                    )
                  : Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: const Icon(Icons.logout, color: Colors.redAccent),
                        title: const Text('登出系統', style: TextStyle(color: Colors.redAccent)),
                        onTap: _handleSignOut,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: isWideScreen ? null : Drawer(child: sidebarContent()),
      appBar: isWideScreen
          ? null
          : AppBar(
              title: Text(_activeMenu),
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
                    child: const Text(
                      '離線預覽',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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
                
                // Weekly Calendar Strip
                if (_activeMenu == '今日行程') _buildWeeklyCalendarStrip(isDark, textColor, subTextColor, borderColor, primaryColor),
                
                // Main Working Area
                Expanded(
                  child: _activeMenu == '今日行程'
                      ? _buildScheduleTimeline()
                      : _activeMenu == '客戶管理'
                          ? const CustomerManagementTab()
                          : _activeMenu == '個人帳號'
                              ? ProfileScreen(onProfileUpdated: _loadUserProfile)
                              : _activeMenu == '系統設定'
                                  ? const SettingsScreen()
                                  : _buildFallbackScreen(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build sidebar item
  Widget _buildSidebarItem(IconData icon, String title, bool isDark, Color primaryColor) {
    final bool isActive = _activeMenu == title;
    final Color activeBg = primaryColor.withOpacity(0.15);
    final Color inactiveText = isDark ? Colors.white70 : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _activeMenu = title;
          });
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
            mainAxisAlignment: _isSidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isActive ? primaryColor : inactiveText,
                size: 20,
              ),
              if (!_isSidebarCollapsed) ...[
                const SizedBox(width: 16),
                Text(
                  title,
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
            _activeMenu,
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
                  child: const Row(
                    children: [
                      Icon(Icons.offline_bolt_outlined, size: 14, color: Colors.amber),
                      SizedBox(width: 6),
                      Text(
                        '離線預覽模式',
                        style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              Text(
                '保險客戶管理助手 v1.0.0',
                style: TextStyle(color: subTextColor, fontSize: 12),
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
    final List<String> weekdaysZh = ['一', '二', '三', '四', '五', '六', '日'];
    
    final String monthString = '${_selectedDate.year}年${_selectedDate.month}月';

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
                                weekdaysZh[index],
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

  // Vertical Day Timeline Schedule
  Widget _buildScheduleTimeline() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;
    final Color gridColor = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;
    final Color hourTextColor = isDark ? Colors.white30 : Colors.black45;

    // We display 06:00 to 22:00
    final List<int> hours = List.generate(17, (index) => index + 6);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
                    // Time text
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
                    
                    // Divider line
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

          // Card 1: 09:00 - 10:00: 「穿黑色衣服」（打卡點圓圈樣式）
          Positioned(
            top: 180 + 8,
            left: 70,
            right: 0,
            height: 48,
            child: _buildBulletSchedule(
              title: '穿黑色衣服',
              timeRange: '09:00 - 10:00',
              bulletColor: primaryColor,
              isDark: isDark,
            ),
          ),

          // Card 2: 14:30 - 17:30: 「服學 正式活動」（滿版背景藍色卡片樣式）
          Positioned(
            top: 510 + 8,
            left: 70,
            right: 0,
            height: 164,
            child: _buildCardSchedule(
              title: '服學 正式活動',
              timeRange: '14:30 - 17:30',
              location: '台大第一學生活動中心',
              tag: '服務學習',
              cardColor: isDark ? const Color(0xFF1E3A8A).withOpacity(0.6) : const Color(0xFFDBEAFE),
              borderColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF3B82F6),
              accentColor: isDark ? const Color(0xFF00F5FF) : const Color(0xFF1D4ED8),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
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

  // Full Card Schedule Item (滿版卡片樣式)
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: subTextColor),
                  const SizedBox(width: 6),
                  Text(
                    timeRange,
                    style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: borderColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tag,
                  style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: subTextColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location,
                  style: TextStyle(color: subTextColor, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        ],
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

