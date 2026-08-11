import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationCenterPopover extends StatefulWidget {
  final VoidCallback? onClose;

  const NotificationCenterPopover({super.key, this.onClose});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        alignment: Alignment.topRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
          child: const NotificationCenterPopover(),
        ),
      ),
    );
  }

  @override
  State<NotificationCenterPopover> createState() => _NotificationCenterPopoverState();
}

class _NotificationCenterPopoverState extends State<NotificationCenterPopover> {
  final NotificationService _service = NotificationService();
  NotificationType? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.94);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final allNotifs = _service.notifications;
        final filteredNotifs = _selectedFilter == null
            ? allNotifs
            : allNotifs.where((n) => n.type == _selectedFilter).toList();

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Header Bar (Touch Target > 44px)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                '訊息通知中心',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              const SizedBox(width: 8),
                              if (_service.unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_service.unreadCount} 未讀',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Mark All as Read Button (Touch target >= 44x44)
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              foregroundColor: const Color(0xFF6366F1),
                            ),
                            onPressed: _service.unreadCount > 0 ? () => _service.markAllAsRead() : null,
                            icon: const Icon(Icons.done_all_rounded, size: 16),
                            label: const Text('全標已讀', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        // Close Button (Touch target >= 44x44)
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: subTextColor,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // 2. Category Filter Chips (Horizontal Scroll, Touch Target >= 44px height)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        _buildFilterChip('全部', null, isDark, textColor),
                        ...NotificationType.values.map((t) => _buildFilterChip(t.labelZh, t, isDark, textColor)),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // 3. Notification Items List
                  Flexible(
                    child: filteredNotifs.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mark_email_read_outlined, size: 48, color: subTextColor.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text('暫無相關訊息通知', style: TextStyle(fontSize: 14, color: subTextColor)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredNotifs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final item = filteredNotifs[i];
                              return _buildNotificationCard(item, isDark, textColor, subTextColor);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, NotificationType? type, bool isDark, Color textColor) {
    final isSelected = _selectedFilter == type;
    final activeColor = type?.themeColor ?? const Color(0xFF6366F1);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: FilterChip(
          selected: isSelected,
          label: Text(label),
          avatar: type != null ? Icon(type.icon, size: 12, color: isSelected ? Colors.white : activeColor) : null,
          selectedColor: activeColor,
          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : textColor,
          ),
          onSelected: (_) {
            setState(() {
              _selectedFilter = type;
            });
          },
        ),
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notif, bool isDark, Color textColor, Color subTextColor) {
    final cardBg = notif.isRead
        ? (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC))
        : (isDark ? const Color(0xFF1E293B) : Colors.white);
    final borderColor = notif.isRead
        ? (isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFE2E8F0))
        : notif.type.themeColor.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: notif.isRead ? 1 : 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: notif.type.themeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(notif.type.icon, size: 16, color: notif.type.themeColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        if (!notif.isRead) ...[
                          const SizedBox(width: 6),
                          const CircleAvatar(radius: 3, backgroundColor: Color(0xFFF59E0B)),
                        ],
                      ],
                    ),
                    Text(
                      '發送者：${notif.senderName} • ${_formatTimeAgo(notif.createdAt)}',
                      style: TextStyle(fontSize: 10, color: subTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            notif.content,
            style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.9), height: 1.4),
          ),
          const SizedBox(height: 8),

          // Action Buttons Bar (Bidirectional Feedback, touch target >= 44px)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (notif.type == NotificationType.managerTaskNote) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      elevation: 0,
                    ),
                    onPressed: () {
                      _service.markAsRead(notif.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ 已標記完成主管交辦，已發送雙向完成通知予主管！'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                    label: const Text('已完成交辦', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else if (notif.type == NotificationType.customerReassigned) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () {
                      _service.markAsRead(notif.id);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('查看客戶卡片', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              if (!notif.isRead)
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: subTextColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    onPressed: () => _service.markAsRead(notif.id),
                    child: const Text('標為已讀', style: TextStyle(fontSize: 11)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
    if (diff.inHours < 24) return '${diff.inHours} 小時前';
    return '${diff.inDays} 天前';
  }
}
