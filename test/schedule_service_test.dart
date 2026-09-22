import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/models/schedule_event.dart';
import 'package:insurance_helper/services/schedule_service.dart';
import 'package:insurance_helper/main.dart';

void main() {
  setUp(() {
    OfflineDataStore.scheduleEvents.clear();
    isOfflineMode = true;
  });

  group('📅 ScheduleEvent Model Tests', () {
    test('1. JSON 序列化與反序列化測試 (UTC/Local Round-Trip)', () {
      final now = DateTime.now();
      final event = ScheduleEvent(
        id: 'event-101',
        profileId: 'user-001',
        customerId: 'cust-888',
        title: '拜訪 林小花',
        startAt: now,
        endAt: now.add(const Duration(hours: 1)),
        location: '台北市信義區信義路五段7號',
        latitude: 25.0330,
        longitude: 121.5654,
        tag: 'VIP簽約',
        eventType: 'visit',
        isCompleted: false,
        description: '討論實支實付升級與醫療險續約',
        googleEventId: 'g-event-999',
        googleCalendarId: 'helper-calendar-id',
        syncStatus: 'synced',
        lastSyncedAt: now,
      );

      final json = event.toJson();
      expect(json['id'], 'event-101');
      expect(json['customer_id'], 'cust-888');
      expect(json['title'], '拜訪 林小花');
      expect(json['location'], '台北市信義區信義路五段7號');
      expect(json['latitude'], 25.0330);
      expect(json['google_event_id'], 'g-event-999');
      expect(json['description'], '討論實支實付升級與醫療險續約');

      final reconstructed = ScheduleEvent.fromJson(json);
      expect(reconstructed.id, event.id);
      expect(reconstructed.customerId, event.customerId);
      expect(reconstructed.title, event.title);
      expect(reconstructed.isGoogleSynced, isTrue);
      expect(reconstructed.description, event.description);
    });

    test('2. copyWith 屬性局部更新測試', () {
      final now = DateTime.now();
      final event = ScheduleEvent(
        id: 'e-1',
        profileId: 'p-1',
        title: '初始行程',
        startAt: now,
        endAt: now.add(const Duration(hours: 1)),
        isCompleted: false,
      );

      final completedEvent = event.copyWith(
        isCompleted: true,
        title: '已完成行程',
        tag: 'VIP客戶',
      );

      expect(completedEvent.id, 'e-1');
      expect(completedEvent.isCompleted, isTrue);
      expect(completedEvent.title, '已完成行程');
      expect(completedEvent.tag, 'VIP客戶');
      expect(event.isCompleted, isFalse); // 不可變性 (Immutability)
    });

    test('3. eventType 白名單標準化測試 (消除 Postgres 23514 報錯)', () {
      // 1. 'visit' 自動標準化為 'customer_visit'
      expect(ScheduleEvent.normalizeEventType('visit'), 'customer_visit');
      expect(ScheduleEvent.normalizeEventType('customer_visit'), 'customer_visit');

      // 2. 'reminder' 自動標準化為 'follow_up'
      expect(ScheduleEvent.normalizeEventType('reminder'), 'follow_up');
      expect(ScheduleEvent.normalizeEventType('follow_up'), 'follow_up');

      // 3. 有關聯客戶但傳入 null 或 personal 時自動升級
      expect(ScheduleEvent.normalizeEventType(null, hasCustomer: true), 'customer_visit');
      expect(ScheduleEvent.normalizeEventType('personal', hasCustomer: true), 'customer_visit');
      expect(ScheduleEvent.normalizeEventType(null, hasCustomer: false), 'personal');

      // 4. ScheduleEvent toJson 輸出必然符合資料庫 CHECK 約束白名單
      final eventWithCustomer = ScheduleEvent(
        id: 'test-1',
        profileId: 'user-1',
        customerId: 'cust-1',
        title: '拜訪客戶',
        startAt: DateTime.now(),
        endAt: DateTime.now().add(const Duration(hours: 1)),
        eventType: 'visit', // 前端舊值
      );
      final json = eventWithCustomer.toJson();
      expect(json['event_type'], 'customer_visit'); // 自動標準化為合法白名單

      const allowedDbEventTypes = {'personal', 'customer_visit', 'meeting', 'follow_up', 'general'};
      expect(allowedDbEventTypes.contains(json['event_type']), isTrue);
    });
  });

  group('⚙️ ScheduleService Business Logic Tests', () {
    test('3. 新增、讀取、更新與刪除行程 (CRUD 離線閉環測試)', () async {
      final service = ScheduleService.instance;
      final now = DateTime.now();

      // Create
      final newEvent = ScheduleEvent(
        id: '',
        profileId: 'test-user',
        customerId: 'cust-1',
        title: '專案會議',
        startAt: now,
        endAt: now.add(const Duration(hours: 2)),
        tag: '重要會議',
      );

      final created = await service.createEvent(newEvent);
      expect(created.id, isNotEmpty);
      expect(created.title, '專案會議');

      // Fetch
      final list = await service.fetchEvents();
      expect(list.any((e) => e.id == created.id), isTrue);

      // Update
      final updatedEvent = created.copyWith(
        title: '專案會議 (已改期)',
        location: '會議室 A',
      );
      final updated = await service.updateEvent(updatedEvent);
      expect(updated.title, '專案會議 (已改期)');
      expect(updated.location, '會議室 A');

      // Toggle Complete
      final success = await service.toggleComplete(created.id, true);
      expect(success, isTrue);

      final afterToggleList = await service.fetchEvents();
      final toggled = afterToggleList.firstWhere((e) => e.id == created.id);
      expect(toggled.isCompleted, isTrue);

      // Delete
      final deleteSuccess = await service.deleteEvent(created.id);
      expect(deleteSuccess, isTrue);

      final afterDeleteList = await service.fetchEvents();
      expect(afterDeleteList.any((e) => e.id == created.id), isFalse);
    });

    test('4. 響應式事件通知 (eventsRevision Notifier) 測試', () async {
      final service = ScheduleService.instance;
      int notificationsCount = 0;
      service.eventsRevision.addListener(() {
        notificationsCount++;
      });

      final initialRevision = service.eventsRevision.value;

      await service.createEvent(ScheduleEvent(
        id: 'rev-test',
        profileId: 'test-user',
        title: '修訂測試行程',
        startAt: DateTime.now(),
        endAt: DateTime.now().add(const Duration(hours: 1)),
      ));

      expect(service.eventsRevision.value, greaterThan(initialRevision));
      expect(notificationsCount, greaterThan(0));
    });
  });
}
