import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/customer_policy_service.dart';
import '../services/policy_crawler_service.dart';
import '../widgets/custom_toast.dart';

class PolicyComparisonScreen extends StatefulWidget {
  final List<PolicyClauseItem> initialProducts;
  final VoidCallback? onBackToSearch;

  const PolicyComparisonScreen({
    super.key,
    required this.initialProducts,
    this.onBackToSearch,
  });

  @override
  State<PolicyComparisonScreen> createState() => _PolicyComparisonScreenState();
}

class _PolicyComparisonScreenState extends State<PolicyComparisonScreen> {
  late List<PolicyClauseItem> _products;
  bool _onlyShowDifferences = false;
  final CustomerPolicyService _policyService = CustomerPolicyService();

  @override
  void initState() {
    super.initState();
    _products = List<PolicyClauseItem>.from(widget.initialProducts);
  }

  void _removeProduct(int index) {
    if (_products.length <= 1) {
      CustomToast.show(context, '⚠️ 比較表至少需保留 1 款商品', ToastType.warning);
      return;
    }
    setState(() {
      _products.removeAt(index);
    });
  }

  Future<void> _openPdfUrl(String url) async {
    if (url.isEmpty || !url.startsWith('http')) {
      CustomToast.show(context, '此條款暫無線上 PDF 檔案連結', ToastType.warning);
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        CustomToast.show(context, '無法開啟條款連結: $url', ToastType.error);
      }
    }
  }

  /// 一鍵為名下客戶規劃/投保此條款
  Future<void> _showEnrollCustomerDialog(PolicyClauseItem policy) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      CustomToast.show(context, '請先登入帳號以連線 CRM 客戶庫', ToastType.warning);
      return;
    }

    // 1. 查詢真實客戶名單
    List<Map<String, dynamic>> customers = [];
    try {
      final res = await supabase
          .from('customers')
          .select('id, name, phone, tags')
          .eq('profile_id', user.id)
          .isFilter('deleted_at', null)
          .order('name');
      customers = List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '讀取客戶資料庫失敗: $e', ToastType.error);
      }
      return;
    }

    if (!mounted) return;

    if (customers.isEmpty) {
      CustomToast.show(context, '您目前名下尚無客戶，請先至「客戶管理」建立客戶檔案！', ToastType.warning);
      return;
    }

    String? selectedCustomerId = customers.first['id'].toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
          final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('為客戶規劃投保：${policy.productName}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🏢 ${policy.companyName} • ${policy.category}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                        const SizedBox(height: 4),
                        Text('病房：${policy.roomLimit} | 手術：${policy.surgeryLimit} | 雜費：${policy.miscLimit}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('請選擇欲掛載保單之名下客戶：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCustomerId,
                    isExpanded: true,
                    items: customers.map((c) {
                      return DropdownMenuItem<String>(
                        value: c['id'].toString(),
                        child: Text('${c['name']} (${c['phone'] ?? '未提供電話'})', style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() => selectedCustomerId = val);
                      }
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedCustomerId != null) {
                    Navigator.pop(ctx);
                    final success = await _policyService.enrollPolicyForCustomer(
                      customerId: selectedCustomerId!,
                      policyClauseId: policy.id,
                      productName: policy.productName,
                      companyName: policy.companyName,
                      category: policy.category,
                      roomLimit: policy.roomLimit,
                      surgeryLimit: policy.surgeryLimit,
                      miscLimit: policy.miscLimit,
                      rawPdfUrl: policy.rawPdfUrl,
                      benefitsJson: policy.benefitsJson,
                    );
                    if (mounted) {
                      if (success) {
                        CustomToast.show(context, '已成功將「${policy.productName}」掛載至客戶保單庫！', ToastType.success);
                      } else {
                        CustomToast.show(context, '保單掛載失敗，請檢查網路連線', ToastType.error);
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
                child: const Text('確認掛載保單'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 開啟「雙模式（情境範本 + 自訂收據細項 + 2-2-7 處置陷阱）」理賠試算彈窗
  void _showClinicalClaimDialog(PolicyClauseItem policy) {
    // 解析該保單限額數值
    int roomLimitVal = 2000;
    int surgeryLimitVal = 150000;
    int miscLimitVal = 120000;

    final roomDigits = RegExp(r'\d+').allMatches(policy.roomLimit.replaceAll(',', ''));
    if (roomDigits.isNotEmpty) {
      roomLimitVal = int.tryParse(roomDigits.first.group(0) ?? '2000') ?? 2000;
    }
    final surgeryDigits = RegExp(r'\d+').allMatches(policy.surgeryLimit.replaceAll(',', ''));
    if (surgeryDigits.isNotEmpty) {
      surgeryLimitVal = int.tryParse(surgeryDigits.first.group(0) ?? '150000') ?? 150000;
    }
    final miscDigits = RegExp(r'\d+').allMatches(policy.miscLimit.replaceAll(',', ''));
    if (miscDigits.isNotEmpty) {
      miscLimitVal = int.tryParse(miscDigits.first.group(0) ?? '120000') ?? 120000;
    }

    final pkDetail = _policyService.extractPolicyPkDetail({
      'tags': policy.tags,
      'product_name': policy.productName,
    });

    // 初始值以達文西手術為範本
    int currentRoomDays = 4;
    int currentRoomDailyCost = 3500;
    int currentSurgeryCost = 220000;
    int currentMiscCost = 80000;
    bool currentIs227 = true;
    String activePresetId = 'davinci';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
          final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

          final result = _policyService.calculateCustomItemizedClaim(
            roomDays: currentRoomDays,
            roomDailyActual: currentRoomDailyCost,
            surgeryCost: currentSurgeryCost,
            miscCost: currentMiscCost,
            is227Procedure: currentIs227,
            roomDailyLimit: roomLimitVal,
            surgeryLimit: surgeryLimitVal,
            miscLimit: miscLimitVal,
            isPolicy227Restricted: pkDetail.is227Restricted,
          );

          final bool has227Trap = pkDetail.is227Restricted && !currentIs227;

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.health_and_safety_rounded, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('全真醫療單據理賠精算：${policy.productName}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ① 快速範本選擇
                    const Text('① 快速載入臨床情境範本：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: CustomerPolicyService.clinicalScenarios.map((sc) {
                        final isSel = activePresetId == sc.id;
                        return ChoiceChip(
                          avatar: Text(sc.iconEmoji),
                          label: Text(sc.title, style: TextStyle(fontSize: 10.5, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                          selected: isSel,
                          selectedColor: const Color(0xFF10B981),
                          labelStyle: TextStyle(color: isSel ? Colors.white : textColor),
                          onSelected: (_) {
                            setDlgState(() {
                              activePresetId = sc.id;
                              currentRoomDays = sc.standardRoomDays;
                              currentRoomDailyCost = sc.hospitalRoomDailyActual;
                              currentSurgeryCost = sc.standardSurgeryCost;
                              currentMiscCost = sc.standardMiscCost;
                              currentIs227 = sc.is227Surgery;
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    // ② 自訂單據細項編輯區
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF6366F1)),
                              SizedBox(width: 4),
                              Text('② 自由調整醫院收據自費細項：', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildNumberInput(
                                  label: '🛏️ 住院天數',
                                  value: currentRoomDays,
                                  suffix: '天',
                                  onChanged: (val) => setDlgState(() {
                                    activePresetId = 'custom';
                                    currentRoomDays = val;
                                  }),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildNumberInput(
                                  label: '🛏️ 單人房每日自費',
                                  value: currentRoomDailyCost,
                                  suffix: '元',
                                  onChanged: (val) => setDlgState(() {
                                    activePresetId = 'custom';
                                    currentRoomDailyCost = val;
                                  }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildNumberInput(
                                  label: '🔪 自費手術費',
                                  value: currentSurgeryCost,
                                  suffix: '元',
                                  onChanged: (val) => setDlgState(() {
                                    activePresetId = 'custom';
                                    currentSurgeryCost = val;
                                  }),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildNumberInput(
                                  label: '💊 自費標靶/醫材雜費',
                                  value: currentMiscCost,
                                  suffix: '元',
                                  onChanged: (val) => setDlgState(() {
                                    activePresetId = 'custom';
                                    currentMiscCost = val;
                                  }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 2-2-7 處置陷阱開關
                          InkWell(
                            onTap: () => setDlgState(() {
                              activePresetId = 'custom';
                              currentIs227 = !currentIs227;
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: currentIs227,
                                    activeColor: const Color(0xFF10B981),
                                    onChanged: (val) => setDlgState(() {
                                      activePresetId = 'custom';
                                      currentIs227 = val ?? true;
                                    }),
                                  ),
                                  const Expanded(
                                    child: Text('此手術項目符合健保「第二部第二章第七節 (2-2-7 手術)」',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (has227Trap) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '🚨 條款地雷預警：此保單限定健保 2-2-7，因該項手術屬於健保處置，條款手術給付為 0 元！',
                                style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // ③ 給付精算與自費缺口
                    const Text('③ 醫療單據總額 vs 保單給付精算：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    _buildClaimRow('🛏️ 病房自費差額給付：', '${result.roomExpenses} 元', '給付: ${result.roomClaim} 元'),
                    _buildClaimRow(
                      '🔪 手術費用給付：',
                      '${result.surgeryExpenses} 元',
                      has227Trap ? '給付: 0 元 (2-2-7除外)' : '給付: ${result.surgeryClaim} 元',
                      claimColor: has227Trap ? Colors.red : const Color(0xFF10B981),
                    ),
                    _buildClaimRow('💊 醫療耗材/藥品雜費給付：', '${result.miscExpenses} 元', '給付: ${result.miscClaim} 元'),
                    const Divider(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: result.outOfPocketGap > 0
                            ? const Color(0xFFEF4444).withOpacity(0.12)
                            : const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: result.outOfPocketGap > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('醫院總自費帳單：', style: TextStyle(fontSize: 12)),
                              Text('${result.totalExpenses} 元', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('保單預估理賠總額：', style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                              Text('${result.totalClaim} 元', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('🚨 病患最終自費缺口：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                              Text('${result.outOfPocketGap} 元', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('關閉')),
            ],
          );
        },
      ),
    );
  }

  /// 開啟「🔥 跨保單/雙實支組合包聯合精算 (Multi-Policy Waterfall Engine)」彈窗
  void _showMultiPolicyWaterfallDialog() {
    int roomDays = 4;
    int roomDailyCost = 3500;
    int surgeryCost = 220000;
    int miscCost = 80000;
    bool is227 = true;

    final policyConfigs = _products.map((p) {
      int roomLimitVal = 2000;
      int surgeryLimitVal = 150000;
      int miscLimitVal = 120000;

      final roomDigits = RegExp(r'\d+').allMatches(p.roomLimit.replaceAll(',', ''));
      if (roomDigits.isNotEmpty) roomLimitVal = int.tryParse(roomDigits.first.group(0) ?? '2000') ?? 2000;

      final surgeryDigits = RegExp(r'\d+').allMatches(p.surgeryLimit.replaceAll(',', ''));
      if (surgeryDigits.isNotEmpty) surgeryLimitVal = int.tryParse(surgeryDigits.first.group(0) ?? '150000') ?? 150000;

      final miscDigits = RegExp(r'\d+').allMatches(p.miscLimit.replaceAll(',', ''));
      if (miscDigits.isNotEmpty) miscLimitVal = int.tryParse(miscDigits.first.group(0) ?? '120000') ?? 120000;

      final pkDetail = _policyService.extractPolicyPkDetail({'tags': p.tags, 'product_name': p.productName});

      return {
        'product_name': p.productName,
        'company_name': p.companyName,
        'room_limit_val': roomLimitVal,
        'surgery_limit_val': surgeryLimitVal,
        'misc_limit_val': miscLimitVal,
        'is_227_restricted': pkDetail.is227Restricted,
        'receipt_rule': pkDetail.receiptType,
      };
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
          final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

          final summary = _policyService.calculateMultiPolicyWaterfallClaim(
            roomDays: roomDays,
            roomDailyActual: roomDailyCost,
            surgeryCost: surgeryCost,
            miscCost: miscCost,
            is227Procedure: is227,
            policyConfigs: policyConfigs,
          );

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.waterfall_chart_rounded, color: Color(0xFFE53E3E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('🔥 跨保單組合包雙實支聯合精算 (已選 ${_products.length} 張保單)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 警示訊息
                    if (summary.warnings.isNotEmpty) ...[
                      ...summary.warnings.map((w) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(w, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          )),
                      const SizedBox(height: 8),
                    ],

                    // 醫院帳單總額
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('🏥 醫院總帳單自費支出：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('${summary.totalHospitalBill} 元', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFE53E3E))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    const Text('📊 跨保單收據核銷與理賠流向瀑布：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),

                    // 各保單理賠明細卡片
                    ...summary.policyClaims.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final claim = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('保單 ${idx + 1}：${claim.companyName} • ${claim.policyName}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(claim.receiptRule, style: const TextStyle(fontSize: 10, color: Color(0xFF6366F1))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('🛏️ 病房核銷: ${claim.roomPaid} 元 | 🔪 手術核銷: ${claim.surgeryPaid} 元 | 💊 雜費核銷: ${claim.miscPaid} 元',
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('💰 本張保單給付總計: ${claim.totalPaid} 元',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          ],
                        ),
                      );
                    }),

                    const Divider(height: 18),

                    // 最終總計
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: summary.finalOutOfPocketGap == 0
                            ? const Color(0xFF10B981).withOpacity(0.12)
                            : const Color(0xFFEF4444).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: summary.finalOutOfPocketGap == 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('💎 組合包理賠總給付額：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                              Text('${summary.grandTotalClaimPaid} 元', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                            ],
                          ),
                          const Divider(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('🚨 最終自費缺口：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                              Text('${summary.finalOutOfPocketGap} 元', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('關閉')),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNumberInput({
    required String label,
    required int value,
    required String suffix,
    required Function(int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value.toString(),
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            isDense: true,
            suffixText: suffix,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          onChanged: (val) {
            final parsed = int.tryParse(val.replaceAll(',', ''));
            if (parsed != null) {
              onChanged(parsed);
            }
          },
        ),
      ],
    );
  }

  Widget _buildClaimRow(String label, String expense, String claim, {Color? claimColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11.5))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(expense, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              Text(claim, style: TextStyle(fontSize: 10.5, color: claimColor ?? const Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
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
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () {
            if (widget.onBackToSearch != null) {
              widget.onBackToSearch!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Row(
          children: [
            Text('商品條款橫向並排比較 (已選 ${_products.length}/8 款)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE53E3E).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('100% 實體資料庫連線', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE53E3E))),
            ),
          ],
        ),
        actions: [
          if (_products.length >= 2)
            ElevatedButton.icon(
              onPressed: _showMultiPolicyWaterfallDialog,
              icon: const Icon(Icons.waterfall_chart_rounded, size: 15),
              label: const Text('🔥 組合包聯合精算', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53E3E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          const SizedBox(width: 8),
          Row(
            children: [
              Text('只看差異', style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.bold)),
              Switch(
                value: _onlyShowDifferences,
                activeColor: const Color(0xFFE53E3E),
                onChanged: (val) => setState(() => _onlyShowDifferences = val),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _products.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value;
              final pkDetail = _policyService.extractPolicyPkDetail({
                'id': p.id,
                'product_name': p.productName,
                'company_name': p.companyName,
                'category': p.category,
                'tags': p.tags,
                'room_limit': p.roomLimit,
                'surgery_limit': p.surgeryLimit,
                'misc_limit': p.miscLimit,
                'waiting_days': p.waitingDays,
                'raw_pdf_url': p.rawPdfUrl,
              });

              return Container(
                width: 295,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE53E3E).withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card Top Header
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53E3E).withOpacity(0.08),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE53E3E),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(p.id.length > 8 ? p.id.substring(0, 8).toUpperCase() : p.id.toUpperCase(),
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _removeProduct(idx),
                                tooltip: '移除此商品',
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(p.companyName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE53E3E))),
                          const SizedBox(height: 2),
                          Text(p.productName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),

                    // Section 1: 基本資訊
                    _buildSectionHeader('📋 基本規格與銷售資訊', isDark),
                    _buildSpecRow('險種分類', p.category, textColor, subTextColor),
                    _buildSpecRow('銷售狀態', '現售條款 (官方報備)', const Color(0xFF10B981), subTextColor),
                    _buildSpecRow('等待期規範', p.waitingDays, textColor, subTextColor),

                    // Section 2: 給付上限
                    _buildSectionHeader('💰 5 大給付與條款限額', isDark),
                    _buildSpecRow('病房費用給付', p.roomLimit, textColor, subTextColor),
                    _buildSpecRow('住院/門診手術', p.surgeryLimit, textColor, subTextColor),
                    _buildSpecRow('醫療自費雜費', p.miscLimit, textColor, subTextColor),

                    // Section 3: 條款關鍵細節比對
                    _buildSectionHeader('🔍 條款關鍵細節比對', isDark),
                    _buildSpecRow('健保 2-2-7 限制', pkDetail.is227Restricted ? '限定健保 2-2-7 (嚴)' : '無 2-2-7 限制 (優)', pkDetail.is227Restricted ? Colors.orange : const Color(0xFF10B981), subTextColor),
                    _buildSpecRow('收據核銷規定', pkDetail.receiptType, textColor, subTextColor),
                    _buildSpecRow('條款形式', pkDetail.clauseType, textColor, subTextColor),

                    // Section 4: CRM 整合與實體行動
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showClinicalClaimDialog(p),
                            icon: const Icon(Icons.health_and_safety_rounded, size: 15),
                            label: const Text('全真醫療單據試算', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showEnrollCustomerDialog(p),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
                            label: const Text('為名下客戶規劃', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _openPdfUrl(p.rawPdfUrl),
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                            label: const Text('原廠 PDF 條款', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(color: borderColor),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF1F5F9),
      child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildSpecRow(String label, String val, Color valColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 11, color: subTextColor))),
          Expanded(child: Text(val, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: valColor))),
        ],
      ),
    );
  }
}
