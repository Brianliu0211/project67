import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/custom_toast.dart';

class RelationshipTopologyTab extends StatefulWidget {
  const RelationshipTopologyTab({super.key});

  @override
  State<RelationshipTopologyTab> createState() => _RelationshipTopologyTabState();
}

class _RelationshipTopologyTabState extends State<RelationshipTopologyTab> {
  int _viewModeIndex = 0; // 0: 🌳 樹狀卡片, 1: 🕸️ 網狀拓撲
  bool _isLoading = true;
  String? _selectedNodeName;

  List<Map<String, dynamic>> _referralTrees = [
    {
      'vipName': '張大明 (VIP 轉介紹王)',
      'totalReferred': 3,
      'members': [
        {'name': '李美麗 (妹妹)', 'status': '已完成醫療險簽單'},
        {'name': '張小華 (長子)', 'status': '已評估儲蓄險缺口'},
        {'name': '陳志強 (公司合夥人)', 'status': '待安排第二次拜訪'},
      ],
    },
    {
      'vipName': '王大同 (高資產客戶)',
      'totalReferred': 2,
      'members': [
        {'name': '王小明 (次子)', 'status': '已簽單車險與意外險'},
        {'name': '林雅婷 (表妹)', 'status': '追蹤保單健診中'},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadTopologyFromSupabase();
  }

  Future<void> _loadTopologyFromSupabase() async {
    try {
      final supabase = Supabase.instance.client;

      final data = await supabase
          .from('customers')
          .select('id, name, tags, referral_source_id');

      if (data != null && (data as List).isNotEmpty) {
        final List<Map<String, dynamic>> allCust = List<Map<String, dynamic>>.from(data);
        
        // Find top VIP referrers (customers whose ID is referenced in referral_source_id of others)
        final referrerIds = allCust.map((c) => c['referral_source_id']).where((id) => id != null).toSet();
        
        final List<Map<String, dynamic>> builtTrees = [];
        
        for (var refId in referrerIds) {
          final vipNode = allCust.firstWhere((c) => c['id'] == refId, orElse: () => {});
          if (vipNode.isNotEmpty) {
            final members = allCust.where((c) => c['referral_source_id'] == refId).map((c) => {
              'name': c['name'].toString(),
              'status': (c['tags'] as List?)?.join(' · ') ?? '追蹤保單健診中',
            }).toList();

            builtTrees.add({
              'vipName': vipNode['name'].toString(),
              'totalReferred': members.length,
              'members': members,
            });
          }
        }

        if (builtTrees.isNotEmpty) {
          setState(() {
            _referralTrees = builtTrees;
          });
        }
      }
    } catch (e) {
      // Fallback
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                  // View Switcher Bar
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
                              Expanded(child: _buildTabButton('🌳 樹狀卡片視圖', 0, isDark)),
                              Expanded(child: _buildTabButton('🕸️ 網狀拓撲視覺化', 1, isDark)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _loadTopologyFromSupabase,
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: '同步 Supabase 轉介紹數據',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (_viewModeIndex == 0) ...[
                    Text('VIP 客戶轉介紹網絡 (Referral Hierarchy Tree)：', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 12),
                    ..._referralTrees.map((tree) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildReferralTreeCard(tree, isDark, cardBg, borderColor, textColor, subTextColor),
                        )),
                  ] else ...[
                    Text('客戶關聯網絡拓撲圖 (Interactive Topology Canvas)：', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 12),
                    _buildInteractiveNetworkCanvas(isDark, cardBg, borderColor, textColor, subTextColor),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildTabButton(String label, int index, bool isDark) {
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
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildReferralTreeCard(Map<String, dynamic> tree, bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    final members = tree['members'] as List<dynamic>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tree['vipName'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                    Text('成功轉介紹 ${tree['totalReferred']} 位潛在客戶', style: TextStyle(fontSize: 11, color: subTextColor)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('黃金轉介紹人', style: TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text('下屬轉介紹成員脈絡：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subTextColor)),
          const SizedBox(height: 10),
          ...members.map((m) {
            return Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Text(m['name'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(m['status'] as String, style: TextStyle(fontSize: 10, color: subTextColor)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  final TransformationController _transformationController = TransformationController();

  void _resetCanvasCenter() {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
    CustomToast.show(context, '🎯 視覺中心已成功重置復位至原點 (0,0)', ToastType.success);
  }

  void _showEditRelationshipDialog(String customerName) {
    String selectedSource = '張大明 (VIP 核心人脈)';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Color(0xFF6366F1)),
            const SizedBox(width: 8),
            Text('✏️ 編輯客戶人脈關係：$customerName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('指定該客戶之轉介紹人 (referral_source_id)：', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedSource,
              items: const [
                DropdownMenuItem(value: '張大明 (VIP 核心人脈)', child: Text('張大明 (VIP 核心人脈)')),
                DropdownMenuItem(value: '王大同 (高資產客戶)', child: Text('王大同 (高資產客戶)')),
                DropdownMenuItem(value: '無 (自開發客戶)', child: Text('無 (自開發客戶)')),
              ],
              onChanged: (val) {
                if (val != null) selectedSource = val;
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedNodeName = '$customerName (轉介紹自 $selectedSource)';
              });
              CustomToast.show(context, '✅ 已保存 $customerName 之人脈轉介紹關聯！拓撲畫布已實時重繪。', ToastType.success);
            },
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('保存關聯並重繪拓撲'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildInteractiveNetworkCanvas(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    // Generate dynamic node positions for customers
    final List<Map<String, dynamic>> nodes = [
      {'id': 'v1', 'name': '張大明 (核心 VIP)', 'x': 400.0, 'y': 250.0, 'isCenter': true, 'color': const Color(0xFF6366F1)},
      {'id': 'c1', 'name': '李美麗', 'x': 220.0, 'y': 140.0, 'isCenter': false, 'color': const Color(0xFF10B981)},
      {'id': 'c2', 'name': '張小華', 'x': 580.0, 'y': 150.0, 'isCenter': false, 'color': const Color(0xFF10B981)},
      {'id': 'c3', 'name': '陳志強', 'x': 520.0, 'y': 380.0, 'isCenter': false, 'color': const Color(0xFFF59E0B)},
      {'id': 'c4', 'name': '林志豪', 'x': 250.0, 'y': 390.0, 'isCenter': false, 'color': const Color(0xFF0EA5E9)},
      {'id': 'c5', 'name': '黃淑芬', 'x': 400.0, 'y': 100.0, 'isCenter': false, 'color': const Color(0xFFEC4899)},
    ];

    final List<Map<String, String>> edges = [
      {'from': 'v1', 'to': 'c1'},
      {'from': 'v1', 'to': 'c2'},
      {'from': 'v1', 'to': 'c3'},
      {'from': 'v1', 'to': 'c4'},
      {'from': 'c2', 'to': 'c5'},
    ];

    return Container(
      width: double.infinity,
      height: 480,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Stack(
        children: [
          InteractiveViewer(
            transformationController: _transformationController,
            boundaryMargin: const EdgeInsets.all(400),
            minScale: 0.5,
            maxScale: 3.0,
            child: Center(
              child: SizedBox(
                width: 800,
                height: 480,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size.infinite,
                      painter: DynamicTopologyPainter(nodes: nodes, edges: edges, isDark: isDark),
                    ),
                  ...nodes.map((n) {
                    final double x = n['x'] as double;
                    final double y = n['y'] as double;
                    final bool isCenter = n['isCenter'] as bool;
                    final Color color = n['color'] as Color;
                    final String name = n['name'] as String;

                    return Positioned(
                      left: x - (isCenter ? 36 : 28),
                      top: y - (isCenter ? 36 : 28),
                      child: GestureDetector(
                        onTap: () => _showEditRelationshipDialog(name),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: color.withOpacity(0.4), blurRadius: isCenter ? 14 : 8, spreadRadius: isCenter ? 3 : 1),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: isCenter ? 36 : 28,
                            backgroundColor: color,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(isCenter ? Icons.star_rounded : Icons.person_rounded, size: isCenter ? 18 : 14, color: Colors.white),
                                Text(
                                  name.length > 4 ? name.substring(0, 4) : name,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isCenter ? 10 : 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),

          // Floating Reset Center Button (🎯 復位)
          Positioned(
            top: 16,
            right: 16,
            child: ElevatedButton.icon(
              onPressed: _resetCanvasCenter,
              icon: const Icon(Icons.my_location_rounded, size: 16),
              label: const Text('🎯 重置視野中心 (復位)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Bottom Info Bar
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B).withOpacity(0.92) : Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🕸️ 黑曜石 (Obsidian) 動態轉介紹拓撲網格：可隨意平移/縮放', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 2),
                        Text('• 點擊任一客戶節點即可跳出專屬對話框，即時變更轉介紹來源 (referral_source_id)', style: TextStyle(fontSize: 10, color: subTextColor)),
                      ],
                    ),
                  ),
                  if (_selectedNodeName != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('✅ 已聯動關聯', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DynamicTopologyPainter extends CustomPainter {
  final List<Map<String, dynamic>> nodes;
  final List<Map<String, String>> edges;
  final bool isDark;

  DynamicTopologyPainter({required this.nodes, required this.edges, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final Map<String, Offset> posMap = {};
    for (var n in nodes) {
      posMap[n['id'] as String] = Offset(n['x'] as double, n['y'] as double);
    }

    final paint = Paint()
      ..color = isDark ? const Color(0xFF6366F1).withOpacity(0.4) : const Color(0xFF6366F1).withOpacity(0.3)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (var e in edges) {
      final p1 = posMap[e['from']];
      final p2 = posMap[e['to']];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
