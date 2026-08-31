import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/schedule_event.dart';

/// Google 日曆雙向自動同步服務 (Singleton)
class GoogleCalendarSyncService {
  static final GoogleCalendarSyncService instance = GoogleCalendarSyncService._internal();
  GoogleCalendarSyncService._internal();

  static const String _secondaryCalendarName = '保險助手 (Insurance Helper)';
  static const String _prefSyncEnabledKey = 'google_calendar_sync_enabled';
  static const String _prefCalendarIdKey = 'google_calendar_secondary_id';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      calendar.CalendarApi.calendarScope,
      calendar.CalendarApi.calendarEventsScope,
    ],
  );

  bool _isSyncEnabled = false;
  bool get isSyncEnabled => _isSyncEnabled;

  String? _secondaryCalendarId;
  String? get secondaryCalendarId => _secondaryCalendarId;

  // 允許測試時注入 Mock Client
  http.Client? mockHttpClient;

  /// 初始化同步服務設定
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSyncEnabled = prefs.getBool(_prefSyncEnabledKey) ?? false;
      _secondaryCalendarId = prefs.getString(_prefCalendarIdKey);
    } catch (e) {
      debugPrint('⚠️ [GoogleCalendarSyncService] 初始化失敗: $e');
    }
  }

  /// 設定是否啟用 Google 日曆同步
  Future<void> setSyncEnabled(bool enabled) async {
    _isSyncEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefSyncEnabledKey, enabled);
    } catch (e) {
      debugPrint('⚠️ [GoogleCalendarSyncService] 儲存同步狀態失敗: $e');
    }
  }

  /// 取得授權的 CalendarApi 客戶端
  Future<calendar.CalendarApi?> _getCalendarApi() async {
    if (mockHttpClient != null) {
      return calendar.CalendarApi(mockHttpClient!);
    }

    try {
      var currentUser = _googleSignIn.currentUser;
      currentUser ??= await _googleSignIn.signInSilently();

      if (currentUser == null) {
        debugPrint('⚠️ [GoogleCalendarSyncService] 使用者未登入 Google 帳號');
        return null;
      }

      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient == null) {
        debugPrint('⚠️ [GoogleCalendarSyncService] 無法取得 Google OAuth Client');
        return null;
      }

      return calendar.CalendarApi(authClient);
    } catch (e) {
      debugPrint('⚠️ [GoogleCalendarSyncService] 取得 CalendarApi 失敗: $e');
      return null;
    }
  }

  /// 取得或創建專屬次日曆「保險助手 (Insurance Helper)」
  Future<String?> getOrCreateSecondaryCalendar(calendar.CalendarApi api) async {
    if (_secondaryCalendarId != null && _secondaryCalendarId!.isNotEmpty) {
      return _secondaryCalendarId;
    }

    try {
      // 1. 搜尋現有日曆列表
      final calendarList = await api.calendarList.list();
      if (calendarList.items != null) {
        for (final cal in calendarList.items!) {
          if (cal.summary == _secondaryCalendarName || cal.summary == '保險助手') {
            _secondaryCalendarId = cal.id;
            await _saveCalendarId(cal.id!);
            return cal.id;
          }
        }
      }

      // 2. 若不存在則建立次日曆
      final newCalendar = calendar.Calendar()
        ..summary = _secondaryCalendarName
        ..description = 'insurance_helper 專案自動同步之專屬行程日曆'
        ..timeZone = 'Asia/Taipei';

      final createdCal = await api.calendars.insert(newCalendar);
      _secondaryCalendarId = createdCal.id;
      if (createdCal.id != null) {
        await _saveCalendarId(createdCal.id!);
      }
      return createdCal.id;
    } catch (e) {
      debugPrint('⚠️ [GoogleCalendarSyncService] 取得/建立次日曆失敗，降級使用 primary: $e');
      return 'primary';
    }
  }

  Future<void> _saveCalendarId(String calId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCalendarIdKey, calId);
    } catch (_) {}
  }

  /// 推送單筆本地行程至 Google 日曆
  Future<ScheduleEvent> pushLocalToRemote(ScheduleEvent event) async {
    if (!_isSyncEnabled) return event;

    final api = await _getCalendarApi();
    if (api == null) {
      return event.copyWith(syncStatus: 'pending_push');
    }

    try {
      final calendarId = await getOrCreateSecondaryCalendar(api) ?? 'primary';

      final googleEvent = calendar.Event()
        ..summary = event.title
        ..description = event.description
        ..location = event.location
        ..start = calendar.EventDateTime(dateTime: event.startAt.toUtc())
        ..end = calendar.EventDateTime(dateTime: event.endAt.toUtc())
        ..extendedProperties = calendar.EventExtendedProperties(
          private: {'insurance_helper_id': event.id},
        );

      calendar.Event resultEvent;

      if (event.googleEventId != null && event.googleEventId!.isNotEmpty) {
        // 更新現有 Google 行程
        try {
          resultEvent = await api.events.update(googleEvent, calendarId, event.googleEventId!);
        } catch (_) {
          // 若遠端找不到則改為 insert
          resultEvent = await api.events.insert(googleEvent, calendarId);
        }
      } else {
        // 新增 Google 行程
        resultEvent = await api.events.insert(googleEvent, calendarId);
      }

      return event.copyWith(
        googleEventId: resultEvent.id,
        googleCalendarId: calendarId,
        syncStatus: 'synced',
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('⚠️ [GoogleCalendarSyncService] 推送行程至 Google 日曆失敗: $e');
      return event.copyWith(syncStatus: 'pending_push');
    }
  }

  /// 從 Google 日曆刪除行程
  Future<bool> deleteRemoteEvent(String? googleCalendarId, String? googleEventId) async {
    if (!_isSyncEnabled || googleEventId == null || googleEventId.isEmpty) {
      return true;
    }

    final api = await _getCalendarApi();
    if (api == null) return false;

    try {
      final calId = googleCalendarId ?? _secondaryCalendarId ?? 'primary';
      await api.events.delete(calId, googleEventId);
      return true;
    } catch (e) {
      debugPrint('⚠️ [GoogleCalendarSyncService] 刪除 Google 日曆行程失敗: $e');
      return false;
    }
  }

  /// 從 Google 日曆雙向拉取並對齊行程 (LWW 衝突解決)
  Future<List<ScheduleEvent>> pullAndAlignEvents(List<ScheduleEvent> localEvents) async {
    if (!_isSyncEnabled) return localEvents;

    final api = await _getCalendarApi();
    if (api == null) return localEvents;

    try {
      final calendarId = await getOrCreateSecondaryCalendar(api) ?? 'primary';
      final remoteEventsList = await api.events.list(calendarId);
      final remoteItems = remoteEventsList.items ?? [];

      final resultMap = {for (var e in localEvents) e.id: e};

      for (final remote in remoteItems) {
        if (remote.status == 'cancelled') continue;

        final localId = remote.extendedProperties?.private?['insurance_helper_id'];
        final remoteUpdated = remote.updated ?? DateTime.now();

        if (localId != null && resultMap.containsKey(localId)) {
          // 本地已存在：依據 LWW (Last-Write-Wins) 比對時間戳
          final local = resultMap[localId]!;
          if (local.lastSyncedAt == null || remoteUpdated.isAfter(local.lastSyncedAt!)) {
            resultMap[localId] = local.copyWith(
              title: remote.summary ?? local.title,
              description: remote.description ?? local.description,
              location: remote.location ?? local.location,
              startAt: remote.start?.dateTime?.toLocal() ?? local.startAt,
              endAt: remote.end?.dateTime?.toLocal() ?? local.endAt,
              googleEventId: remote.id,
              googleCalendarId: calendarId,
              syncStatus: 'synced',
              lastSyncedAt: DateTime.now(),
            );
          }
        } else {
          // 遠端新增行程：加入 App 本地
          final newEventId = localId ?? remote.id ?? '';
          final newLocalEvent = ScheduleEvent(
            id: newEventId,
            profileId: 'google-sync-user',
            title: remote.summary ?? 'Google 同步行程',
            description: remote.description,
            location: remote.location,
            startAt: remote.start?.dateTime?.toLocal() ?? DateTime.now(),
            endAt: remote.end?.dateTime?.toLocal() ?? DateTime.now().add(const Duration(hours: 1)),
            googleEventId: remote.id,
            googleCalendarId: calendarId,
            syncStatus: 'synced',
            lastSyncedAt: DateTime.now(),
          );
          resultMap[newEventId] = newLocalEvent;
        }
      }

      return resultMap.values.toList();
    } catch (e) {
      debugPrint('⚠️ [GoogleCalendarSyncService] 拉取 Google 日曆行程失敗: $e');
      return localEvents;
    }
  }

  /// 將 ScheduleEvent 物件轉為 googleapis.Event 物件（單元測試用）
  calendar.Event toGoogleEvent(ScheduleEvent event) {
    return calendar.Event()
      ..summary = event.title
      ..description = event.description
      ..location = event.location
      ..start = calendar.EventDateTime(dateTime: event.startAt.toUtc())
      ..end = calendar.EventDateTime(dateTime: event.endAt.toUtc())
      ..extendedProperties = calendar.EventExtendedProperties(
        private: {'insurance_helper_id': event.id},
      );
  }
}
