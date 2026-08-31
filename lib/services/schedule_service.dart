import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule_event.dart';
import '../main.dart';

/// 全域行程業務邏輯與資料存取服務 (Singleton)
class ScheduleService {
  static final ScheduleService instance = ScheduleService._internal();
  ScheduleService._internal();

  final _uuid = const Uuid();

  // 本地快取
  List<ScheduleEvent> _cachedEvents = [];
  List<ScheduleEvent> get cachedEvents => List.unmodifiable(_cachedEvents);

  // 變更通知
  final ValueNotifier<int> eventsRevision = ValueNotifier<int>(0);

  void _notifyChange() {
    eventsRevision.value++;
  }

  User? get _currentUser {
    if (isOfflineMode) return null;
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// 依起訖時間查詢行程列表
  Future<List<ScheduleEvent>> fetchEvents({
    DateTime? start,
    DateTime? end,
    bool silent = false,
  }) async {
    final user = _currentUser;

    if (isOfflineMode || user == null) {
      // 離線預覽模式：從 OfflineDataStore 讀取
      var localList = OfflineDataStore.scheduleEvents
          .map((json) => ScheduleEvent.fromJson(json))
          .toList();

      if (start != null && end != null) {
        localList = localList.where((e) {
          return e.startAt.isBefore(end) && e.endAt.isAfter(start);
        }).toList();
      }

      localList.sort((a, b) => a.startAt.compareTo(b.startAt));
      _cachedEvents = localList;
      _notifyChange();
      return localList;
    }

    try {
      var query = Supabase.instance.client
          .from('schedule_events')
          .select()
          .eq('profile_id', user.id);

      if (start != null) {
        query = query.gte('end_at', start.toUtc().toIso8601String());
      }
      if (end != null) {
        query = query.lte('start_at', end.toUtc().toIso8601String());
      }

      final data = await query.order('start_at', ascending: true);
      final list = (data as List)
          .map((json) => ScheduleEvent.fromJson(json as Map<String, dynamic>))
          .toList();

      _cachedEvents = list;
      // 同步一份至 OfflineDataStore 做本地快取備份
      OfflineDataStore.scheduleEvents = list.map((e) => e.toJson()).toList();
      _notifyChange();
      return list;
    } catch (e) {
      debugPrint('⚠️ [ScheduleService] 載入行程失敗，降級使用本地快取: $e');
      if (OfflineDataStore.scheduleEvents.isNotEmpty) {
        final fallbackList = OfflineDataStore.scheduleEvents
            .map((json) => ScheduleEvent.fromJson(json))
            .toList();
        _cachedEvents = fallbackList;
        return fallbackList;
      }
      return [];
    }
  }

  /// 新增行程
  Future<ScheduleEvent> createEvent(ScheduleEvent event) async {
    final user = _currentUser;
    final profileId = user?.id ?? 'offline-user';
    final generatedId = event.id.isNotEmpty ? event.id : _uuid.v4();

    final newEvent = event.copyWith(
      id: generatedId,
      profileId: profileId,
      syncStatus: event.syncStatus.isEmpty ? 'local_only' : event.syncStatus,
    );

    if (isOfflineMode || user == null) {
      final json = newEvent.toJson();
      OfflineDataStore.scheduleEvents.insert(0, json);
      _cachedEvents.insert(0, newEvent);
      _notifyChange();
      return newEvent;
    }

    final payload = newEvent.toJson();
    try {
      final res = await Supabase.instance.client
          .from('schedule_events')
          .insert(payload)
          .select()
          .single();

      final created = ScheduleEvent.fromJson(res);
      _cachedEvents.removeWhere((e) => e.id == created.id);
      _cachedEvents.add(created);
      _cachedEvents.sort((a, b) => a.startAt.compareTo(b.startAt));
      
      OfflineDataStore.scheduleEvents = _cachedEvents.map((e) => e.toJson()).toList();
      _notifyChange();
      return created;
    } catch (dbErr) {
      final errStr = dbErr.toString();
      // 相容性處理：若資料庫缺少經緯度等新欄位
      if (errStr.contains('latitude') || errStr.contains('PGRST204')) {
        payload.remove('latitude');
        payload.remove('longitude');
        final res = await Supabase.instance.client
            .from('schedule_events')
            .insert(payload)
            .select()
            .single();
        final created = ScheduleEvent.fromJson(res);
        _cachedEvents.add(created);
        _cachedEvents.sort((a, b) => a.startAt.compareTo(b.startAt));
        _notifyChange();
        return created;
      }
      rethrow;
    }
  }

  /// 更新行程
  Future<ScheduleEvent> updateEvent(ScheduleEvent event) async {
    final user = _currentUser;

    if (isOfflineMode || user == null) {
      final idx = OfflineDataStore.scheduleEvents.indexWhere((e) => e['id'] == event.id);
      if (idx != -1) {
        OfflineDataStore.scheduleEvents[idx] = event.toJson();
      }
      final cIdx = _cachedEvents.indexWhere((e) => e.id == event.id);
      if (cIdx != -1) {
        _cachedEvents[cIdx] = event;
      }
      _notifyChange();
      return event;
    }

    final payload = event.toJson();
    try {
      final res = await Supabase.instance.client
          .from('schedule_events')
          .update(payload)
          .eq('id', event.id)
          .select()
          .single();

      final updated = ScheduleEvent.fromJson(res);
      final idx = _cachedEvents.indexWhere((e) => e.id == updated.id);
      if (idx != -1) {
        _cachedEvents[idx] = updated;
      } else {
        _cachedEvents.add(updated);
      }
      _cachedEvents.sort((a, b) => a.startAt.compareTo(b.startAt));

      OfflineDataStore.scheduleEvents = _cachedEvents.map((e) => e.toJson()).toList();
      _notifyChange();
      return updated;
    } catch (e) {
      debugPrint('⚠️ [ScheduleService] 更新行程失敗: $e');
      rethrow;
    }
  }

  /// 刪除行程
  Future<bool> deleteEvent(String id) async {
    final user = _currentUser;

    if (isOfflineMode || user == null) {
      OfflineDataStore.scheduleEvents.removeWhere((e) => e['id'] == id);
      _cachedEvents.removeWhere((e) => e.id == id);
      _notifyChange();
      return true;
    }

    try {
      await Supabase.instance.client
          .from('schedule_events')
          .delete()
          .eq('id', id);

      _cachedEvents.removeWhere((e) => e.id == id);
      OfflineDataStore.scheduleEvents.removeWhere((e) => e['id'] == id);
      _notifyChange();
      return true;
    } catch (e) {
      debugPrint('⚠️ [ScheduleService] 刪除行程失敗: $e');
      rethrow;
    }
  }

  /// 一鍵切換完成狀態
  Future<bool> toggleComplete(String id, bool isCompleted) async {
    final user = _currentUser;

    final targetIdx = _cachedEvents.indexWhere((e) => e.id == id);
    if (targetIdx != -1) {
      _cachedEvents[targetIdx] = _cachedEvents[targetIdx].copyWith(isCompleted: isCompleted);
      _notifyChange();
    }

    if (isOfflineMode || user == null) {
      final offIdx = OfflineDataStore.scheduleEvents.indexWhere((e) => e['id'] == id);
      if (offIdx != -1) {
        OfflineDataStore.scheduleEvents[offIdx]['is_completed'] = isCompleted;
      }
      return true;
    }

    try {
      await Supabase.instance.client
          .from('schedule_events')
          .update({'is_completed': isCompleted})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('⚠️ [ScheduleService] 更新完成狀態失敗: $e');
      // 回滾
      if (targetIdx != -1) {
        _cachedEvents[targetIdx] = _cachedEvents[targetIdx].copyWith(isCompleted: !isCompleted);
        _notifyChange();
      }
      return false;
    }
  }
}
