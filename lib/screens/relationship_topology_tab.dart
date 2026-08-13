import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import '../main.dart';
import '../services/customer_relationship_service.dart';
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
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _relationships = [];
  List<Map<String, dynamic>> _referralTrees = [];

  List<Map<String, dynamic>> _computedNodes = [];
  List<Map<String, dynamic>> _computedEdges = [];

  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _loadTopologyFromSupabase();
  }

  Future<void> _loadTopologyFromSupabase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      List<Map<String, dynamic>> loadedCust = [];

      final data = await supabase
          .from('customers')
          .select('id, name, nickname, phone, tags, referral_source_id');

      if (data != null && (data as List).isNotEmpty) {
        loadedCust = List<Map<String, dynamic>>.from(data);
      } else {
        loadedCust = List<Map<String, dynamic>>.from(OfflineDataStore.customers);
      }

      final loadedRels = await CustomerRelationshipService.fetchAllRelationships();

      _allCustomers = loadedCust;
      _relationships = loadedRels;

      // 1. Build Referral Trees for View Mode 0
      final referrerIds = _allCustomers
          .map((c) => c['referral_source_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toSet();

      final List<Map<String, dynamic>> builtTrees = [];

      for (var refId in referrerIds) {
        final vipNode = _allCustomers.firstWhere((c) => c['id'].toString() == refId, orElse: () => {});
        if (vipNode.isNotEmpty) {
          final members = _allCustomers.where((c) => c['referral_source_id']?.toString() == refId).map((c) {
            final tagsList = c['tags'] as List?;
            final statusStr = (tagsList != null && tagsList.isNotEmpty) ? tagsList.join(' · ') : '追蹤保單健診中';
            return {
              'id': c['id'].toString(),
              'name': c['name'].toString(),
              'status': statusStr,
            };
          }).toList();

          builtTrees.add({
            'vipId': vipNode['id'].toString(),
            'vipName': vipNode['name'].toString(),
            'totalReferred': members.length,
            'members': members,
          });
        }
      }

      _referralTrees = builtTrees;

      // 2. Build Cluster Island Graph Topology for View Mode 1
      _calculateClusterIslandTopology();

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

  /// Connected Component Cluster Island Layout Algorithm with Greedy Adjacent Angular Sorting
  void _calculateClusterIslandTopology() {
    if (_allCustomers.isEmpty) {
      _computedNodes = [];
      _computedEdges = [];
      return;
    }

    final Map<String, Set<String>> adjMap = {};
    for (var c in _allCustomers) {
      adjMap[c['id'].toString()] = {};
    }

    // Build edges list first
    final List<Map<String, dynamic>> edges = [];

    // Edges - Dimension 1: Referral
    for (var c in _allCustomers) {
      final targetId = c['id'].toString();
      final sourceId = c['referral_source_id']?.toString();
      if (sourceId != null && sourceId.isNotEmpty && adjMap.containsKey(sourceId)) {
        adjMap[sourceId]!.add(targetId);
        adjMap[targetId]!.add(sourceId);

        edges.add({
          'from': sourceId,
          'to': targetId,
          'type': 'referral',
          'label': '轉介紹',
          'color': const Color(0xFF10B981),
        });
      }
    }

    // Edges - Dimension 2: Social Relationships
    for (var r in _relationships) {
      final s = r['source_customer_id']?.toString();
      final t = r['target_customer_id']?.toString();
      final typeStr = r['relationship_type']?.toString() ?? 'family';
      final detailStr = r['relationship_detail']?.toString() ?? '';

      if (s != null && t != null && adjMap.containsKey(s) && adjMap.containsKey(t)) {
        adjMap[s]!.add(t);
        adjMap[t]!.add(s);

        Color edgeColor = const Color(0xFF0EA5E9);
        String defaultLabel = '關聯';
        if (typeStr == 'family') { edgeColor = const Color(0xFF06B6D4); defaultLabel = '親眷'; }
        else if (typeStr == 'workplace') { edgeColor = const Color(0xFFF59E0B); defaultLabel = '同事'; }
        else if (typeStr == 'social') { edgeColor = const Color(0xFF8B5CF6); defaultLabel = '社友'; }
        else { edgeColor = const Color(0xFF6B7280); defaultLabel = '朋友'; }

        edges.add({
          'from': s,
          'to': t,
          'type': typeStr,
          'label': detailStr.isNotEmpty ? detailStr : defaultLabel,
          'color': edgeColor,
        });
      }
    }

    // Graph Connected Component Decomposition (BFS)
    final Set<String> visited = {};
    final List<List<String>> components = [];

    for (var c in _allCustomers) {
      final id = c['id'].toString();
      if (!visited.contains(id)) {
        final List<String> comp = [];
        final List<String> queue = [id];
        visited.add(id);

        while (queue.isNotEmpty) {
          final curr = queue.removeAt(0);
          comp.add(curr);
          for (var neighbor in adjMap[curr] ?? {}) {
            if (!visited.contains(neighbor)) {
              visited.add(neighbor);
              queue.add(neighbor);
            }
          }
        }
        components.add(comp);
      }
    }

    // Sort components by size descending (largest component is Main Island)
    components.sort((a, b) => b.length.compareTo(a.length));

    final Map<String, Map<String, dynamic>> custMap = {
      for (var c in _allCustomers) c['id'].toString(): c
    };

    final List<Map<String, dynamic>> nodes = [];

    // Slots for secondary islands around canvas
    final List<Offset> islandSlots = [
      const Offset(130.0, 110.0), // Top-Left
      const Offset(670.0, 110.0), // Top-Right
      const Offset(670.0, 370.0), // Bottom-Right
      const Offset(130.0, 370.0), // Bottom-Left
    ];

    int islandSlotIdx = 0;
    int isolatedCount = 0;

    for (int compIdx = 0; compIdx < components.length; compIdx++) {
      final comp = components[compIdx];

      if (compIdx == 0) {
        // Main Island: Center placed at (380, 240)
        final double centerX = 380.0;
        final double centerY = 240.0;

        // Find hub node with max degrees in main component
        comp.sort((a, b) => (adjMap[b]?.length ?? 0).compareTo(adjMap[a]?.length ?? 0));
        final String hubId = comp.first;

        // Sort outer ring nodes by adjacency to minimize edge crossings
        final List<String> outerNodes = comp.sublist(1);
        final List<String> orderedOuter = [];
        final Set<String> placedOuter = {};

        while (placedOuter.length < outerNodes.length) {
          final unplaced = outerNodes.where((id) => !placedOuter.contains(id)).toList();
          if (unplaced.isEmpty) break;

          unplaced.sort((a, b) {
            final aConn = adjMap[a]!.intersection(placedOuter).length;
            final bConn = adjMap[b]!.intersection(placedOuter).length;
            if (aConn != bConn) return bConn.compareTo(aConn);
            return (adjMap[b]?.length ?? 0).compareTo(adjMap[a]?.length ?? 0);
          });

          final nextNode = unplaced.first;
          orderedOuter.add(nextNode);
          placedOuter.add(nextNode);
        }

        final List<String> sortedComp = [hubId, ...orderedOuter];
        final int compLen = sortedComp.length;

        for (int i = 0; i < compLen; i++) {
          final id = sortedComp[i];
          final cust = custMap[id] ?? {};
          final name = cust['name']?.toString() ?? '未知';
          final degree = adjMap[id]?.length ?? 0;
          final bool isCenter = (i == 0);

          double x, y;
          if (i == 0) {
            x = centerX;
            y = centerY;
          } else {
            final angle = (i - 1) * (2 * math.pi / math.max(1, compLen - 1));
            final radius = (compLen > 6 && i > 6) ? 300.0 : 210.0;
            x = centerX + radius * math.cos(angle);
            y = centerY + radius * math.sin(angle);
          }

          Color nodeColor = const Color(0xFF0EA5E9);
          if (isCenter) nodeColor = const Color(0xFF6366F1);
          else if (degree > 1) nodeColor = const Color(0xFF10B981);
          else if (degree == 1) nodeColor = const Color(0xFFF59E0B);

          nodes.add({
            'id': id,
            'name': name,
            'customer': cust,
            'x': x,
            'y': y,
            'isCenter': isCenter,
            'degree': degree,
            'color': nodeColor,
          });
        }
      } else if (comp.length > 1) {
        // Independent Connected Sub-Islands (e.g. 5-6 pair)
        final Offset islandCenter = islandSlots[islandSlotIdx % islandSlots.length];
        islandSlotIdx++;

        final int compLen = comp.length;
        for (int i = 0; i < compLen; i++) {
          final id = comp[i];
          final cust = custMap[id] ?? {};
          final name = cust['name']?.toString() ?? '未知';
          final degree = adjMap[id]?.length ?? 0;

          final angle = i * (2 * math.pi / compLen);
          final radius = 70.0;
          final x = islandCenter.dx + radius * math.cos(angle);
          final y = islandCenter.dy + radius * math.sin(angle);

          nodes.add({
            'id': id,
            'name': name,
            'customer': cust,
            'x': x,
            'y': y,
            'isCenter': false,
            'degree': degree,
            'color': const Color(0xFFF59E0B),
          });
        }
      } else {
        // Completely Isolated Single Customer
        final double startAngle = math.pi / 2;
        final double radius = 350.0;
        final angle = startAngle + isolatedCount * (math.pi / 8);
        isolatedCount++;

        final x = 380.0 + radius * math.cos(angle);
        final y = 240.0 + radius * math.sin(angle);

        nodes.add({
          'id': comp[0],
          'name': custMap[comp[0]]?['name']?.toString() ?? '未知',
          'customer': custMap[comp[0]] ?? {},
          'x': x,
          'y': y,
          'isCenter': false,
          'degree': 0,
          'color': const Color(0xFF6B7280),
        });
      }
    }

    _computedNodes = nodes;
    _computedEdges = edges;
  }

  void _resetCanvasCenter() {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
    CustomToast.show(context, '🎯 視野中心已成功重置復位', ToastType.success);
  }

  void _showEditRelationshipDialog(Map<String, dynamic> customer) async {
    final customerId = customer['id'].toString();
    String? currentReferralId = customer['referral_source_id']?.toString();

    List<Map<String, dynamic>> rels = await CustomerRelationshipService.fetchAllRelationships();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final myRels = rels.where((r) =>
              r['source_customer_id'].toString() == customerId ||
              r['target_customer_id'].toString() == customerId
            ).toList();

            final otherCustomers = _allCustomers.where((c) => c['id'].toString() != customerId).toList();

            String? selectedTargetId = otherCustomers.isNotEmpty ? otherCustomers.first['id'].toString() : null;
            String selectedType = 'family';
            final detailController = TextEditingController(text: '親眷');

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.hub_rounded, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '👥 管理人脈與轉介紹：${customer['name']}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📌 維度 1：轉介紹歸因 (Referral Source)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                      const SizedBox(height: 4),
                      const Text('指定是哪位已有客戶將此人轉介紹給您：', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        value: otherCustomers.any((c) => c['id'].toString() == currentReferralId) ? currentReferralId : null,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('無 (自開發 / 獨立客戶)'),
                          ),
                          ...otherCustomers.map((c) => DropdownMenuItem<String?>(
                            value: c['id'].toString(),
                            child: Text('${c['name']} ${c['phone'] != null && c['phone'].toString().isNotEmpty ? "(${c['phone']})" : ""}'),
                          )),
                        ],
                        onChanged: (val) async {
                          currentReferralId = val;
                          await CustomerRelationshipService.updateReferralSource(
                            customerId: customerId,
                            referralSourceId: val,
                          );
                          setState(() {
                            customer['referral_source_id'] = val;
                          });
                          await _loadTopologyFromSupabase();
                          setDialogState(() {});
                          CustomToast.show(context, '✅ 已更新轉介紹來源，拓撲畫布已重繪！', ToastType.success);
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      const Text('🕸️ 維度 2：社交角色關係 (Social Relationships)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      const SizedBox(height: 4),
                      const Text('建立與其他客戶的親眷、職場、社團關係：', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 10),

                      if (myRels.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('目前尚無社交角色關係紀錄', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        )
                      else
                        ...myRels.map((r) {
                          final bool isSource = r['source_customer_id'].toString() == customerId;
                          final otherId = isSource ? r['target_customer_id'].toString() : r['source_customer_id'].toString();
                          final otherCust = _allCustomers.firstWhere((c) => c['id'].toString() == otherId, orElse: () => {'name': '未知客戶'});
                          final typeStr = r['relationship_type'] ?? 'family';
                          final detailStr = r['relationship_detail'] ?? '';

                          Color tagColor = const Color(0xFF10B981);
                          String typeName = '親眷';
                          if (typeStr == 'workplace') { tagColor = const Color(0xFFF59E0B); typeName = '職場'; }
                          else if (typeStr == 'social') { tagColor = const Color(0xFF8B5CF6); typeName = '社團'; }
                          else if (typeStr == 'other') { tagColor = const Color(0xFF6B7280); typeName = '其他'; }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: tagColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: tagColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tagColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(typeName, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${otherCust['name']} (${detailStr.isNotEmpty ? detailStr : typeName})',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                  onPressed: () async {
                                    await CustomerRelationshipService.deleteRelationship(r['id'].toString());
                                    rels = await CustomerRelationshipService.fetchAllRelationships();
                                    await _loadTopologyFromSupabase();
                                    setDialogState(() {});
                                    CustomToast.show(context, '🗑️ 已解除人脈關係，拓撲畫布已重繪！', ToastType.warning);
                                  },
                                ),
                              ],
                            ),
                          );
                        }),

                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('➕ 新增社交關係：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: selectedTargetId,
                              items: otherCustomers.map((c) => DropdownMenuItem<String>(
                                value: c['id'].toString(),
                                child: Text(c['name'] ?? ''),
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) selectedTargetId = val;
                              },
                              decoration: InputDecoration(
                                labelText: '選擇對象客戶',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: selectedType,
                                    items: const [
                                      DropdownMenuItem(value: 'family', child: Text('親眷')),
                                      DropdownMenuItem(value: 'workplace', child: Text('職場/同事')),
                                      DropdownMenuItem(value: 'social', child: Text('社團/朋友')),
                                      DropdownMenuItem(value: 'other', child: Text('其他')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        selectedType = val;
                                        if (val == 'family') detailController.text = '親眷';
                                        else if (val == 'workplace') detailController.text = '同事';
                                        else if (val == 'social') detailController.text = '社友';
                                        else detailController.text = '朋友';
                                      }
                                    },
                                    decoration: InputDecoration(
                                      labelText: '關係類別',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: detailController,
                                    decoration: InputDecoration(
                                      labelText: '細節描述 (如 夫妻)',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (selectedTargetId != null) {
                                    await CustomerRelationshipService.addRelationship(
                                      sourceCustomerId: customerId,
                                      targetCustomerId: selectedTargetId!,
                                      relationshipType: selectedType,
                                      relationshipDetail: detailController.text.trim(),
                                    );
                                    rels = await CustomerRelationshipService.fetchAllRelationships();
                                    await _loadTopologyFromSupabase();
                                    setDialogState(() {});
                                    CustomToast.show(context, '✅ 成功新增人脈關聯，拓撲畫布已重繪！', ToastType.success);
                                  }
                                },
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('新增關聯'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('關閉'),
                ),
              ],
            );
          },
        );
      },
    );
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
                        tooltip: '同步 Supabase 數據',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (_viewModeIndex == 0) ...[
                    Text('VIP 客戶轉介紹網絡 (Referral Hierarchy Tree)：', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 12),
                    if (_referralTrees.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.nature_people_rounded, size: 48, color: subTextColor),
                            const SizedBox(height: 12),
                            Text('目前尚無轉介紹資料紀錄', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 4),
                            Text('點擊下方或在「客戶管理」卡片背面指定轉介紹人，即可自動生成網絡樹！', style: TextStyle(fontSize: 12, color: subTextColor)),
                          ],
                        ),
                      )
                    else
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


  Widget _buildInteractiveNetworkCanvas(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
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
                      painter: DynamicTopologyPainter(
                        nodes: _computedNodes,
                        edges: _computedEdges,
                        isDark: isDark,
                      ),
                    ),
                    ..._computedNodes.map((n) {
                      final double x = n['x'] as double;
                      final double y = n['y'] as double;
                      final bool isCenter = n['isCenter'] as bool;
                      final Color color = n['color'] as Color;
                      final String name = n['name'] as String;
                      final Map<String, dynamic> cust = n['customer'] as Map<String, dynamic>;

                      return Positioned(
                        left: x - (isCenter ? 36 : 28),
                        top: y - (isCenter ? 36 : 28),
                        child: GestureDetector(
                          onTap: () => _showEditRelationshipDialog(cust),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.4),
                                  blurRadius: isCenter ? 14 : 8,
                                  spreadRadius: isCenter ? 3 : 1,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: isCenter ? 36 : 28,
                              backgroundColor: color,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isCenter ? Icons.star_rounded : Icons.person_rounded,
                                    size: isCenter ? 18 : 14,
                                    color: Colors.white,
                                  ),
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
                    }).toList(),
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
                        Text('🕸️ 黑曜石 (Obsidian) 群島動態拓撲圖：相鄰角度聚類 + 雙向對稱避讓畫布', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 2),
                        Text('• 🟢 轉介紹帶單向箭頭 ➔ | 🔷 藍線: 親眷 | 🟧 橘線: 職場/同事 | 🟣 紫線: 社團/朋友', style: TextStyle(fontSize: 10, color: subTextColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Advanced Dynamic Topology Painter with Canonical Orientation & Absolute Symmetric Multi-Edge Splitting
class DynamicTopologyPainter extends CustomPainter {
  final List<Map<String, dynamic>> nodes;
  final List<Map<String, dynamic>> edges;
  final bool isDark;

  DynamicTopologyPainter({required this.nodes, required this.edges, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final Map<String, Map<String, dynamic>> nodeMap = {};
    for (var n in nodes) {
      nodeMap[n['id'].toString()] = n;
    }

    // Group multi-edges between the exact same pair of nodes (canonical pairKey: idA < idB separated by ':::')
    final Map<String, List<Map<String, dynamic>>> edgeGroupMap = {};

    for (var e in edges) {
      final String fromId = e['from'].toString();
      final String toId = e['to'].toString();
      final pairKey = fromId.compareTo(toId) < 0 ? '$fromId:::$toId' : '$toId:::$fromId';

      if (!edgeGroupMap.containsKey(pairKey)) {
        edgeGroupMap[pairKey] = [];
      }
      edgeGroupMap[pairKey]!.add(e);
    }

    // Render each edge group with canonical vector orientation
    for (var entry in edgeGroupMap.entries) {
      final groupList = entry.value;
      final int groupCount = groupList.length;

      final parts = entry.key.split(':::');
      if (parts.length < 2) continue;

      final String idA = parts[0];
      final String idB = parts[1];
      final nodeA = nodeMap[idA];
      final nodeB = nodeMap[idB];

      if (nodeA == null || nodeB == null) continue;

      // Canonical baseline vector from Node A (lower ID) to Node B (higher ID)
      final pA = Offset(nodeA['x'] as double, nodeA['y'] as double);
      final pB = Offset(nodeB['x'] as double, nodeB['y'] as double);

      final double dx = pB.dx - pA.dx;
      final double dy = pB.dy - pA.dy;
      final double dist = math.sqrt(dx * dx + dy * dy);

      if (dist == 0) continue;

      final double midX = (pA.dx + pB.dx) / 2;
      final double midY = (pA.dy + pB.dy) / 2;

      final double nx = -dy / dist;
      final double ny = dx / dist;

      for (int groupIdx = 0; groupIdx < groupCount; groupIdx++) {
        final e = groupList[groupIdx];
        final String fromId = e['from'].toString();
        final String toId = e['to'].toString();
        final Color strokeColor = (e['color'] as Color?) ?? const Color(0xFF6366F1);
        final String labelStr = (e['label'] as String?) ?? '關聯';
        final String typeStr = (e['type'] as String?) ?? 'social';

        final node1 = nodeMap[fromId]!;
        final node2 = nodeMap[toId]!;
        final p1 = Offset(node1['x'] as double, node1['y'] as double);
        final p2 = Offset(node2['x'] as double, node2['y'] as double);

        final double r1 = (node1['isCenter'] as bool? ?? false) ? 36.0 : 28.0;
        final double r2 = (node2['isCenter'] as bool? ?? false) ? 36.0 : 28.0;

        double curveMagnitude = 0.0;
        double curveSign = 1.0;
        double tLabel = 0.5;

        if (groupCount == 1) {
          curveMagnitude = dist > 220 ? 30.0 : 18.0;
          curveSign = 1.0;
          tLabel = 0.5;
        } else {
          // Absolute symmetric opposing curves relative to canonical pA -> pB vector!
          curveSign = (groupIdx % 2 == 0) ? 1.0 : -1.0;
          curveMagnitude = 36.0 + (groupIdx ~/ 2) * 28.0;

          if (groupIdx == 0) tLabel = 0.38;
          else if (groupIdx == 1) tLabel = 0.62;
          else if (groupIdx == 2) tLabel = 0.28;
          else tLabel = 0.72;
        }

        final double controlX = midX + nx * curveMagnitude * curveSign;
        final double controlY = midY + ny * curveMagnitude * curveSign;

        final path = Path()
          ..moveTo(p1.dx, p1.dy)
          ..quadraticBezierTo(controlX, controlY, p2.dx, p2.dy);

        final linePaint = Paint()
          ..color = strokeColor.withOpacity(0.85)
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke;

        canvas.drawPath(path, linePaint);

        // If Referral edge (type == 'referral'), draw a Directional Arrow pointing towards target p2
        if (typeStr == 'referral') {
          _drawDirectionalArrow(canvas, controlX, controlY, p2, r2, strokeColor);
        }

        // Evaluate point on Bezier curve at t = tLabel
        final double labelX = (1 - tLabel) * (1 - tLabel) * p1.dx + 2 * (1 - tLabel) * tLabel * controlX + tLabel * tLabel * p2.dx;
        final double labelY = (1 - tLabel) * (1 - tLabel) * p1.dy + 2 * (1 - tLabel) * tLabel * controlY + tLabel * tLabel * p2.dy;
        Offset labelPos = Offset(labelX, labelY);

        // Calculate clearance from P1 and P2 node centers
        final double distP1 = (labelPos - p1).distance;
        final double distP2 = (labelPos - p2).distance;
        final double minClearance1 = r1 + 55.0;
        final double minClearance2 = r2 + 55.0;

        if (distP1 < minClearance1 && distP1 > 0) {
          final Offset dir1 = (labelPos - p1) / distP1;
          labelPos = p1 + dir1 * minClearance1;
        }
        if (distP2 < minClearance2 && distP2 > 0) {
          final Offset dir2 = (labelPos - p2) / distP2;
          labelPos = p2 + dir2 * minClearance2;
        }

        // Draw Edge Label Pill at staggered & safe labelPos
        _drawEdgeLabelPill(canvas, labelPos, labelStr, strokeColor, isDark);
      }
    }
  }

  void _drawDirectionalArrow(Canvas canvas, double controlX, double controlY, Offset p2, double r2, Color color) {
    final double vx = p2.dx - controlX;
    final double vy = p2.dy - controlY;
    final double vLen = math.sqrt(vx * vx + vy * vy);

    if (vLen == 0) return;

    final double uX = vx / vLen;
    final double uY = vy / vLen;

    // Arrow tip location touching outer border of target node
    final Offset arrowTip = Offset(p2.dx - uX * (r2 + 4.0), p2.dy - uY * (r2 + 4.0));

    final double pX = -uY;
    final double pY = uX;

    final double arrowSize = 11.0;
    final double arrowWidth = 5.5;

    final Offset wing1 = Offset(
      arrowTip.dx - uX * arrowSize + pX * arrowWidth,
      arrowTip.dy - uY * arrowSize + pY * arrowWidth,
    );
    final Offset wing2 = Offset(
      arrowTip.dx - uX * arrowSize - pX * arrowWidth,
      arrowTip.dy - uY * arrowSize - pY * arrowWidth,
    );

    final arrowPath = Path()
      ..moveTo(arrowTip.dx, arrowTip.dy)
      ..lineTo(wing1.dx, wing1.dy)
      ..lineTo(wing2.dx, wing2.dy)
      ..close();

    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, arrowPaint);
  }

  void _drawEdgeLabelPill(Canvas canvas, Offset center, String text, Color color, bool isDark) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 10.0,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final double paddingH = 7.0;
    final double paddingV = 4.0;
    final double pillWidth = textPainter.width + paddingH * 2;
    final double pillHeight = textPainter.height + paddingV * 2;

    final RRect pillRRect = RRect.fromLTRBR(
      center.dx - pillWidth / 2,
      center.dy - pillHeight / 2,
      center.dx + pillWidth / 2,
      center.dy + pillHeight / 2,
      const Radius.circular(8),
    );

    // Pill background fill (Dark container background with high opacity)
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF0F172A).withOpacity(0.95) : const Color(0xFF1E293B).withOpacity(0.95)
      ..style = PaintingStyle.fill;

    // Pill border line
    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(pillRRect, bgPaint);
    canvas.drawRRect(pillRRect, borderPaint);

    // Render label text
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
