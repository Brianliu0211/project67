import 'package:flutter/material.dart';

enum NotificationType {
  customerReassigned('customer_reassigned', '過戶通知', Icons.assignment_ind_rounded, Color(0xFF6366F1)),
  managerTaskNote('manager_task_note', '主管交辦', Icons.mark_chat_read_rounded, Color(0xFFF59E0B)),
  draftCustomer('draft_customer', '待補齊草稿', Icons.contact_mail_rounded, Color(0xFFF59E0B)),
  aiSmartAlert('ai_smart_alert', 'AI 提醒', Icons.auto_awesome_rounded, Color(0xFF10B981)),
  systemNotice('system_notice', '系統公告', Icons.campaign_rounded, Color(0xFF3B82F6));

  final String dbValue;
  final String labelZh;
  final IconData icon;
  final Color themeColor;

  const NotificationType(this.dbValue, this.labelZh, this.icon, this.themeColor);

  static NotificationType fromString(String? val) {
    if (val == null) return NotificationType.systemNotice;
    return NotificationType.values.firstWhere(
      (e) => e.dbValue == val,
      orElse: () => NotificationType.systemNotice,
    );
  }
}

class AppNotification {
  final String id;
  final String profileId;
  final String senderName;
  final String title;
  final String content;
  final NotificationType type;
  final bool isRead;
  final String? targetCustomerId;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.profileId,
    required this.senderName,
    required this.title,
    required this.content,
    required this.type,
    required this.isRead,
    this.targetCustomerId,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      profileId: json['profile_id'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? '系統',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      type: NotificationType.fromString(json['type'] as String?),
      isRead: json['is_read'] as bool? ?? false,
      targetCustomerId: json['target_customer_id'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'sender_name': senderName,
      'title': title,
      'content': content,
      'type': type.dbValue,
      'is_read': isRead,
      'target_customer_id': targetCustomerId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    bool? isRead,
  }) {
    return AppNotification(
      id: id,
      profileId: profileId,
      senderName: senderName,
      title: title,
      content: content,
      type: type,
      isRead: isRead ?? this.isRead,
      targetCustomerId: targetCustomerId,
      createdAt: createdAt,
    );
  }
}
