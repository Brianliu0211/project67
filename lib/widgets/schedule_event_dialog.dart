import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/schedule_event.dart';
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

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;

  String _eventType = 'personal';
  String? _selectedCustomerId;
  bool _isSaving = false;
  bool _isDeleting = false;

  List<Map<String, dynamic>> _customers = [];
  bool _isLoadingCustomers = false;

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
      _eventType = event.eventType;
      _selectedCustomerId = event.customerId;
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
    }

    _loadCustomers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    if (isOfflineMode) return;
    setState(() => _isLoadingCustomers = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('customers')
            .select('id, name')
            .eq('profile_id', user.id)
            .eq('is_deleted', false)
            .order('name');
        
        if (mounted) {
          setState(() {
            _customers = List<Map<String, dynamic>>.from(data);
          });
        }
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoadingCustomers = false);
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

      final eventData = {
        'profile_id': profileId,
        'customer_id': _selectedCustomerId,
        'title': _titleController.text.trim(),
        'start_at': startDateTime.toUtc().toIso8601String(),
        'end_at': endDateTime.toUtc().toIso8601String(),
        'location': _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        'tag': _tagController.text.trim().isEmpty ? null : _tagController.text.trim(),
        'event_type': _eventType,
      };

      if (!isOfflineMode && user != null) {
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? '編輯行程' : '新增行程',
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
                    decoration: const InputDecoration(
                      labelText: '行程名稱 *',
                      prefixIcon: Icon(Icons.event_note),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? '請輸入行程名稱' : null,
                  ),
                  const SizedBox(height: 16),

                  // Event Type Selector
                  DropdownButtonFormField<String>(
                    value: _eventType,
                    decoration: const InputDecoration(
                      labelText: '行程類型',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'personal', child: Text('個人行程 👤')),
                      DropdownMenuItem(value: 'meeting', child: Text('會議談判 💼')),
                      DropdownMenuItem(value: 'visit', child: Text('客戶拜訪 🚗')),
                      DropdownMenuItem(value: 'reminder', child: Text('待辦提醒 🔔')),
                    ],
                    onChanged: (val) => setState(() => _eventType = val ?? 'personal'),
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
                            decoration: const InputDecoration(
                              labelText: '開始日期',
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              prefixIcon: Icon(Icons.calendar_today, size: 18),
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
                            decoration: const InputDecoration(
                              labelText: '開始時間',
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              prefixIcon: Icon(Icons.access_time, size: 18),
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
                            decoration: const InputDecoration(
                              labelText: '結束日期',
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              prefixIcon: Icon(Icons.calendar_today, size: 18),
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
                            decoration: const InputDecoration(
                              labelText: '結束時間',
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              prefixIcon: Icon(Icons.access_time, size: 18),
                            ),
                            child: Text(_endTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location Input
                  TextFormField(
                    controller: _locationController,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _saveEvent(),
                    decoration: const InputDecoration(
                      labelText: '地點 (選填)',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dynamic Categorized Tag Selector (Unified with Customer Tag System)
                  CategorizedTagAccordionSelector(
                    tagsController: _tagController,
                    isDark: Theme.of(context).brightness == Brightness.dark,
                    primaryColor: const Color(0xFF0369A1),
                  ),
                  const SizedBox(height: 16),

                  // Associate Customer Dropdown
                  DropdownButtonFormField<String?>(
                    value: _selectedCustomerId,
                    decoration: InputDecoration(
                      labelText: '關聯客戶 (選填)',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      suffixIcon: _isLoadingCustomers
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('無關聯客戶 (個人行程)', style: TextStyle(color: Colors.grey)),
                      ),
                      ..._customers.map((c) => DropdownMenuItem<String?>(
                            value: c['id'] as String,
                            child: Text(c['name'] as String),
                          )),
                    ],
                    onChanged: (val) => setState(() => _selectedCustomerId = val),
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
                          label: const Text('刪除', style: TextStyle(color: Colors.red)),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消', style: TextStyle(color: Colors.grey)),
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
                            : Text(isEdit ? '儲存變更' : '新增行程', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
