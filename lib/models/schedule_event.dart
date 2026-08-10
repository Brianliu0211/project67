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
  });

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) {
    return ScheduleEvent(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      customerId: json['customer_id'] as String?,
      title: json['title'] as String,
      // 將 UTC 時間轉換為本地時間顯示
      startAt: DateTime.parse(json['start_at'] as String).toLocal(),
      endAt: DateTime.parse(json['end_at'] as String).toLocal(),
      location: json['location'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      tag: json['tag'] as String?,
      eventType: json['event_type'] as String? ?? 'personal',
      isCompleted: json['is_completed'] as bool? ?? false,
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
    };
  }
}
