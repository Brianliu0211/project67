import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/schedule_event.dart';
import '../services/app_localizations.dart';
import '../services/location_service.dart';
import 'custom_toast.dart';
import '../main.dart';
import 'categorized_tag_accordion_selector.dart';

class ScheduleEventDialog extends StatefulWidget {
  final DateTime initialDate;
  final ScheduleEvent? eventToEdit;

  const ScheduleEventDialog({
    super.key,
    required this.initialDate,
    this.eventToEdit,
  });

  @override
  State<ScheduleEventDialog> createState() => _ScheduleEventDialogState();
}

class _ScheduleEventDialogState extends State<ScheduleEventDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _tagController;
  final TextEditingController _mapSearchController = TextEditingController();

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;

  double? _selectedLat;
  double? _selectedLng;
  bool _isMapExpanded = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isSearchingPlace = false;

  List<PlaceSearchResult> _searchResults = [];
  final MapController _mapController = MapController();

  // 預設台北 101
  static const LatLng _defaultCenter = LatLng(25.0330, 121.5654);

  @override
  void initState() {
    super.initState();
    final event = widget.eventToEdit;

    if (event != null) {
      _titleController = TextEditingController(text: event.title);
      _locationController = TextEditingController(text: event.location ?? '');
      _tagController = TextEditingController(text: event.tag ?? '');
      _startDate = event.startAt;
      _startTime = TimeOfDay.fromDateTime(event.startAt);
      _endDate = event.endAt;
      _endTime = TimeOfDay.fromDateTime(event.endAt);
      _selectedLat = event.latitude;
      _selectedLng = event.longitude;
    } else {
      _titleController = TextEditingController();
      _locationController = TextEditingController();
      _tagController = TextEditingController();
      
      final now = DateTime.now();
      _startDate = DateTime(
        widget.initialDate.year,
        widget.initialDate.month,
        widget.initialDate.day,
        now.hour + 1 > 23 ? 23 : now.hour + 1,
        0,
      );
      _startTime = TimeOfDay(hour: _startDate.hour, minute: 0);
      
      _endDate = _startDate.add(const Duration(hours: 1));
      _endTime = TimeOfDay(hour: _endDate.hour, minute: 0);

      // 自動初始化使用者定位
      LocationService.getCurrentUserLocation().then((loc) {
        if (mounted && loc != null && _selectedLat == null && _selectedLng == null) {
          setState(() {
            _selectedLat = loc['latitude'];
            _selectedLng = loc['longitude'];
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _tagController.dispose();
    _mapSearchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearchingPlace = true);
    try {
      final results = await LocationService.searchPlaces(
        query,
        userLat: _selectedLat ?? _defaultCenter.latitude,
        userLng: _selectedLng ?? _defaultCenter.longitude,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
        if (results.isNotEmpty) {
          final first = results.first;
          _mapController.move(LatLng(first.latitude, first.longitude), 15);
        }
      }
    } finally {
      if (mounted) setState(() => _isSearchingPlace = false);
    }
  }

  void _selectSearchResult(PlaceSearchResult item) {
    setState(() {
      _selectedLat = item.latitude;
      _selectedLng = item.longitude;
      _locationController.text = item.displayName;
      _searchResults = [];
      _mapSearchController.text = _locationController.text;
    });
    _mapController.move(LatLng(item.latitude, item.longitude), 16);
  }

  Future<void> _onMapTap(LatLng point) async {
    setState(() {
      _selectedLat = point.latitude;
      _selectedLng = point.longitude;
    });
    // 逆向地理編碼取得完整中文名稱
    final addr = await LocationService.reverseGeocode(point.latitude, point.longitude);
    if (mounted && addr != null && addr.isNotEmpty) {
      setState(() {
        _locationController.text = addr;
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (endDateTime.isBefore(startDateTime)) {
      CustomToast.show(context, '結束時間不能早於開始時間', ToastType.warning);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profileId = user?.id ?? 'offline-user';

      final eventData = <String, dynamic>{
        'profile_id': profileId,
        'title': _titleController.text.trim(),
        'start_at': startDateTime.toUtc().toIso8601String(),
        'end_at': endDateTime.toUtc().toIso8601String(),
        'location': _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        'latitude': _selectedLat,
        'longitude': _selectedLng,
        'tag': _tagController.text.trim().isEmpty ? null : _tagController.text.trim(),
        'event_type': 'personal',
      };

      if (!isOfflineMode && user != null) {
        try {
          if (widget.eventToEdit != null) {
            await Supabase.instance.client
                .from('schedule_events')
                .update(eventData)
                .eq('id', widget.eventToEdit!.id);
          } else {
            await Supabase.instance.client
                .from('schedule_events')
                .insert(eventData);
          }
        } catch (dbErr) {
          final errStr = dbErr.toString();
          // 若線上資料庫尚未套用 latitude/longitude 欄位 (PGRST204)，則備援寫入純文字地址
          if (errStr.contains('latitude') || errStr.contains('PGRST204')) {
            eventData.remove('latitude');
            eventData.remove('longitude');
            if (widget.eventToEdit != null) {
              await Supabase.instance.client
                  .from('schedule_events')
                  .update(eventData)
                  .eq('id', widget.eventToEdit!.id);
            } else {
              await Supabase.instance.client
                  .from('schedule_events')
                  .insert(eventData);
            }
            if (mounted) {
              CustomToast.show(context, '線上資料庫尚未擴充經緯度欄位，已自動相容儲存。', ToastType.warning);
            }
          } else {
            rethrow;
          }
        }
      }

      if (mounted) {
        final resultAction = widget.eventToEdit != null ? 'updated' : 'created';
        Navigator.of(context).pop(resultAction);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '儲存失敗：$e', ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteEvent() async {
    if (widget.eventToEdit == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除行程'),
        content: const Text('確定要刪除這筆行程嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      if (!isOfflineMode) {
        await Supabase.instance.client
            .from('schedule_events')
            .delete()
            .eq('id', widget.eventToEdit!.id);
      }

      if (mounted) {
        Navigator.of(context).pop('deleted');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '刪除失敗：$e', ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.eventToEdit != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentCenter = (_selectedLat != null && _selectedLng != null)
        ? LatLng(_selectedLat!, _selectedLng!)
        : _defaultCenter;

    Widget buildFormColumn() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEdit ? context.l10n('event_edit_title') : context.l10n('event_add_title'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Event Title Input
          TextFormField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _saveEvent(),
            decoration: InputDecoration(
              labelText: '${context.l10n('event_title_label')} *',
              hintText: context.l10n('event_title_hint'),
              prefixIcon: const Icon(Icons.event_note),
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            validator: (val) => (val == null || val.trim().isEmpty) ? context.l10n('event_title_hint') : null,
          ),
          const SizedBox(height: 16),

          // Date & Time Pickers (Start)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _startDate = picked;
                        if (_endDate.isBefore(_startDate)) {
                          _endDate = _startDate;
                        }
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.l10n('event_start_date'),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      prefixIcon: const Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(DateFormat('yyyy/MM/dd').format(_startDate)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _startTime,
                    );
                    if (picked != null) {
                      setState(() => _startTime = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.l10n('event_start_time'),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      prefixIcon: const Icon(Icons.access_time, size: 18),
                    ),
                    child: Text(_startTime.format(context)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Date & Time Pickers (End)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _endDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.l10n('event_end_date'),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      prefixIcon: const Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(DateFormat('yyyy/MM/dd').format(_endDate)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _endTime,
                    );
                    if (picked != null) {
                      setState(() => _endTime = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.l10n('event_end_time'),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      prefixIcon: const Icon(Icons.access_time, size: 18),
                    ),
                    child: Text(_endTime.format(context)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Location Input (with interactive map toggle icon)
          TextFormField(
            controller: _locationController,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _saveEvent(),
            decoration: InputDecoration(
              labelText: context.l10n('event_location_label'),
              hintText: context.l10n('event_location_hint'),
              prefixIcon: const Icon(Icons.location_on_outlined),
              suffixIcon: Tooltip(
                message: _isMapExpanded ? '收起地圖' : '展開地圖選點',
                child: IconButton(
                  icon: Icon(
                    _isMapExpanded ? Icons.map : Icons.map_outlined,
                    color: _isMapExpanded ? const Color(0xFF0284C7) : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isMapExpanded = !_isMapExpanded;
                    });
                  },
                ),
              ),
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          if (_selectedLat != null && _selectedLng != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.pin_drop, size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 4),
                Text(
                  '已定位經緯度: ${_selectedLat!.toStringAsFixed(4)}, ${_selectedLng!.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Dynamic Categorized Tag Selector
          CategorizedTagAccordionSelector(
            tagsController: _tagController,
            isDark: isDark,
            primaryColor: const Color(0xFF0369A1),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isEdit)
                TextButton.icon(
                  onPressed: _isDeleting ? null : _deleteEvent,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: Text(context.l10n('event_delete_btn'), style: const TextStyle(color: Colors.red)),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n('cancel')),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEdit ? context.l10n('profile_save_changes') : context.l10n('event_add_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      );
    }

    Widget buildMapColumn() {
      return Container(
        height: 480,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Map Top Search Bar
            Container(
              padding: const EdgeInsets.all(8),
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _mapSearchController,
                          decoration: InputDecoration(
                            hintText: '搜尋地點 (例: 星巴克, 台北車站)',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            suffixIcon: _isSearchingPlace
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.search, size: 20),
                                    onPressed: () => _performSearch(_mapSearchController.text),
                                  ),
                          ),
                          onSubmitted: (val) => _performSearch(val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: '在 Google 地圖中開啟',
                        icon: const Icon(Icons.open_in_new, color: Color(0xFF0284C7)),
                        onPressed: () => LocationService.openInGoogleMaps(
                          lat: _selectedLat,
                          lon: _selectedLng,
                          address: _locationController.text,
                        ),
                      ),
                    ],
                  ),
                  if (_searchResults.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: Container(
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (ctx, idx) {
                          final item = _searchResults[idx];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on, size: 18, color: Colors.redAccent),
                            title: Text(item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            onTap: () => _selectSearchResult(item),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Map View Area
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: currentCenter,
                      initialZoom: 14,
                      onTap: (tapPos, point) => _onMapTap(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.insurance_helper',
                      ),
                      if (_selectedLat != null && _selectedLng != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_selectedLat!, _selectedLng!),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'recenter_map',
                      onPressed: () {
                        if (_selectedLat != null && _selectedLng != null) {
                          _mapController.move(LatLng(_selectedLat!, _selectedLng!), 16);
                        } else {
                          _mapController.move(_defaultCenter, 14);
                        }
                      },
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: _isMapExpanded ? 960 : 480,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: _isMapExpanded
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: buildFormColumn()),
                        const SizedBox(width: 24),
                        Expanded(child: buildMapColumn()),
                      ],
                    )
                  : buildFormColumn(),
            ),
          ),
        ),
      ),
    );
  }
}
