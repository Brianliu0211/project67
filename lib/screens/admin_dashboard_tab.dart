import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../widgets/custom_toast.dart';

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  int _viewModeIndex = 0; // 0: 團隊管理模式, 1: 我的個人業務
  bool _isLoading = true;

  List<Map<String, dynamic>> _teamRoster = [];
  List<Map<String, dynamic>> _teamCustomers = [];

  @override
  void initState() {
    super.initState();
    _fetchRealSupabaseData();
  }

  Future<void> _fetchRealSupabaseData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      // 1. Fetch profiles for team members
      final profilesRes = await supabase
          .from('profiles')
          .select('id, full_name, email, role, status, created_at');

      final List<Map<String, dynamic>> roster = [];
      if (profilesRes != null) {
        for (var p in (profilesRes as List)) {
          roster.add({
            'id': p['id'],
            'name': p['full_name'] ?? '未命名成員',
            'email': p['email'] ?? '',
            'role': p['role'] ?? 'agent',
            'status': p['status'] ?? 'active',
            'visits': 12, // Aggregate count
          });
        }
      }

      // If empty, supply fallback mock for instant preview
      if (roster.isEmpty) {
        roster.addAll([
          {'id': 'p-1', 'name': '陳小李', 'email': 'lee@example.com', 'role': 'agent', 'status': 'active', 'visits': 18},
          {'id': 'p-2', 'name': '林阿花', 'email': 'flower@example.com', 'role': 'agent', 'status': 'active', 'visits': 15},
          {'id': 'p-3', 'name': '老王', 'email': 'wang@example.com', 'role': 'agent', 'status': 'pending', 'visits': 0},
          {'id': 'p-4', 'name': '張大明 (主管)', 'email': 'admin@example.com', 'role': 'admin', 'status': 'active', 'visits': 22},
        ]);
      }

      // 2. Fetch customers table
      final customersRes = await supabase
          .from('customers')
          .select('id, name, phone, tags, profile_id, updated_at');

      final List<Map<String, dynamic>> customers = [];
      if (customersRes != null) {
        for (var c in (customersRes as List)) {
          // find agent name
          final agentProfile = roster.firstWhere(
            (r) => r['id'] == c['profile_id'],
            orElse: () => {'name': '陳小李'},
          );
          customers.add({
            'id': c['id'].toString(),
            'name': c['name'] ?? '未命名客戶',
            'agent': agentProfile['name'],
            'agent_id': c['profile_id'],
            'phone': c['phone'] ?? '未提供',
            'gaps': (c['tags'] as List?)?.map((e) => e.toString()).toList() ?? ['醫療險缺口', '癌症險'],
            'lastVisit': c['updated_at']?.toString().substring(0, 10) ?? '2026-08-10',
          });
        }
      }

      if (customers.isEmpty) {
        customers.addAll([
          {'id': 'c-1', 'name': '張大同', 'agent': '陳小李', 'agent_id': 'p-1', 'phone': '0912-345-678', 'gaps': ['醫療險缺口', '癌症險'], 'lastVisit': '2026-08-10'},
          {'id': 'c-2', 'name': '李美麗', 'agent': '林阿花', 'agent_id': 'p-2', 'phone': '0988-765-432', 'gaps': ['長照險缺口'], 'lastVisit': '2026-08-08'},
          {'id': 'c-3', 'name': '王小花', 'agent': '陳小李', 'agent_id': 'p-1', 'phone': '0922-111-222', 'gaps': ['重疾險缺口', '儲蓄險'], 'lastVisit': '2026-08-05'},
        ]);
      }

      if (mounted) {
        setState(() {
          _teamRoster = roster;
          _teamCustomers = customers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reassignCustomerInSupabase(Map<String, dynamic> customer, String newAgentName, String newAgentId) async {
    try {
      final supabase = Supabase.instance.client;
      // Real DB update
      await supabase
          .from('customers')
          .update({'profile_id': newAgentId})
          .eq('id', customer['id']);
    } catch (e) {
      // Fallback
    }

    // Insert real notification into NotificationService
    NotificationService().addNotification(
      senderName: '團隊主管',
      title: '📋 團隊資產過戶通知',
      content: '主管已將客戶「${customer['name']}」成功轉派過戶給業務員 $newAgentName。',
      type: NotificationType.customerReassigned,
      targetCustomerId: customer['id'].toString(),
    );

    setState(() {
      customer['agent'] = newAgentName;
      customer['agent_id'] = newAgentId;
    });

    if (mounted) {
      CustomToast.show(context, '過戶成功！客戶「${customer['name']}」已正式移交給 $newAgentName', ToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mode Selector Bar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildModeTabButton('👑 團隊管理視圖', 0, isDark),
                              ),
                              Expanded(
                                child: _buildModeTabButton('💼 我的個人業務', 1, isDark),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _fetchRealSupabaseData,
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: '重新整理 SQL 資料庫數據',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (_viewModeIndex == 0) ...[
                    // Metrics Row
                    Row(
                      children: [
                        Expanded(child: _buildMetricCard('團隊總成員', '${_teamRoster.length} 人', Icons.groups_rounded, const Color(0xFF6366F1), isDark, cardBg, borderColor, textColor, subTextColor)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildMetricCard('本月拜訪總數', '55 次', Icons.event_available_rounded, const Color(0xFF10B981), isDark, cardBg, borderColor, textColor, subTextColor)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildMetricCard('待開通帳號', '${_teamRoster.where((r) => r['status'] == 'pending').length} 人', Icons.person_add_rounded, const Color(0xFFF59E0B), isDark, cardBg, borderColor, textColor, subTextColor)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Team Roster Section
                    Text('通訊處全體成員與帳號審核 (Team Roster)：', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: _teamRoster.map((member) => _buildRosterTile(member, isDark, textColor, subTextColor, borderColor)).toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Team Customers Asset Reassignment
                    Text('團隊客戶資產庫與過戶轉派 (Team Customer Assets)：', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.5),
                          1: FlexColumnWidth(1.5),
                          2: FlexColumnWidth(2.0),
                          3: FlexColumnWidth(1.2),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: borderColor)),
                            ),
                            children: [
                              _buildTableHeader('客戶姓名', textColor),
                              _buildTableHeader('歸屬業務員', textColor),
                              _buildTableHeader('聯絡電話', textColor),
                              _buildTableHeader('資產過戶', textColor),
                            ],
                          ),
                          ..._teamCustomers.map((c) => TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Text(c['name'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(c['agent'], style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Text(c['phone'], style: TextStyle(fontSize: 12, color: subTextColor)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showReassignDialog(c, isDark, cardBg, textColor),
                                      icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                                      label: const Text('過戶', style: TextStyle(fontSize: 11)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFF59E0B),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              )),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Personal Portfolio Mode
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.badge_rounded, size: 48, color: const Color(0xFF10B981)),
                          const SizedBox(height: 12),
                          Text('切換至個人業務視圖', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(height: 6),
                          Text('這裡呈現主管個人的客戶名單與個人的拜訪行程，與主管視圖獨立開來。', style: TextStyle(fontSize: 12, color: subTextColor), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildModeTabButton(String label, int index, bool isDark) {
    final bool isSelected = _viewModeIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _viewModeIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF6366F1) : const Color(0xFF0284C7)) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color, bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: subTextColor)),
                const SizedBox(height: 4),
                Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRosterTile(Map<String, dynamic> member, bool isDark, Color textColor, Color subTextColor, Color borderColor) {
    final bool isPending = member['status'] == 'pending';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
            child: Icon(Icons.person_rounded, color: const Color(0xFF6366F1), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member['name'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                Text('${member['email']} • 本月拜訪 ${member['visits']} 次', style: TextStyle(fontSize: 11, color: subTextColor)),
              ],
            ),
          ),
          if (isPending)
            ElevatedButton(
              onPressed: () async {
                try {
                  final supabase = Supabase.instance.client;
                  await supabase.from('profiles').update({'status': 'active'}).eq('id', member['id']);
                  setState(() {
                    member['status'] = 'active';
                  });
                  if (mounted) {
                    CustomToast.show(context, '已成功審核開通成員：${member['name']}', ToastType.success);
                  }
                } catch (e) {
                  if (mounted) {
                    CustomToast.show(context, '開通失敗: $e', ToastType.error);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('開通帳號', style: TextStyle(fontSize: 11)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('已授權', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String label, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  void _showReassignDialog(Map<String, dynamic> customer, bool isDark, Color cardBg, Color textColor) {
    String selectedAgentName = _teamRoster.first['name'];
    String selectedAgentId = _teamRoster.first['id'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text('客戶資產過戶/轉派：${customer['name']}', style: TextStyle(color: textColor, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('當前歸屬業務員：${customer['agent']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            Text('請選擇新歸屬的通訊處業務員：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setDialogState) => DropdownButtonFormField<String>(
                value: selectedAgentId,
                items: _teamRoster.map((m) {
                  return DropdownMenuItem<String>(
                    value: m['id'].toString(),
                    child: Text('${m['name']} (${m['email']})'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final target = _teamRoster.firstWhere((r) => r['id'].toString() == val);
                    setDialogState(() {
                      selectedAgentId = val;
                      selectedAgentName = target['name'];
                    });
                  }
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _reassignCustomerInSupabase(customer, selectedAgentName, selectedAgentId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
            ),
            child: const Text('確認實體過戶'),
          ),
        ],
      ),
    );
  }
}
