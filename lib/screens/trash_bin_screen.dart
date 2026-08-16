import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/app_settings.dart';
import '../services/app_localizations.dart';
import '../widgets/custom_toast.dart';

enum TrashCategory {
  all(label: '全部項目', icon: Icons.all_inbox_rounded),
  customer(label: '正式客戶', icon: Icons.person_outline_rounded),
  draftCustomer(label: '語音草稿', icon: Icons.mic_none_rounded),
  schedule(label: '行程與日曆', icon: Icons.event_busy_rounded);

  final String label;
  final IconData icon;
  const TrashCategory({required this.label, required this.icon});
}

class TrashBinScreen extends StatefulWidget {
  const TrashBinScreen({super.key});

  @override
  State<TrashBinScreen> createState() => _TrashBinScreenState();
}

class _TrashBinScreenState extends State<TrashBinScreen> {
  List<Map<String, dynamic>> _deletedCustomers = [];
  bool _isLoading = false;
  TrashCategory _activeCategory = TrashCategory.all;

  @override
  void initState() {
    super.initState();
    _fetchDeletedCustomers();
  }

  Future<void> _fetchDeletedCustomers() async {
    setState(() {
      _isLoading = true;
    });

    if (isOfflineMode) {
      setState(() {
        _deletedCustomers = OfflineDataStore.customers
            .where((c) => c['deleted_at'] != null)
            .toList();
        _isLoading = false;
      });
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      // Fetch only soft-deleted customers
      final response = await supabase
          .from('customers')
          .select()
          .not('deleted_at', 'is', null)
          .order('deleted_at', ascending: false);

      setState(() {
        _deletedCustomers = List<Map<String, dynamic>>.from(response.map((data) {
          return {
            'id': data['id'],
            'name': data['name'],
            'nickname': data['nickname'] ?? '',
            'avatar_url': data['avatar_url'] ?? '',
            'phone': data['phone'],
            'email': data['email'],
            'status': data['status'] ?? 'active',
            'tags': List<String>.from(data['tags'] ?? []),
            'notes': data['notes'],
            'created_at': data['created_at'],
            'deleted_at': data['deleted_at'],
          };
        }));
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '載入垃圾桶失敗: $e', ToastType.error);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreCustomer(String id, bool isDraft) async {
    setState(() {
      _isLoading = true;
    });

    if (isOfflineMode) {
      final index = OfflineDataStore.customers.indexWhere((c) => c['id'] == id);
      if (index != -1) {
        OfflineDataStore.customers[index] = {
          ...OfflineDataStore.customers[index],
          'deleted_at': null,
        };
      }
      await _fetchDeletedCustomers();
      if (mounted) {
        CustomToast.show(context, isDraft ? '🎉 語音草稿已成功還原至收件匣！' : '🎉 客戶已成功還原至名冊！', ToastType.success);
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('customers').update({
        'deleted_at': null,
      }).eq('id', id);
      await _fetchDeletedCustomers();
      if (mounted) {
        CustomToast.show(context, isDraft ? '🎉 語音草稿已成功還原至收件匣！' : '🎉 客戶已成功還原至名冊！', ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '復原失敗: $e', ToastType.error);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCustomerForever(String id) async {
    setState(() {
      _isLoading = true;
    });

    if (isOfflineMode) {
      OfflineDataStore.customers.removeWhere((c) => c['id'] == id);
      await _fetchDeletedCustomers();
      if (mounted) {
        CustomToast.show(context, '${context.l10n('trash_bin_delete_forever_success')} (離線暫存)', ToastType.success);
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      // Physical hard delete
      await supabase.from('customers').delete().eq('id', id);
      await _fetchDeletedCustomers();
      if (mounted) {
        CustomToast.show(context, context.l10n('trash_bin_delete_forever_success'), ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '徹底刪除失敗: $e', ToastType.error);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDeleteForeverConfirm(String id, String name) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
          title: Text(
            context.l10n('trash_bin_confirm_delete_forever_title'),
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          content: Text(
            '確定要永久刪除「$name」嗎？此動作將自資料庫徹底銷毀，無法復原！',
            style: TextStyle(color: textColor.withOpacity(0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.l10n('cancel'),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteCustomerForever(id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: Text(context.l10n('trash_bin_delete_forever')),
            ),
          ],
        );
      },
    );
  }

  int _calculateDaysLeft(String deletedAtStr) {
    final deletedAt = DateTime.tryParse(deletedAtStr) ?? DateTime.now();
    final now = DateTime.now();
    final difference = now.difference(deletedAt).inDays;
    final remaining = 30 - difference;
    return remaining < 0 ? 0 : remaining;
  }

  ImageProvider? _getAvatarProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      return NetworkImage(avatarUrl);
    }
    return AssetImage(avatarUrl);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppSettings.instance.primaryColor;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white60 : Colors.black54;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF30363D) : Colors.grey.shade200;

    // Filter by extensible category
    final displayedItems = _deletedCustomers.where((c) {
      final isDraft = c['status'] == 'draft' || c['status'] == 'discarded_draft';
      if (_activeCategory == TrashCategory.customer) return !isDraft;
      if (_activeCategory == TrashCategory.draftCustomer) return isDraft;
      if (_activeCategory == TrashCategory.schedule) return false; // Extensible placeholder
      return true;
    }).toList();

    final draftCount = _deletedCustomers.where((c) => c['status'] == 'draft' || c['status'] == 'discarded_draft').length;
    final activeCount = _deletedCustomers.length - draftCount;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading && _deletedCustomers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(Icons.delete_sweep_outlined, color: primaryColor, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            context.l10n('trash_bin'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_deletedCustomers.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: primaryColor.withOpacity(0.5)),
                              ),
                              child: Text(
                                _deletedCustomers.length.toString(),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '已刪除項目將保留 30 天，可依據「正式客戶」與「語音草稿」分類進行精準復原或永久銷毀。',
                        style: TextStyle(
                          fontSize: 13,
                          color: subTextColor,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 🏷️ 可擴展分類 Filter Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: TrashCategory.values.map((cat) {
                            final isSelected = _activeCategory == cat;
                            int count = 0;
                            if (cat == TrashCategory.all) count = _deletedCustomers.length;
                            else if (cat == TrashCategory.customer) count = activeCount;
                            else if (cat == TrashCategory.draftCustomer) count = draftCount;
                            else if (cat == TrashCategory.schedule) count = 0;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                avatar: Icon(cat.icon, size: 14, color: isSelected ? Colors.white : primaryColor),
                                label: Text('${cat.label} ($count)', style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                selected: isSelected,
                                onSelected: (_) => setState(() => _activeCategory = cat),
                                selectedColor: primaryColor,
                                labelStyle: TextStyle(color: isSelected ? Colors.white : textColor),
                                checkmarkColor: Colors.white,
                                backgroundColor: cardBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: isSelected ? primaryColor : borderColor),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // List / Grid
                      Expanded(
                        child: displayedItems.isEmpty
                            ? _buildEmptyState(isDark, subTextColor)
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  int crossAxisCount = 1;
                                  if (constraints.maxWidth >= 900) {
                                    crossAxisCount = 3;
                                  } else if (constraints.maxWidth >= 600) {
                                    crossAxisCount = 2;
                                  }

                                  return GridView.builder(
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      mainAxisExtent: 220,
                                    ),
                                    itemCount: displayedItems.length,
                                    itemBuilder: (context, index) {
                                      final customer = displayedItems[index];
                                      final daysLeft = _calculateDaysLeft(customer['deleted_at'] ?? DateTime.now().toIso8601String());
                                      
                                      return _buildDeletedCustomerCard(
                                        customer: customer,
                                        daysLeft: daysLeft,
                                        cardBg: cardBg,
                                        borderColor: borderColor,
                                        textColor: textColor,
                                        subTextColor: subTextColor,
                                        primaryColor: primaryColor,
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_outline_rounded,
            size: 80,
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '此分類目前無任何垃圾項目',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '所有被刪除或捨棄的檔案將在此妥善保存 30 天。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: subTextColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedCustomerCard({
    required Map<String, dynamic> customer,
    required int daysLeft,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subTextColor,
    required Color primaryColor,
  }) {
    final avatarUrl = customer['avatar_url'] ?? '';
    final ImageProvider? avatarProvider = _getAvatarProvider(avatarUrl);
    final bool isDraft = customer['status'] == 'draft' || customer['status'] == 'discarded_draft';

    // Color code days left warning
    Color daysLeftColor = Colors.green;
    if (daysLeft <= 7) {
      daysLeftColor = Colors.redAccent;
    } else if (daysLeft <= 15) {
      daysLeftColor = Colors.amber;
    }

    final cardBorder = isDraft ? const Color(0xFFF59E0B).withOpacity(0.4) : borderColor;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: isDraft ? 1.5 : 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar & Type Badge & Days Left
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isDraft ? const Color(0xFFF59E0B).withOpacity(0.15) : primaryColor.withOpacity(0.1),
                  backgroundImage: avatarProvider,
                  child: avatarProvider == null
                      ? Text(
                          (customer['name'] ?? '?').substring(0, 1),
                          style: TextStyle(
                            color: isDraft ? const Color(0xFFF59E0B) : primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customer['name'] ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isDraft ? const Color(0xFFF59E0B) : const Color(0xFF0EA5E9)).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isDraft ? '🟡 語音速記草稿' : '👥 正式客戶',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDraft ? const Color(0xFFF59E0B) : const Color(0xFF0EA5E9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Days left badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: daysLeftColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: daysLeftColor.withOpacity(0.4), width: 1),
                  ),
                  child: Text(
                    '剩 $daysLeft 天',
                    style: TextStyle(
                      color: daysLeftColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Content snippet (phone or notes)
            Expanded(
              child: Text(
                isDraft
                    ? (customer['notes'] != null && customer['notes'].toString().isNotEmpty ? '速記摘要: ${customer['notes']}' : '無語音錄音摘要')
                    : '聯絡電話: ${customer['phone'] ?? '未填寫'} · 標籤: ${(customer['tags'] as List).join(', ')}',
                style: TextStyle(
                  fontSize: 11,
                  color: subTextColor,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const Divider(height: 12),

            // Action Buttons (Restore & Delete Forever)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showDeleteForeverConfirm(customer['id'], customer['name'] ?? ''),
                  icon: const Icon(Icons.delete_forever_rounded, size: 14, color: Colors.redAccent),
                  label: const Text('永久刪除', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    side: const BorderSide(color: Colors.redAccent, width: 0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _restoreCustomer(customer['id'], isDraft),
                  icon: const Icon(Icons.restore_from_trash_rounded, size: 14),
                  label: Text(isDraft ? '還原草稿' : '還原客戶', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
