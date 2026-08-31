import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:insurance_helper/models/schedule_event.dart';
import 'package:insurance_helper/services/google_calendar_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleCalendarSyncService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Sync enabled toggle state persistence', () async {
      final syncService = GoogleCalendarSyncService.instance;
      await syncService.init();
      expect(syncService.isSyncEnabled, isFalse);

      await syncService.setSyncEnabled(true);
      expect(syncService.isSyncEnabled, isTrue);

      // Re-initialize to test SharedPreferences persistence
      await syncService.init();
      expect(syncService.isSyncEnabled, isTrue);
    });

    test('2. ScheduleEvent to Google Calendar Event conversion', () {
      final syncService = GoogleCalendarSyncService.instance;
      final now = DateTime.now();
      final event = ScheduleEvent(
        id: 'test-event-123',
        profileId: 'user-456',
        title: '保單健診與拜訪',
        description: '拜訪張先生討論美金保單',
        location: '台北市信義區松壽路 1 號',
        startAt: now,
        endAt: now.add(const Duration(hours: 1)),
      );

      final googleEvent = syncService.toGoogleEvent(event);

      expect(googleEvent.summary, equals('保單健診與拜訪'));
      expect(googleEvent.description, equals('拜訪張先生討論美金保單'));
      expect(googleEvent.location, equals('台北市信義區松壽路 1 號'));
      expect(googleEvent.extendedProperties?.private?['insurance_helper_id'], equals('test-event-123'));
    });

    test('3. ScheduleEvent JSON serialization with Google fields', () {
      final now = DateTime.now();
      final event = ScheduleEvent(
        id: 'evt-001',
        profileId: 'prof-001',
        title: '團隊月會',
        startAt: now,
        endAt: now.add(const Duration(hours: 2)),
        googleEventId: 'goog-evt-777',
        googleCalendarId: 'sec-cal-888',
        syncStatus: 'synced',
        lastSyncedAt: now,
      );

      expect(event.isGoogleSynced, isTrue);

      final json = event.toJson();
      expect(json['google_event_id'], equals('goog-evt-777'));
      expect(json['google_calendar_id'], equals('sec-cal-888'));
      expect(json['sync_status'], equals('synced'));
      expect(json['last_synced_at'], isNotNull);

      final reconstructed = ScheduleEvent.fromJson(json);
      expect(reconstructed.id, equals('evt-001'));
      expect(reconstructed.googleEventId, equals('goog-evt-777'));
      expect(reconstructed.googleCalendarId, equals('sec-cal-888'));
      expect(reconstructed.syncStatus, equals('synced'));
    });

    test('4. Graceful offline fallback simulation for pushLocalToRemote', () async {
      final syncService = GoogleCalendarSyncService.instance;
      await syncService.setSyncEnabled(true);

      final event = ScheduleEvent(
        id: 'offline-evt-1',
        profileId: 'offline-user',
        title: '離線拜訪行程',
        startAt: DateTime.now(),
        endAt: DateTime.now().add(const Duration(hours: 1)),
      );

      // Without network/OAuth login, push should gracefully return event with pending_push
      final result = await syncService.pushLocalToRemote(event);
      expect(result.syncStatus, equals('pending_push'));
    });
  });
}
