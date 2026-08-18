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
  String? _selectedNodeId;
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _relationships = [];
  List<Map<String, dynamic>> _referralTrees = [];

  List<Map<String, dynamic>> _computedNodes = [];
  List<Map<String, dynamic>> _computedEdges = [];
  final Map<String, Offset> _nodePositionCache = {};
  Size _lastCanvasContainerSize = const Size(1200, 800);

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
      final user = supabase.auth.currentUser;
      var query = supabase
          .from('customers')
          .select('id, name, nickname, phone, tags, referral_source_id')
          .isFilter('deleted_at', null);

      if (user?.id != null) {
        final profileRes = await supabase.from('profiles').select('role').eq('id', user!.id).maybeSingle();
        final userRole = profileRes?['role']?.toString() ?? 'agent';
        if (userRole != 'dev' && userRole != 'admin') {
          query = query.eq('profile_id', user.id);
        }
      }

      final data = await query;

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
      _calculateClusterIslandTopology(_allCustomers, _relationships);

    } catch (e) {
      // Fallback
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _resetCanvasCenter();
        });
      }
    }
  }

  void _calculateClusterIslandTopology(List<Map<String, dynamic>> customers, List<Map<String, dynamic>> rels) {
    if (customers.isEmpty) {
      if (_allCustomers.isNotEmpty) {
        customers = _allCustomers;
      } else if (OfflineDataStore.customers.isNotEmpty) {
        customers = List<Map<String, dynamic>>.from(OfflineDataStore.customers);
      } else {
        _computedNodes = [];
        _computedEdges = [];
        return;
      }
    }

    final Map<String, Map<String, dynamic>> custMap = {
      for (var c in customers) c['id'].toString(): c,
    };

    final Map<String, Set<String>> adjMap = {
      for (var c in customers) c['id'].toString(): <String>{},
    };

    final List<Map<String, dynamic>> edges = [];
    final Set<String> activeCustIds = {};

    for (var r in rels) {
      final from = r['source_customer_id']?.toString() ?? '';
      final to = r['target_customer_id']?.toString() ?? '';
      final type = r['relationship_type']?.toString() ?? 'other';
      final note = r['notes']?.toString() ?? '';

      if (from.isNotEmpty && to.isNotEmpty && custMap.containsKey(from) && custMap.containsKey(to)) {
        adjMap[from]?.add(to);
        adjMap[to]?.add(from);
        activeCustIds.add(from);
        activeCustIds.add(to);

        Color edgeColor = const Color(0xFF6366F1);
        String label = '關聯';

        switch (type) {
          case 'referral':
            edgeColor = const Color(0xFF10B981);
            label = '轉介紹';
            break;
          case 'family':
            edgeColor = const Color(0xFF0EA5E9);
            label = note.isNotEmpty ? note : '親眷';
            break;
          case 'colleague':
            edgeColor = const Color(0xFFF59E0B);
            label = note.isNotEmpty ? note : '同事';
            break;
          case 'social':
            edgeColor = const Color(0xFF8B5CF6);
            label = note.isNotEmpty ? note : '社友';
            break;
          default:
            edgeColor = const Color(0xFF94A3B8);
            label = note.isNotEmpty ? note : '朋友';
        }

        edges.add({
          'id': r['id']?.toString() ?? '',
          'from': from,
          'to': to,
          'type': type,
          'label': label,
          'color': edgeColor,
        });
      }
    }

    for (var c in customers) {
      final refId = c['referral_source_id']?.toString();
      final myId = c['id'].toString();
      if (refId != null && refId.isNotEmpty && refId != 'null' && custMap.containsKey(refId)) {
        adjMap[refId]?.add(myId);
        adjMap[myId]?.add(refId);
        activeCustIds.add(refId);
        activeCustIds.add(myId);

        final alreadyExists = edges.any((e) =>
          (e['from'] == refId && e['to'] == myId) ||
          (e['from'] == myId && e['to'] == refId)
        );

        if (!alreadyExists) {
          edges.add({
            'id': 'ref_$refId\_$myId',
            'from': refId,
            'to': myId,
            'type': 'referral',
            'label': '轉介紹',
            'color': const Color(0xFF10B981),
          });
        }
      }
    }

    final Set<String> visited = {};
    final List<List<String>> components = [];

    for (var custId in activeCustIds) {
      if (!visited.contains(custId)) {
        final List<String> comp = [];
        final List<String> queue = [custId];
        visited.add(custId);

        while (queue.isNotEmpty) {
          final curr = queue.removeAt(0);
          comp.add(curr);

          for (var neighbor in (adjMap[curr] ?? <String>{})) {
            if (!visited.contains(neighbor)) {
              visited.add(neighbor);
              queue.add(neighbor);
            }
          }
        }
        components.add(comp);
      }
    }

    components.sort((a, b) => b.length.compareTo(a.length));

    final List<Map<String, dynamic>> nodes = [];
    final Set<String> placedIds = {};
    final List<String> isolatedCustIds = customers
        .map((c) => c['id'].toString())
        .where((id) => !activeCustIds.contains(id))
        .toList();

    const double centerX = 600.0;
    const double centerY = 260.0;

    final List<Offset> islandSlots = [
      const Offset(280, 140),
      const Offset(920, 140),
      const Offset(280, 380),
      const Offset(920, 380),
      const Offset(600, 90),
      const Offset(600, 430),
    ];
    int islandSlotIdx = 0;

    for (int cIdx = 0; cIdx < components.length; cIdx++) {
      final comp = components[cIdx];
      if (comp.isEmpty) continue;

      if (cIdx == 0) {
        String hubId = comp[0];
        int maxDeg = -1;
        for (var id in comp) {
          final deg = adjMap[id]?.length ?? 0;
          if (deg > maxDeg) {
            maxDeg = deg;
            hubId = id;
          }
        }

        final List<String> outerNodes = comp.where((id) => id != hubId).toList();
        final List<String> orderedOuter = [];
        final Set<String> outerVisited = {};

        for (var outId in outerNodes) {
          if (!outerVisited.contains(outId)) {
            orderedOuter.add(outId);
            outerVisited.add(outId);
            for (var neighbor in (adjMap[outId] ?? <String>{})) {
              if (outerNodes.contains(neighbor) && !outerVisited.contains(neighbor)) {
                orderedOuter.add(neighbor);
                outerVisited.add(neighbor);
              }
            }
          }
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
          if (_nodePositionCache.containsKey(id)) {
            x = _nodePositionCache[id]!.dx;
            y = _nodePositionCache[id]!.dy;
          } else {
            if (i == 0) {
              x = centerX;
              y = centerY;
            } else if (compLen == 2) {
              const double radius = 320.0;
              x = centerX + radius * math.cos(math.pi / 4);
              y = centerY + radius * math.sin(math.pi / 4);
            } else if (compLen == 3) {
              final double angle = (i == 1) ? -math.pi / 3 : math.pi / 3;
              const double radius = 320.0;
              x = centerX + radius * math.cos(angle);
              y = centerY + radius * math.sin(angle);
            } else {
              final double angle = (2 * math.pi / (compLen - 1)) * (i - 1) - math.pi / 2;
              final double radius = 280.0 + (compLen > 6 ? 60.0 : 0.0);
              x = centerX + radius * math.cos(angle);
              y = centerY + radius * math.sin(angle);
            }
            _nodePositionCache[id] = Offset(x, y);
          }

          Color nodeColor = const Color(0xFF6366F1);
          if (degree >= 3) {
            nodeColor = const Color(0xFF10B981);
          } else if (degree == 2) {
            nodeColor = const Color(0xFF3B82F6);
          } else if (degree == 1) {
            nodeColor = const Color(0xFF8B5CF6);
          }

          nodes.add({
            'id': id,
            'name': name,
            'x': x,
            'y': y,
            'color': nodeColor,
            'isCenter': isCenter,
            'customer': cust,
          });
        }
      } else {
        final Offset islandCenter = islandSlots[islandSlotIdx % islandSlots.length];
        islandSlotIdx++;

        final int compLen = comp.length;
        for (int i = 0; i < compLen; i++) {
          final id = comp[i];
          final cust = custMap[id] ?? {};
          final name = cust['name']?.toString() ?? '未知';
          final degree = adjMap[id]?.length ?? 0;
          final bool isCenter = (i == 0);

          double x, y;
          if (_nodePositionCache.containsKey(id)) {
            x = _nodePositionCache[id]!.dx;
            y = _nodePositionCache[id]!.dy;
          } else {
            if (i == 0) {
              x = islandCenter.dx;
              y = islandCenter.dy;
            } else {
              final double angle = (2 * math.pi / (compLen - 1)) * (i - 1);
              const double radius = 180.0;
              x = islandCenter.dx + radius * math.cos(angle);
              y = islandCenter.dy + radius * math.sin(angle);
            }
            _nodePositionCache[id] = Offset(x, y);
          }

          Color nodeColor = const Color(0xFF6366F1);
          if (degree >= 3) {
            nodeColor = const Color(0xFF10B981);
          } else if (degree == 2) {
            nodeColor = const Color(0xFF3B82F6);
          }

          nodes.add({
            'id': id,
            'name': name,
            'x': x,
            'y': y,
            'color': nodeColor,
            'isCenter': isCenter,
            'customer': cust,
          });
        }
      }
    }

    if (isolatedCustIds.isNotEmpty) {
      final int totalIso = isolatedCustIds.length;
      final double ringRadius = 200.0;

      for (int i = 0; i < totalIso; i++) {
        final id = isolatedCustIds[i];
        final cust = custMap[id] ?? {};
        final name = cust['name']?.toString() ?? '未知';

        double x, y;
        if (_nodePositionCache.containsKey(id)) {
          x = _nodePositionCache[id]!.dx;
          y = _nodePositionCache[id]!.dy;
        } else {
          final double angle = (2 * math.pi / totalIso) * i;
          x = centerX + ringRadius * math.cos(angle);
          y = centerY + ringRadius * math.sin(angle);
          _nodePositionCache[id] = Offset(x, y);
        }

        nodes.add({
          'id': id,
          'name': name,
          'x': x,
          'y': y,
          'color': const Color(0xFF64748B),
          'isCenter': false,
          'customer': cust,
        });
      }
    }

    _computedNodes = nodes;
    _computedEdges = edges;
  }

  void _resetCanvasCenter() {
    setState(() {
      _selectedNodeId = null;
      _nodePositionCache.clear();
      _calculateClusterIslandTopology(_allCustomers, _relationships);

      if (_computedNodes.isEmpty) {
        _transformationController.value = Matrix4.identity();
        return;
      }

      double minX = double.infinity, maxX = -double.infinity;
      double minY = double.infinity, maxY = -double.infinity;
      for (var n in _computedNodes) {
        final x = (n['x'] as num).toDouble();
        final y = (n['y'] as num).toDouble();
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }

      final double graphCenterX = (minX + maxX) / 2;
      final double graphCenterY = (minY + maxY) / 2;

      double containerW = _lastCanvasContainerSize.width;
      double containerH = _lastCanvasContainerSize.height;
      if (!containerW.isFinite || containerW <= 0) containerW = 1200;
      if (!containerH.isFinite || containerH <= 0) containerH = 520;

      const double fitScale = 1.0;

      final Matrix4 matrix = Matrix4.identity()
        ..translate(containerW / 2, containerH / 2)
        ..scale(fitScale)
        ..translate(-graphCenterX, -graphCenterY);

      _transformationController.value = matrix;
    });
    CustomToast.show(context, '🎯 全景視野已自適應置中復位', ToastType.success);
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

  void _focusOnNode(String nodeId) {
    setState(() {
      _viewModeIndex = 1;
      _selectedNodeId = nodeId;
    });

    final node = _computedNodes.firstWhere(
      (n) => n['id'].toString() == nodeId,
      orElse: () => {},
    );

    if (node.isNotEmpty) {
      final double nx = node['x'] as double;
      final double ny = node['y'] as double;
      final matrix = Matrix4.identity()
        ..scale(1.15)
        ..translate(-(nx - 600) * 0.75, -(ny - 400) * 0.75);
      setState(() {
        _transformationController.value = matrix;
      });
      CustomToast.show(context, '🎯 已在拓撲中聚焦客戶：${node['name']}', ToastType.success);
    }
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
              InkWell(
                onTap: () => _focusOnNode(tree['vipId'].toString()),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hub_rounded, size: 12, color: Color(0xFF6366F1)),
                      SizedBox(width: 4),
                      Text('在拓撲中聚焦', style: TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
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
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.location_searching_rounded, size: 14, color: Color(0xFF6366F1)),
                    tooltip: '在拓撲中定位',
                    onPressed: () => _focusOnNode(m['id'].toString()),
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
    // Determine 1st-degree connected node IDs if _selectedNodeId != null
    final Set<String> focusNodeIds = {};
    if (_selectedNodeId != null) {
      focusNodeIds.add(_selectedNodeId!);
      for (var e in _computedEdges) {
        if (e['from'].toString() == _selectedNodeId) {
          focusNodeIds.add(e['to'].toString());
        }
        if (e['to'].toString() == _selectedNodeId) {
          focusNodeIds.add(e['from'].toString());
        }
      }
    }

    return Container(
      width: double.infinity,
      height: 520,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _lastCanvasContainerSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(
            children: [
              InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: const EdgeInsets.all(1200),
                minScale: 0.2,
                maxScale: 4.0,
                clipBehavior: Clip.none,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                          size: Size.infinite,
                          painter: DynamicTopologyPainter(
                            nodes: _computedNodes,
                            edges: _computedEdges,
                            selectedNodeId: _selectedNodeId,
                            isDark: isDark,
                          ),
                        ),
                        ..._computedNodes.map((n) {
                          final double x = n['x'] as double;
                          final double y = n['y'] as double;
                          final bool isCenter = n['isCenter'] as bool;
                          final Color color = n['color'] as Color;
                          final String name = n['name'] as String;
                          final String id = n['id'].toString();
                          final Map<String, dynamic> cust = n['customer'] as Map<String, dynamic>;

                          final bool isDimmed = _selectedNodeId != null && !focusNodeIds.contains(id);
                          final bool isFocused = _selectedNodeId == id;

                          return Positioned(
                            left: x - (isCenter ? 42 : 34),
                            top: y - (isCenter ? 42 : 34),
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  final double newX = (n['x'] as double) + details.delta.dx;
                                  final double newY = (n['y'] as double) + details.delta.dy;
                                  n['x'] = newX;
                                  n['y'] = newY;
                                  _nodePositionCache[id] = Offset(newX, newY);
                                });
                              },
                              onTap: () {
                                setState(() {
                                  _selectedNodeId = (_selectedNodeId == id) ? null : id;
                                });
                              },
                          onDoubleTap: () => _showEditRelationshipDialog(cust),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isDimmed ? 0.25 : 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: isFocused
                                    ? Border.all(color: Colors.amberAccent, width: 3.5)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: isFocused
                                        ? Colors.amberAccent.withOpacity(0.6)
                                        : color.withOpacity(0.4),
                                    blurRadius: isFocused ? 18 : (isCenter ? 14 : 8),
                                    spreadRadius: isFocused ? 4 : (isCenter ? 3 : 1),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: isCenter ? 42 : 34,
                                backgroundColor: color,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isCenter ? Icons.star_rounded : Icons.person_rounded,
                                      size: isCenter ? 22 : 18,
                                      color: Colors.white,
                                    ),
                                    Text(
                                      name.length > 4 ? name.substring(0, 4) : name,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isCenter ? 12 : 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
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

          // Floating Reset Center Button & Hint
          Positioned(
            top: 16,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedNodeId != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _selectedNodeId = null),
                      icon: const Icon(Icons.clear_all_rounded, size: 14),
                      label: const Text('解除聚焦', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: _resetCanvasCenter,
                  icon: const Icon(Icons.my_location_rounded, size: 16),
                  label: const Text('🎯 視野置中復位', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Info Bar with Drag & Tap Guides
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
                        Text('🕸️ 黑曜石 (Obsidian) 動態圖譜：可按住節點自由拖曳 | 點擊節點聚焦一度人脈 | 雙擊管理關係', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
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
      );
    },
  ),
);
  }
}

/// Advanced Dynamic Topology Painter with Canonical Orientation & Multi-Edge Curved Splitting
class DynamicTopologyPainter extends CustomPainter {
  final List<Map<String, dynamic>> nodes;
  final List<Map<String, dynamic>> edges;
  final String? selectedNodeId;
  final bool isDark;

  DynamicTopologyPainter({
    required this.nodes,
    required this.edges,
    this.selectedNodeId,
    required this.isDark,
  });

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

        final double r1 = (node1['isCenter'] as bool? ?? false) ? 42.0 : 34.0;
        final double r2 = (node2['isCenter'] as bool? ?? false) ? 42.0 : 34.0;

        final bool isEdgeFocused = selectedNodeId == null ||
            (fromId == selectedNodeId || toId == selectedNodeId);
        final double edgeOpacity = isEdgeFocused ? 0.9 : 0.15;

        double curveMagnitude = 0.0;
        double curveSign = 1.0;
        double tLabel = 0.5;

        if (groupCount == 1) {
          curveMagnitude = 28.0;
          curveSign = 1.0;
          tLabel = 0.50;
        } else if (groupCount == 2) {
          curveMagnitude = 65.0;
          curveSign = (groupIdx == 0) ? 1.0 : -1.0;
          tLabel = (groupIdx == 0) ? 0.36 : 0.64;
        } else if (groupCount == 3) {
          if (groupIdx == 0) {
            curveMagnitude = 85.0;
            curveSign = 1.0;
            tLabel = 0.30;
          } else if (groupIdx == 1) {
            curveMagnitude = 0.0;
            curveSign = 0.0;
            tLabel = 0.50;
          } else {
            curveMagnitude = 85.0;
            curveSign = -1.0;
            tLabel = 0.70;
          }
        } else {
          curveSign = (groupIdx % 2 == 0) ? 1.0 : -1.0;
          curveMagnitude = 55.0 + (groupIdx ~/ 2) * 50.0;
          tLabel = 0.22 + (groupIdx * 0.56 / (groupCount - 1));
        }

        final double controlX = midX + nx * curveMagnitude * curveSign;
        final double controlY = midY + ny * curveMagnitude * curveSign;

        final path = Path()
          ..moveTo(p1.dx, p1.dy)
          ..quadraticBezierTo(controlX, controlY, p2.dx, p2.dy);

        final linePaint = Paint()
          ..color = strokeColor.withOpacity(edgeOpacity)
          ..strokeWidth = isEdgeFocused ? 2.4 : 1.2
          ..style = PaintingStyle.stroke;

        canvas.drawPath(path, linePaint);

        // If Referral edge (type == 'referral'), draw a Directional Arrow pointing towards target p2
        if (typeStr == 'referral') {
          _drawDirectionalArrow(canvas, controlX, controlY, p2, r2, strokeColor.withOpacity(edgeOpacity));
        }

        // Evaluate point on Bezier curve at t = tLabel
        final double labelX = (1 - tLabel) * (1 - tLabel) * p1.dx + 2 * (1 - tLabel) * tLabel * controlX + tLabel * tLabel * p2.dx;
        final double labelY = (1 - tLabel) * (1 - tLabel) * p1.dy + 2 * (1 - tLabel) * tLabel * controlY + tLabel * tLabel * p2.dy;
        final Offset labelPos = Offset(labelX, labelY);

        // Draw Edge Label Pill at staggered & safe labelPos with focus opacity
        if (isEdgeFocused) {
          _drawEdgeLabelPill(canvas, labelPos, labelStr, strokeColor, isDark);
        }
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
