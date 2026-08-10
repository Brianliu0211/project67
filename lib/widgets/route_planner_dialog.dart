import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/schedule_event.dart';
import 'custom_toast.dart';

class RoutePlannerDialog extends StatefulWidget {
  final DateTime selectedDate;
  final List<ScheduleEvent> events;

  const RoutePlannerDialog({
    super.key,
    required this.selectedDate,
    required this.events,
  });

  @override
  State<RoutePlannerDialog> createState() => _RoutePlannerDialogState();
}

class _RoutePlannerDialogState extends State<RoutePlannerDialog> {
  late List<ScheduleEvent> _validEvents;
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    // 篩選當日有填寫地點的行程，並按開始時間順序排序
    _validEvents = widget.events
        .where((e) => e.location != null && e.location!.trim().isNotEmpty)
        .toList();
    _validEvents.sort((a, b) => a.startAt.compareTo(b.startAt));

    // 預設全選所有包含地點的行程
    _selectedIds = _validEvents.map((e) => e.id).toSet();
  }

  void _toggleSelectAll(bool selectAll) {
    setState(() {
      if (selectAll) {
        _selectedIds = _validEvents.map((e) => e.id).toSet();
      } else {
        _selectedIds.clear();
      }
    });
  }

  Future<void> _launchGoogleMapsNavigation() async {
    final selectedEvents = _validEvents.where((e) => _selectedIds.contains(e.id)).toList();

    if (selectedEvents.isEmpty) {
      CustomToast.show(context, '請至少勾選 1 個有地點的行程進行導航', ToastType.warning);
      return;
    }

    String getLocStr(ScheduleEvent e) {
      if (e.latitude != null && e.longitude != null) {
        return '${e.latitude},${e.longitude}';
      }
      return Uri.encodeComponent(e.location!);
    }

    String url;
    if (selectedEvents.length == 1) {
      // 1 個地點：起點自動為使用者「目前位置」，導航至該選定地點
      final destStr = getLocStr(selectedEvents.first);
      url = 'https://www.google.com/maps/dir/?api=1&destination=$destStr&travelmode=driving';
    } else {
      // 2 個以上地點：起點自動為使用者「目前位置」，將前 N-1 個行程作為 Waypoints，最後 1 個行程作為 Destination
      final destEv = selectedEvents.last;
      final waypointsEv = selectedEvents.sublist(0, selectedEvents.length - 1);

      final destStr = getLocStr(destEv);
      final waypointsStr = waypointsEv.map((e) => getLocStr(e)).join('|');

      url = 'https://www.google.com/maps/dir/?api=1&destination=$destStr&waypoints=$waypointsStr&travelmode=driving';
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        CustomToast.show(context, '無法開啟 Google Maps 連結', ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final dateStr = DateFormat('yyyy年MM月dd日', 'zh_TW').format(widget.selectedDate);
    final dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.alt_route, color: primaryColor, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '行程路線規劃 ($dateStr)',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '起點自動為目前位置。勾選要前往的地點，將依時間順序自動在 Google Maps 規劃多站駕駛路線：',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 12),

              // Select All / Deselect All Bar
              Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: primaryColor),
                    icon: const Icon(Icons.select_all, size: 16),
                    label: const Text('全選'),
                    onPressed: () => _toggleSelectAll(true),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: isDark ? Colors.white70 : Colors.black54),
                    icon: const Icon(Icons.deselect, size: 16),
                    label: const Text('全不選'),
                    onPressed: () => _toggleSelectAll(false),
                  ),
                  const Spacer(),
                  Text(
                    '已選擇 ${_selectedIds.length} / ${_validEvents.length} 站',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                ],
              ),
              Divider(color: isDark ? const Color(0xFF30363D) : Colors.grey.shade300),

              // Event Checkbox List
              if (_validEvents.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text('今日尚無任何包含地點的行程記錄', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _validEvents.length,
                    itemBuilder: (ctx, index) {
                      final event = _validEvents[index];
                      final isSelected = _selectedIds.contains(event.id);
                      final orderNum = index + 1;

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(event.id);
                            } else {
                              _selectedIds.remove(event.id);
                            }
                          });
                        },
                        secondary: CircleAvatar(
                          radius: 12,
                          backgroundColor: isSelected ? primaryColor : Colors.grey,
                          child: Text('$orderNum', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(
                          '${DateFormat('HH:mm').format(event.startAt)} ${event.title}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '📍 ${event.location}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        activeColor: primaryColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        dense: true,
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _validEvents.isEmpty ? null : _launchGoogleMapsNavigation,
                    icon: const Icon(Icons.navigation, color: Colors.white, size: 18),
                    label: const Text('開啟 Google 地圖導航 (免費)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
