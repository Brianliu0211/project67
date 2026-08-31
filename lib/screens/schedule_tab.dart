import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/schedule_event.dart';
import '../main.dart';
import '../services/schedule_service.dart';
import '../services/app_localizations.dart';
import '../widgets/custom_toast.dart';
import '../widgets/schedule_event_dialog.dart';
import '../widgets/route_planner_dialog.dart';

class ScheduleTab extends StatefulWidget {
  final bool isWideScreen;
  final bool isDark;
  final Color primaryColor;
  final Function(String) onMenuChanged;

  const ScheduleTab({
    super.key,
    required this.isWideScreen,
    required this.isDark,
    required this.primaryColor,
    required this.onMenuChanged,
  });

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  DateTime _selectedDate = DateTime.now();
  String _viewMode = 'month_grid'; // 'month_grid', 'timeline', 'agenda'

  List<ScheduleEvent> _events = [];
  bool _isLoading = false;
  Map<String, Map<String, dynamic>> _customerMap = {};

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _fetchEvents();

    // 監聽行程變更通知
    ScheduleService.instance.eventsRevision.addListener(_onEventsChanged);
  }

  @override
  void dispose() {
    ScheduleService.instance.eventsRevision.removeListener(_onEventsChanged);
    super.dispose();
  }

  void _onEventsChanged() {
    if (mounted) {
      _fetchEvents(silent: true);
    }
  }

  User? get _currentUser {
    if (isOfflineMode) return null;
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadCustomers() async {
    try {
      final user = _currentUser;
      List<Map<String, dynamic>> rawList = [];
      if (isOfflineMode || user == null) {
        rawList = List<Map<String, dynamic>>.from(OfflineDataStore.customers);
      } else {
        final data = await Supabase.instance.client
            .from('customers')
            .select('id, name, phone, tags, custom_attributes')
            .isFilter('deleted_at', null);
        rawList = List<Map<String, dynamic>>.from(data as List);
      }
      final map = <String, Map<String, dynamic>>{};
      for (final c in rawList) {
        final id = c['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          map[id] = c;
        }
      }
      if (mounted) {
        setState(() => _customerMap = map);
      }
    } catch (e) {
      debugPrint('⚠️ 載入客戶映射表失敗: $e');
    }
  }

  Future<void> _fetchEvents({bool silent = false}) async {
    if (!silent && _events.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      DateTime rangeStart;
      DateTime rangeEnd;

      if (_viewMode == 'month_grid') {
        // 月視圖：抓取前後一個月擴充範圍
        rangeStart = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
        rangeEnd = DateTime(_selectedDate.year, _selectedDate.month + 2, 0, 23, 59, 59);
      } else if (_viewMode == 'timeline') {
        // 日時間軸：抓取當日
        rangeStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
        rangeEnd = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
      } else {
        // 議程清單：抓取前後 60 天
        rangeStart = DateTime.now().subtract(const Duration(days: 30));
        rangeEnd = DateTime.now().add(const Duration(days: 60));
      }

      final events = await ScheduleService.instance.fetchEvents(
        start: rangeStart,
        end: rangeEnd,
        silent: silent,
      );

      if (mounted) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<ScheduleEvent> get _eventsForSelectedDate {
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _events.where((e) {
      return e.startAt.isBefore(endOfDay) && e.endAt.isAfter(startOfDay);
    }).toList();
  }

  Color _getTagColor(String? tag) {
    if (tag == null || tag.isEmpty) return const Color(0xFF0284C7);
    final hash = tag.codeUnits.fold(0, (prev, elem) => prev + elem);
    final hue = (hash * 37) % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.65, 0.50).toColor();
  }

  Future<void> _openAddEventDialog([ScheduleEvent? eventToEdit]) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => ScheduleEventDialog(
        initialDate: _selectedDate,
        eventToEdit: eventToEdit,
      ),
    );

    if (result != null) {
      _fetchEvents();
    }
  }

  void _openRoutePlanner() {
    final dayEvents = _eventsForSelectedDate;
    if (dayEvents.isEmpty) {
      CustomToast.show(context, '當日尚無行程可規劃路線', ToastType.warning);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => RoutePlannerDialog(
        selectedDate: _selectedDate,
        events: dayEvents,
      ),
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        CustomToast.show(context, '無法發起電話通話: $phone', ToastType.warning);
      }
    }
  }

  Future<void> _openMapNavigation(String location, double? lat, double? lng) async {
    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        CustomToast.show(context, '無法開啟地圖導航', ToastType.warning);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryColor = widget.primaryColor;
    final bgColor = isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // 頂部全域工具列 (Top Action Header)
          _buildTopHeader(isDark, primaryColor, cardBg, borderColor),

          // 主畫面內容區 (Main Content Area based on viewMode)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMainView(isDark, primaryColor, cardBg, borderColor),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 76.0),
        child: FloatingActionButton.extended(
          heroTag: 'schedule_tab_add_fab',
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_task),
          label: const Text('新增行程', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => _openAddEventDialog(),
        ),
      ),
    );
  }

  // 頂部工具列
  Widget _buildTopHeader(bool isDark, Color primaryColor, Color cardBg, Color borderColor) {
    final isWide = widget.isWideScreen;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // 1. 日期導航器
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: '上一週期',
                onPressed: () {
                  setState(() {
                    if (_viewMode == 'month_grid') {
                      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, _selectedDate.day);
                    } else if (_viewMode == 'timeline') {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                    } else {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 7));
                    }
                  });
                  _fetchEvents();
                },
              ),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _fetchEvents();
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        _viewMode == 'month_grid'
                            ? DateFormat('yyyy 年 MM 月').format(_selectedDate)
                            : DateFormat('yyyy 年 MM 月 dd 日 (E)', 'zh_TW').format(_selectedDate),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: '下一週期',
                onPressed: () {
                  setState(() {
                    if (_viewMode == 'month_grid') {
                      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, _selectedDate.day);
                    } else if (_viewMode == 'timeline') {
                      _selectedDate = _selectedDate.add(const Duration(days: 1));
                    } else {
                      _selectedDate = _selectedDate.add(const Duration(days: 7));
                    }
                  });
                  _fetchEvents();
                },
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(50, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  setState(() => _selectedDate = DateTime.now());
                  _fetchEvents();
                },
                child: const Text('今天', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          // 2. 視圖模式切換器 (Segmented Control)
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewModeButton('month_grid', Icons.grid_view_rounded, '月曆網格', primaryColor, isDark),
                _buildViewModeButton('timeline', Icons.view_timeline_rounded, '日時間軸', primaryColor, isDark),
                _buildViewModeButton('agenda', Icons.view_agenda_outlined, '議程清單', primaryColor, isDark),
              ],
            ),
          ),

          // 3. 快捷操作按鈕群 (路線規劃 / Google 日曆同步 / 新增)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _openRoutePlanner,
                icon: const Icon(Icons.alt_route, size: 16, color: Color(0xFF0284C7)),
                label: const Text('路線導航', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  CustomToast.show(
                    context,
                    'Google 日曆雙向同步功能已就緒，即將於 Phase 2 自動串接！',
                    ToastType.success,
                  );
                },
                icon: const Icon(Icons.sync, size: 16, color: Color(0xFF10B981)),
                label: const Text('Google 日曆', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(String mode, IconData icon, String label, Color primaryColor, bool isDark) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () {
        setState(() => _viewMode = mode);
        _fetchEvents();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 主畫面內容分流
  Widget _buildMainView(bool isDark, Color primaryColor, Color cardBg, Color borderColor) {
    switch (_viewMode) {
      case 'month_grid':
        return _buildMonthGridView(isDark, primaryColor, cardBg, borderColor);
      case 'timeline':
        return _buildTimelineView(isDark, primaryColor, cardBg, borderColor);
      case 'agenda':
      default:
        return _buildAgendaListView(isDark, primaryColor, cardBg, borderColor);
    }
  }

  // 1. 月曆網格視圖 (Month Grid View)
  Widget _buildMonthGridView(bool isDark, Color primaryColor, Color cardBg, Color borderColor) {
    final isWide = widget.isWideScreen;

    final gridWidget = Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 星期表頭 (Mon - Sun)
          Row(
            children: const [
              Expanded(child: Center(child: Text('一', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
              Expanded(child: Center(child: Text('二', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
              Expanded(child: Center(child: Text('三', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
              Expanded(child: Center(child: Text('四', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
              Expanded(child: Center(child: Text('五', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
              Expanded(child: Center(child: Text('六', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent)))),
              Expanded(child: Center(child: Text('日', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent)))),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // 日期格子清單
          Expanded(
            child: _buildMonthDaysGrid(isDark, primaryColor, cardBg, borderColor),
          ),
        ],
      ),
    );

    final selectedEventsWidget = Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(left: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.event_note, size: 18, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${DateFormat('MM/dd (E)', 'zh_TW').format(_selectedDate)} 行程 (${_eventsForSelectedDate.length})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF10B981)),
                  tooltip: '在此日新增行程',
                  onPressed: () => _openAddEventDialog(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _eventsForSelectedDate.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available, size: 48, color: isDark ? Colors.white24 : Colors.black12),
                        const SizedBox(height: 8),
                        Text('當日尚無行程', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _openAddEventDialog(),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('立即新增'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _eventsForSelectedDate.length,
                    itemBuilder: (context, idx) {
                      return _buildEventCard(_eventsForSelectedDate[idx], isDark, primaryColor, cardBg, borderColor);
                    },
                  ),
          ),
        ],
      ),
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(flex: 65, child: gridWidget),
          Expanded(flex: 35, child: selectedEventsWidget),
        ],
      );
    } else {
      return Column(
        children: [
          Expanded(flex: 55, child: gridWidget),
          Expanded(flex: 45, child: selectedEventsWidget),
        ],
      );
    }
  }

  Widget _buildMonthDaysGrid(bool isDark, Color primaryColor, Color cardBg, Color borderColor) {
    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

    // 計算前面補幾個前一個月的格子 (Monday is 1, Sunday is 7)
    final leadingPadding = (firstDayOfMonth.weekday - 1) % 7;
    final totalDays = lastDayOfMonth.day;
    final totalSlots = ((leadingPadding + totalDays + 6) ~/ 7) * 7;

    final now = DateTime.now();

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.1,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: totalSlots,
      itemBuilder: (context, index) {
        final dayOffset = index - leadingPadding + 1;
        final isCurrentMonth = dayOffset >= 1 && dayOffset <= totalDays;

        DateTime slotDate;
        if (dayOffset < 1) {
          slotDate = DateTime(_selectedDate.year, _selectedDate.month, dayOffset);
        } else if (dayOffset > totalDays) {
          slotDate = DateTime(_selectedDate.year, _selectedDate.month + 1, dayOffset - totalDays);
        } else {
          slotDate = DateTime(_selectedDate.year, _selectedDate.month, dayOffset);
        }

        final isToday = slotDate.year == now.year && slotDate.month == now.month && slotDate.day == now.day;
        final isSelected = slotDate.year == _selectedDate.year && slotDate.month == _selectedDate.month && slotDate.day == _selectedDate.day;

        // 計算該日行程
        final dayStart = DateTime(slotDate.year, slotDate.month, slotDate.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        final dayEvents = _events.where((e) => e.startAt.isBefore(dayEnd) && e.endAt.isAfter(dayStart)).toList();

        return InkWell(
          onTap: () {
            setState(() => _selectedDate = slotDate);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withValues(alpha: 0.15)
                  : (isToday ? const Color(0xFF10B981).withValues(alpha: 0.08) : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? primaryColor
                    : (isToday ? const Color(0xFF10B981) : Colors.transparent),
                width: isSelected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day number
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${slotDate.day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isCurrentMonth
                            ? (isToday
                                ? const Color(0xFF10B981)
                                : (isDark ? Colors.white : Colors.black87))
                            : (isDark ? Colors.white30 : Colors.black26),
                      ),
                    ),
                    if (dayEvents.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${dayEvents.length}',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),

                // Event dots / Mini titles
                Expanded(
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dayEvents.length > 2 ? 2 : dayEvents.length,
                    itemBuilder: (ctx, i) {
                      final ev = dayEvents[i];
                      final tagColor = _getTagColor(ev.tag);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                        decoration: BoxDecoration(
                          color: tagColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: tagColor.withValues(alpha: 0.5), width: 0.5),
                        ),
                        child: Text(
                          ev.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                            decoration: ev.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 2. 日時間軸視圖 (Day Timeline View)
  Widget _buildTimelineView(bool isDark, Color primaryColor, Color cardBg, Color borderColor) {
    final dayEvents = _eventsForSelectedDate;

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // Top Info Badge
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.today, size: 20, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('yyyy 年 MM 月 dd 日 (EEEE)', 'zh_TW').format(_selectedDate),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Text(
                        '今日共 ${dayEvents.length} 個排程項目',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 24-hour timeline slots (07:00 to 22:00)
                ...List.generate(16, (index) {
                  final hour = index + 7;
                  final hourStr = '${hour.toString().padLeft(2, '0')}:00';
                  final slotStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, 0);
                  final slotEnd = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour + 1, 0);

                  final slotEvents = dayEvents.where((e) {
                    return e.startAt.isBefore(slotEnd) && e.endAt.isAfter(slotStart);
                  }).toList();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hour Label
                        SizedBox(
                          width: 50,
                          child: Text(
                            hourStr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ),
                        // Timeline Line
                        Container(
                          width: 2,
                          height: slotEvents.isEmpty ? 40 : null,
                          color: borderColor,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        // Event Card Content
                        Expanded(
                          child: slotEvents.isEmpty
                              ? InkWell(
                                  onTap: () {
                                    final customDate = DateTime(
                                      _selectedDate.year,
                                      _selectedDate.month,
                                      _selectedDate.day,
                                      hour,
                                      0,
                                    );
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => ScheduleEventDialog(
                                        initialDate: customDate,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: borderColor.withValues(alpha: 0.4), style: BorderStyle.solid),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '＋ 點擊於 $hourStr 排入行程',
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white24 : Colors.black26),
                                    ),
                                  ),
                                )
                              : Column(
                                  children: slotEvents.map((ev) {
                                    return _buildEventCard(ev, isDark, primaryColor, cardBg, borderColor);
                                  }).toList(),
                                ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 3. 議程清單視圖 (Agenda List View)
  Widget _buildAgendaListView(bool isDark, Color primaryColor, Color cardBg, Color borderColor) {
    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 64, color: isDark ? Colors.white24 : Colors.black12),
            const SizedBox(height: 12),
            Text('目前無排程項目', style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _openAddEventDialog(),
              icon: const Icon(Icons.add),
              label: const Text('新增第一筆行程'),
            ),
          ],
        ),
      );
    }

    // 按日期分組 (Group by Date)
    final Map<String, List<ScheduleEvent>> grouped = {};
    for (final e in _events) {
      final dateKey = DateFormat('yyyy/MM/dd (E)', 'zh_TW').format(e.startAt);
      grouped.putIfAbsent(dateKey, () => []).add(e);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final dateKey = grouped.keys.elementAt(index);
        final eventsInGroup = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 14, color: primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    dateKey,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                ],
              ),
            ),
            // Events in this date
            ...eventsInGroup.map((ev) {
              return _buildEventCard(ev, isDark, primaryColor, cardBg, borderColor);
            }),
          ],
        );
      },
    );
  }

  // 通用精緻行程卡片組件
  Widget _buildEventCard(
    ScheduleEvent event,
    bool isDark,
    Color primaryColor,
    Color cardBg,
    Color borderColor,
  ) {
    final tagColor = _getTagColor(event.tag);
    final customer = event.customerId != null ? _customerMap[event.customerId] : null;
    final customerName = customer?['name']?.toString();
    final customerPhone = customer?['phone']?.toString();

    final timeStr = '${DateFormat('HH:mm').format(event.startAt)} - ${DateFormat('HH:mm').format(event.endAt)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: event.isCompleted
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openAddEventDialog(event),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Complete Checkbox, Title, Tag & Sync Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Checkbox
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: event.isCompleted,
                        activeColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        onChanged: (val) async {
                          if (val != null) {
                            await ScheduleService.instance.toggleComplete(event.id, val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Title
                    Expanded(
                      child: Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                          color: event.isCompleted
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),

                    // Tag Badge
                    if (event.tag != null && event.tag!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tagColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: tagColor.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: Text(
                          event.tag!,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tagColor),
                        ),
                      ),

                    // Google Sync Icon
                    if (event.isGoogleSynced) ...[
                      const SizedBox(width: 6),
                      const Tooltip(
                        message: '已同步至 Google 日曆',
                        child: Icon(Icons.cloud_done, size: 16, color: Color(0xFF10B981)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Middle Info Row: Time & Customer
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    // Time range
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 14, color: isDark ? Colors.white60 : Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          timeStr,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                        ),
                      ],
                    ),

                    // Linked Customer Badge
                    if (customerName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, size: 12, color: Color(0xFF0284C7)),
                            const SizedBox(width: 4),
                            Text(
                              customerName,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // Location Row (if any)
                if (event.location != null && event.location!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Description (if any)
                if (event.description != null && event.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    event.description!,
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Bottom Action Buttons: Phone Call & Navigation
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (customerPhone != null && customerPhone.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.phone, size: 18, color: Color(0xFF10B981)),
                        tooltip: '撥打給 $customerName ($customerPhone)',
                        onPressed: () => _makePhoneCall(customerPhone),
                      ),
                    if (event.location != null && event.location!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.directions, size: 18, color: Color(0xFF0284C7)),
                        tooltip: '開啟地圖導航',
                        onPressed: () => _openMapNavigation(event.location!, event.latitude, event.longitude),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: '編輯行程',
                      onPressed: () => _openAddEventDialog(event),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
