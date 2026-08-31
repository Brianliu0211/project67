class ScheduleEvent {
  final String id;
  final String profileId;
  final String? customerId;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? tag;
  final String eventType;
  final bool isCompleted;
  final String? description;
  final String? googleEventId;
  final String? googleCalendarId;
  final String syncStatus;
  final DateTime? lastSyncedAt;

  ScheduleEvent({
    required this.id,
    required this.profileId,
    this.customerId,
    required this.title,
    required this.startAt,
    required this.endAt,
    this.location,
    this.latitude,
    this.longitude,
    this.tag,
    this.eventType = 'personal',
    this.isCompleted = false,
    this.description,
    this.googleEventId,
    this.googleCalendarId,
    this.syncStatus = 'local_only',
    this.lastSyncedAt,
  });

  bool get isGoogleSynced => googleEventId != null && googleEventId!.isNotEmpty;

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) {
    return ScheduleEvent(
      id: (json['id'] as String?) ?? '',
      profileId: (json['profile_id'] as String?) ?? '',
      customerId: json['customer_id'] as String?,
      title: (json['title'] as String?) ?? '新行程',
      // 將 UTC 時間轉換為本地時間顯示
      startAt: json['start_at'] != null ? DateTime.parse(json['start_at'] as String).toLocal() : DateTime.now(),
      endAt: json['end_at'] != null ? DateTime.parse(json['end_at'] as String).toLocal() : DateTime.now().add(const Duration(hours: 1)),
      location: json['location'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      tag: json['tag'] as String?,
      eventType: json['event_type'] as String? ?? 'personal',
      isCompleted: json['is_completed'] as bool? ?? false,
      description: json['description'] as String?,
      googleEventId: json['google_event_id'] as String?,
      googleCalendarId: json['google_calendar_id'] as String?,
      syncStatus: (json['sync_status'] as String?) ?? 'local_only',
      lastSyncedAt: json['last_synced_at'] != null ? DateTime.parse(json['last_synced_at'] as String).toLocal() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'profile_id': profileId,
      'customer_id': customerId,
      'title': title,
      // 寫入資料庫前轉換為 UTC 格式
      'start_at': startAt.toUtc().toIso8601String(),
      'end_at': endAt.toUtc().toIso8601String(),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'tag': tag,
      'event_type': eventType,
      'is_completed': isCompleted,
      'description': description,
      'google_event_id': googleEventId,
      'google_calendar_id': googleCalendarId,
      'sync_status': syncStatus,
      'last_synced_at': lastSyncedAt?.toUtc().toIso8601String(),
    };
  }

  ScheduleEvent copyWith({
    String? id,
    String? profileId,
    String? customerId,
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    String? location,
    double? latitude,
    double? longitude,
    String? tag,
    String? eventType,
    bool? isCompleted,
    String? description,
    String? googleEventId,
    String? googleCalendarId,
    String? syncStatus,
    DateTime? lastSyncedAt,
  }) {
    return ScheduleEvent(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      customerId: customerId ?? this.customerId,
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      tag: tag ?? this.tag,
      eventType: eventType ?? this.eventType,
      isCompleted: isCompleted ?? this.isCompleted,
      description: description ?? this.description,
      googleEventId: googleEventId ?? this.googleEventId,
      googleCalendarId: googleCalendarId ?? this.googleCalendarId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
