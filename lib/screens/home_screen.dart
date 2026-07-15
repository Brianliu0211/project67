import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'login_screen.dart';
import 'customer_management_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime(2026, 7, 8); // Default to current mock time July 8, 2026
  String _activeMenu = '今日行程';
  bool _isSidebarCollapsed = false;

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
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00ADB5),
              onPrimary: Colors.white,
              surface: Color(0xFF161B22),
              onSurface: Colors.white,
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
    // Find the Monday of the week containing the date
    final int daysFromMonday = date.weekday - 1;
    final DateTime monday = date.subtract(Duration(days: daysFromMonday));
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= 768;

    // Sidebar navigation content
    Widget sidebarContent() {
      return Container(
        color: const Color(0xFF161B22),
        width: _isSidebarCollapsed ? 70 : 260,
        child: Column(
          children: [
            // Header Profile Area
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF21262D), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF00ADB5),
                    radius: 20,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  if (!_isSidebarCollapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '王大同 業務代表',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isOfflineMode ? '離線模式' : '已連線 (Supabase)',
                            style: TextStyle(
                              color: isOfflineMode ? Colors.amber : Colors.green,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _buildSidebarItem(Icons.calendar_today_outlined, '今日行程'),
                  _buildSidebarItem(Icons.people_outline, '客戶管理'),
                  _buildSidebarItem(Icons.hub_outlined, '人脈拓撲'),
                  _buildSidebarItem(Icons.bar_chart_outlined, '數據戰情'),
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
                  color: Colors.white54,
                ),
              ),

            // Sign out button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF21262D), width: 1),
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
              backgroundColor: const Color(0xFF161B22),
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
                if (isWideScreen) _buildWebHeader(),
                
                // Weekly Calendar Strip
                if (_activeMenu == '今日行程') _buildWeeklyCalendarStrip(),
                
                // Main Working Area
                Expanded(
                  child: _activeMenu == '今日行程'
                      ? _buildScheduleTimeline()
                      : _activeMenu == '客戶管理'
                          ? const CustomerManagementTab()
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
  Widget _buildSidebarItem(IconData icon, String title) {
    final bool isActive = _activeMenu == title;
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
            color: isActive ? const Color(0xFF00ADB5).withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: _isSidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF00F5FF) : Colors.white70,
                size: 20,
              ),
              if (!_isSidebarCollapsed) ...[
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
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
  Widget _buildWebHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: const Color(0xFF0D1117),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _activeMenu,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
              const Text(
                '保險客戶管理助手 v1.0.0',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          )
        ],
      ),
    );
  }

  // Horizontal Weekly Calendar Strip
  Widget _buildWeeklyCalendarStrip() {
    final List<DateTime> weekDates = _getWeekDates(_selectedDate);
    final List<String> weekdaysZh = ['一', '二', '三', '四', '五', '六', '日'];
    
    final String monthString = '${_selectedDate.year}年${_selectedDate.month}月';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(
          bottom: BorderSide(color: Color(0xFF21262D), width: 1),
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF00ADB5), size: 24),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Weekly Row
          Row(
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
                          ? const Color(0xFF00ADB5) 
                          : isToday 
                              ? const Color(0xFF00ADB5).withOpacity(0.1) 
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isToday && !isSelected
                          ? Border.all(color: const Color(0xFF00ADB5), width: 1)
                          : Border.all(color: Colors.transparent),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00ADB5).withOpacity(0.4),
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
                            color: isSelected ? Colors.white : Colors.white38,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white,
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
          )
        ],
      ),
    );
  }

  // Vertical Day Timeline Schedule
  Widget _buildScheduleTimeline() {
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
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    
                    // Divider line
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Divider(
                          color: Color(0xFF21262D),
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

          // Custom Schedule Cards overlays
          // Note: Timeline height starts from 06:00. Height of 1 hour is 60px.
          // Position = (Hour - 6) * 60 + (Minute/60) * 60
          
          // Card 1: 09:00 - 10:00: 「穿黑色衣服」（打卡點圓圈樣式）
          // Position top: (9 - 6) * 60 = 180px. Height: 60px.
          Positioned(
            top: 180 + 8,
            left: 70,
            right: 0,
            height: 48,
            child: _buildBulletSchedule(
              title: '穿黑色衣服',
              timeRange: '09:00 - 10:00',
              bulletColor: const Color(0xFF00ADB5),
            ),
          ),

          // Card 2: 14:30 - 17:30: 「服學 正式活動」（滿版背景藍色卡片樣式）
          // Position top: (14.5 - 6) * 60 = 8.5 * 60 = 510px.
          // Height: 3 hours = 180px.
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
              cardColor: const Color(0xFF1E3A8A).withOpacity(0.6), // Solid dark blue
              borderColor: const Color(0xFF2563EB), // Blue border
              accentColor: const Color(0xFF00F5FF), // Ice Blue accent
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D), width: 1),
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
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
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
  }) {
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
                  const Icon(Icons.access_time, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    timeRange,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Colors.white38),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
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
            color: const Color(0xFF00ADB5).withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '$_activeMenu 功能骨架',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '目前處於 Phase 1，此畫面為選單骨架頁面。\n後續 Phase 將逐步刻劃並串接資料庫實作。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white30,
            ),
          ),
        ],
      ),
    );
  }
}
