import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule_event.dart';
import '../main.dart';
import '../services/app_settings.dart';
import '../services/app_localizations.dart';

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
  String _calendarViewMode = 'timeline';
  List<ScheduleEvent> _events = [];
  bool _isLoadingEvents = false;

  @override
  void initState() {
    super.initState();
    _fetchEventsForSelectedDate();
  }

  Future<void> _fetchEventsForSelectedDate({bool silent = false}) async {
    if (isOfflineMode) {
      if (!silent && mounted) {
        // CustomToast.show(context, '目前為離線預覽模式，無法讀取真實行程資料。', ToastType.warning);
      }
      setState(() {
        _events = [];
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
          rangeStart = DateTime(_selectedDate.year, _selectedDate.month, 1, 0, 0, 0).subtract(const Duration(days: 7)).toUtc();
          rangeEnd = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59).add(const Duration(days: 7)).toUtc();
        } else {
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

        final events = (data as List).map((json) => ScheduleEvent.fromJson(json)).toList();

        if (mounted) {
          setState(() {
            _events = events;
            _isLoadingEvents = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEvents = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('行程管理開發中'),
    );
  }
}
