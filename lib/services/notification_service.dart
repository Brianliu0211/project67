import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal() {
    _initMockNotifications();
  }

  final List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void _initMockNotifications() {
    if (_notifications.isNotEmpty) return;
    _notifications.addAll([
      AppNotification(
        id: 'notif-1',
        profileId: 'demo-user',
        senderName: '主管 (張大明)',
        title: '📋 客戶過戶交接通知',
        content: '主管已將客戶「林小花」過戶至您的 CRM 客戶名單中，請撥空關懷。',
        type: NotificationType.customerReassigned,
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      AppNotification(
        id: 'notif-2',
        profileId: 'demo-user',
        senderName: '主管 (張大明)',
        title: '💬 主管公務留言交辦',
        content: '請於下週二前向客戶「王大同」說明防癌險最新條款更新，並完成簽署。',
        type: NotificationType.managerTaskNote,
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'notif-3',
        profileId: 'demo-user',
        senderName: 'Gemini AI 大腦',
        title: '⏰ AI 智慧跟進提醒',
        content: '客戶「陳美麗」的汽機車強制險將於 3 天後到期，建議即刻發起聯繫。',
        type: NotificationType.aiSmartAlert,
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
  }

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
  }

  void addNotification({
    required String senderName,
    required String title,
    required String content,
    required NotificationType type,
    String? targetCustomerId,
  }) {
    final notif = AppNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      profileId: 'demo-user',
      senderName: senderName,
      title: title,
      content: content,
      type: type,
      isRead: false,
      targetCustomerId: targetCustomerId,
      createdAt: DateTime.now(),
    );
    _notifications.insert(0, notif);
    notifyListeners();
  }
}
