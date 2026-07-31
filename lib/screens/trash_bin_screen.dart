import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../main.dart';
import '../services/app_settings.dart';
import '../services/app_localizations.dart';
import 'customer_management_tab.dart';

class TrashBinScreen extends StatefulWidget {
  const TrashBinScreen({super.key});

  @override
  State<TrashBinScreen> createState() => _TrashBinScreenState();
}

class _TrashBinScreenState extends State<TrashBinScreen> {
  List<Map<String, dynamic>> _deletedCustomers = [];
  bool _isLoading = false;

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

  Future<void> _restoreCustomer(String id) async {
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
        CustomToast.show(context, '${context.l10n('trash_bin_restore_success')} (離線暫存)', ToastType.success);
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
        CustomToast.show(context, context.l10n('trash_bin_restore_success'), ToastType.success);
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
            context.l10n('trash_bin_confirm_delete_forever_desc'),
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
                backgroundColor: Colors.redAccent,
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
    final deletedAt = DateTime.parse(deletedAtStr);
    final now = DateTime.now();
    final difference = now.difference(deletedAt).inDays;
    final remaining = 30 - difference;
    return remaining < 0 ? 0 : remaining;
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
                        context.l10n('trash_bin_desc'),
                        style: TextStyle(
                          fontSize: 13,
                          color: subTextColor,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // List
                      Expanded(
                        child: _deletedCustomers.isEmpty
                            ? _buildEmptyState(isDark, subTextColor)
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  // Determine cross axis count based on screen width
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
                                    itemCount: _deletedCustomers.length,
                                    itemBuilder: (context, index) {
                                      final customer = _deletedCustomers[index];
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
            context.l10n('trash_bin_empty'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n('trash_bin_desc'),
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

    // Color code days left warning
    Color daysLeftColor = Colors.green;
    if (daysLeft <= 7) {
      daysLeftColor = Colors.redAccent;
    } else if (daysLeft <= 15) {
      daysLeftColor = Colors.amber;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
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
            // Top Row: Avatar & Basic Info & Days left badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: primaryColor.withOpacity(0.1),
                  backgroundImage: avatarProvider,
                  child: avatarProvider == null
                      ? Text(
                          (customer['name'] ?? '?').substring(0, 1),
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (customer['nickname'] != null && customer['nickname'].isNotEmpty)
                        Text(
                          '(${customer['nickname']})',
                          style: TextStyle(
                            fontSize: 13,
                            color: subTextColor,
                          ),
                        ),
                    ],
                  ),
                ),
                // Days left badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: daysLeftColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: daysLeftColor.withOpacity(0.4), width: 1),
                  ),
                  child: Text(
                    '$daysLeft ${context.l10n('trash_bin_days_left')}',
                    style: TextStyle(
                      color: daysLeftColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Middle: Phone / Email
            if (customer['phone'] != null && customer['phone'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 14, color: subTextColor),
                    const SizedBox(width: 6),
                    Text(
                      customer['phone'],
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                  ],
                ),
              ),
            
            if (customer['email'] != null && customer['email'].isNotEmpty)
              Row(
                children: [
                  Icon(Icons.mail_outline_rounded, size: 14, color: subTextColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      customer['email'],
                      style: TextStyle(fontSize: 12, color: subTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            
            const Spacer(),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 8),

            // Bottom row: Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _restoreCustomer(customer['id']),
                  icon: const Icon(Icons.restore, size: 16),
                  label: Text(context.l10n('trash_bin_restore')),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showDeleteForeverConfirm(customer['id'], customer['name']),
                  icon: const Icon(Icons.delete_forever, size: 16),
                  label: Text(context.l10n('trash_bin_delete_forever')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Helper to get image provider from URL or Base64 data URI
  ImageProvider? _getAvatarProvider(String avatarUrl) {
    if (avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('data:image/') || avatarUrl.startsWith('data:application/')) {
      try {
        final base64String = avatarUrl.split(',').last;
        return MemoryImage(const Base64Decoder().convert(base64String));
      } catch (e) {
        return null;
      }
    }
    return NetworkImage(avatarUrl);
  }
}
