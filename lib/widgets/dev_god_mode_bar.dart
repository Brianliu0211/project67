import 'package:flutter/material.dart';
import '../models/user_role.dart';

class DevGodModeBar extends StatelessWidget {
  final UserRole currentRole;
  final ValueChanged<UserRole> onRoleChanged;
  final VoidCallback? onOpenDevConsole;

  const DevGodModeBar({
    super.key,
    required this.currentRole,
    required this.onRoleChanged,
    this.onOpenDevConsole,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        border: const Border(bottom: BorderSide(color: Color(0xFF0EA5E9), width: 1.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0EA5E9)),
            ),
            child: const Row(
              children: [
                Icon(Icons.remove_red_eye_rounded, size: 14, color: Color(0xFF38BDF8)),
                SizedBox(width: 4),
                Text('上帝視角 God-Mode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '切換實體視圖：',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(width: 6),
          Wrap(
            spacing: 6,
            children: UserRole.values.map((role) {
              final isSelected = currentRole == role;
              return ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: ChoiceChip(
                  selected: isSelected,
                  avatar: Icon(role.badgeIcon, size: 12, color: isSelected ? Colors.white : role.primaryColor),
                  label: Text(role.shortLabel),
                  selectedColor: role.primaryColor,
                  backgroundColor: const Color(0xFF334155),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey[300],
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      onRoleChanged(role);
                    }
                  },
                ),
              );
            }).toList(),
          ),
          const Spacer(),
          // Health Status Capsule
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981)),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 3, backgroundColor: Color(0xFF10B981)),
                SizedBox(width: 4),
                Text('Supabase 24ms 🟢', style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (onOpenDevConsole != null) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: onOpenDevConsole,
                icon: const Icon(Icons.developer_board_rounded, size: 14),
                label: const Text('控制台', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
