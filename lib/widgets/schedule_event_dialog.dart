import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/schedule_event.dart';
import '../services/app_localizations.dart';
import '../services/location_service.dart';
import '../services/schedule_service.dart';
import '../services/google_calendar_sync_service.dart';
import 'custom_toast.dart';
import '../main.dart';
import 'categorized_tag_accordion_selector.dart';

class ScheduleEventDialog extends StatefulWidget {
  final DateTime initialDate;
  final ScheduleEvent? eventToEdit;
  final String? initialTitle;
  final String? initialEventType;
  final String? initialCustomerId;

  const ScheduleEventDialog({
    super.key,
    required this.initialDate,
    this.eventToEdit,
    this.initialTitle,
    this.initialEventType,
    this.initialCustomerId,
  });

  @override
  State<ScheduleEventDialog> createState() => _ScheduleEventDialogState();
}

class _ScheduleEventDialogState extends State<ScheduleEventDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _tagController;
  late TextEditingController _descriptionController;
  final TextEditingController _mapSearchController = TextEditingController();

  String? _selectedCustomerId;
  List<Map<String, dynamic>> _availableCustomers = [];
  bool _isLoadingCustomers = false;

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;

  double? _selectedLat;
  double? _selectedLng;
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
      _descriptionController = TextEditingController(text: event.description ?? '');
      _selectedCustomerId = event.customerId;
      _startDate = event.startAt;
      _startTime = TimeOfDay.fromDateTime(event.startAt);
      _endDate = event.endAt;
      _endTime = TimeOfDay.fromDateTime(event.endAt);
      _selectedLat = event.latitude;
      _selectedLng = event.longitude;
    } else {
      _titleController = TextEditingController(text: widget.initialTitle ?? '');
      _locationController = TextEditingController();
      _tagController = TextEditingController();
      _descriptionController = TextEditingController();
      _selectedCustomerId = widget.initialCustomerId;

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

    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoadingCustomers = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (isOfflineMode || user == null) {
        _availableCustomers = List<Map<String, dynamic>>.from(OfflineDataStore.customers)
            .where((c) => c['deleted_at'] == null)
            .toList();
      } else {
        final data = await Supabase.instance.client
            .from('customers')
            .select('id, name, nickname, phone, tags, custom_attributes')
            .isFilter('deleted_at', null)
            .order('name');
        _availableCustomers = List<Map<String, dynamic>>.from(data as List);
      }
    } catch (e) {
      debugPrint('⚠️ 載入客戶清單失敗，降級本地: $e');
      _availableCustomers = List<Map<String, dynamic>>.from(OfflineDataStore.customers)
          .where((c) => c['deleted_at'] == null)
          .toList();
    } finally {
      if (mounted) setState(() => _isLoadingCustomers = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _tagController.dispose();
    _descriptionController.dispose();
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

      final eventToSave = ScheduleEvent(
        id: widget.eventToEdit?.id ?? '',
        profileId: widget.eventToEdit?.profileId ?? profileId,
        customerId: _selectedCustomerId,
        title: _titleController.text.trim(),
        startAt: startDateTime,
        endAt: endDateTime,
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        latitude: _selectedLat,
        longitude: _selectedLng,
        tag: _tagController.text.trim().isEmpty ? null : _tagController.text.trim(),
        eventType: widget.eventToEdit?.eventType ?? widget.initialEventType ?? (_selectedCustomerId != null ? 'visit' : 'personal'),
        isCompleted: widget.eventToEdit?.isCompleted ?? false,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        googleEventId: widget.eventToEdit?.googleEventId,
        googleCalendarId: widget.eventToEdit?.googleCalendarId,
        syncStatus: widget.eventToEdit?.syncStatus ?? 'local_only',
        lastSyncedAt: widget.eventToEdit?.lastSyncedAt,
      );

      if (widget.eventToEdit != null) {
        await ScheduleService.instance.updateEvent(eventToSave);
        if (mounted) {
          CustomToast.show(context, '行程更新成功 ✅', ToastType.success);
        }
      } else {
        await ScheduleService.instance.createEvent(eventToSave);
        if (mounted) {
          CustomToast.show(context, '行程建立成功 📅', ToastType.success);
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
      await ScheduleService.instance.deleteEvent(widget.eventToEdit!.id);
      if (mounted) {
        CustomToast.show(context, '行程已成功刪除', ToastType.warning);
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

    Widget buildFormColumn() {
      // Find selected customer info if any
      final selectedCustomer = _availableCustomers.firstWhere(
        (c) => c['id'].toString() == _selectedCustomerId,
        orElse: () => {},
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_available, color: Color(0xFF0284C7), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? context.l10n('event_edit_title') : context.l10n('event_add_title'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (GoogleCalendarSyncService.instance.isSyncEnabled) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (widget.eventToEdit?.isGoogleSynced ?? false) ? Icons.sync : Icons.cloud_sync_outlined,
                            size: 13,
                            color: const Color(0xFF4285F4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (widget.eventToEdit?.isGoogleSynced ?? false) ? 'Google 已對齊' : '自動對齊 Google',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF4285F4), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Customer Selector Section (關聯客戶)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 18, color: Color(0xFF0284C7)),
                        const SizedBox(width: 6),
                        Text(
                          '關聯客戶 (可選)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    if (_selectedCustomerId != null)
                      TextButton(
                        onPressed: () => setState(() => _selectedCustomerId = null),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(40, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('清除關聯', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedCustomerId,
                    isExpanded: true,
                    hint: Text(
                      _isLoadingCustomers ? '載入客戶中...' : '👤 選擇此行程關聯的客戶 (選定後自動帶入備註)',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('無關聯客戶 (個人行程)', style: TextStyle(fontSize: 13)),
                      ),
                      ..._availableCustomers.map((cust) {
                        final name = cust['name']?.toString() ?? '未命名';
                        final phone = cust['phone']?.toString() ?? '';
                        return DropdownMenuItem<String?>(
                          value: cust['id'].toString(),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.2),
                                child: Text(
                                  name.isNotEmpty ? name[0] : '?',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              if (phone.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text('($phone)', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedCustomerId = val;
                        if (val != null) {
                          final c = _availableCustomers.firstWhere((x) => x['id'].toString() == val, orElse: () => {});
                          if (c.isNotEmpty) {
                            final name = c['name']?.toString() ?? '';
                            if (_titleController.text.trim().isEmpty || _titleController.text.startsWith('拜訪:')) {
                              _titleController.text = '拜訪 $name';
                            }
                            // Check for customer address in custom_attributes or notes
                            final customAttrs = c['custom_attributes'] as Map<String, dynamic>?;
                            final addr = customAttrs?['address']?.toString() ?? '';
                            if (addr.isNotEmpty && _locationController.text.trim().isEmpty) {
                              _locationController.text = addr;
                            }
                          }
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
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

          // Location Input (with interactive map modal popup button)
          TextFormField(
            controller: _locationController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: context.l10n('event_location_label'),
              hintText: context.l10n('event_location_hint'),
              prefixIcon: const Icon(Icons.location_on_outlined),
              suffixIcon: Tooltip(
                message: '開啟地圖定位選點',
                child: IconButton(
                  icon: const Icon(
                    Icons.map,
                    color: Color(0xFF0284C7),
                    size: 22,
                  ),
                  onPressed: () => _openInteractiveMapModal(context),
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

          // Description Input (拜訪重點 / 備註)
          TextFormField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '📝 行程詳細備註 / 拜訪重點',
              hintText: '例：討論醫療險續約、檢視實支實付收據、客戶偏好下午喝茶...',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Icon(Icons.notes_outlined),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
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
                    : Text(
                        isEdit ? context.l10n('profile_save_changes') : context.l10n('event_add_title'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ],
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width >= 560 ? 520 : MediaQuery.of(context).size.width * 0.94,
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: buildFormColumn(),
          ),
        ),
      ),
    );
  }

  // 🗺️ 彈出頂層互動式地圖 Modal (覆蓋最上方，不擠壓底層行程表單)
  void _openInteractiveMapModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: bgColor,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 650),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Top Modal Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.map_rounded, color: Color(0xFF0284C7), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            '🗺️ 地圖定位點選',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search Bar Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _mapSearchController,
                          decoration: InputDecoration(
                            hintText: '搜尋地點 (例: 星巴克, 台北車站)',
                            isDense: true,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _isSearchingPlace
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => _mapSearchController.clear(),
                                  ),
                            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                          ),
                          onSubmitted: (val) async {
                            await _performSearch(val);
                            setModalState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await _performSearch(_mapSearchController.text);
                          setModalState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('搜尋'),
                      ),
                    ],
                  ),

                  // Search Results List (if any)
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      constraints: const BoxConstraints(maxHeight: 140),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = _searchResults[idx];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on, size: 18, color: Color(0xFF0284C7)),
                            title: Text(item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () {
                              _selectSearchResult(item);
                              setModalState(() {});
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 10),

                  // Interactive Flutter Map View
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: (_selectedLat != null && _selectedLng != null)
                                  ? LatLng(_selectedLat!, _selectedLng!)
                                  : _defaultCenter,
                              initialZoom: 15,
                              onTap: (_, point) async {
                                await _onMapTap(point);
                                setModalState(() {});
                              },
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
                              heroTag: 'recenter_map_modal',
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
                  ),
                  const SizedBox(height: 12),

                  // Bottom Confirmation Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedLat != null
                              ? '📍 已選地點: ${_locationController.text.isNotEmpty ? _locationController.text : "${_selectedLat!.toStringAsFixed(4)}, ${_selectedLng!.toStringAsFixed(4)}"}'
                              : '💡 請在地圖上點擊位置或搜尋標註定位點',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('確認套用此地點', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
