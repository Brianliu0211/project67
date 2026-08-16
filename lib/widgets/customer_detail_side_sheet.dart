import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/customer_policy_service.dart';
import '../services/policy_crawler_service.dart';
import '../widgets/custom_toast.dart';
import '../widgets/categorized_tag_accordion_selector.dart';
import '../widgets/voice_recorder_widget.dart';

class CustomerDetailSideSheet extends StatefulWidget {
  final Map<String, dynamic> customer;
  final Function(Map<String, dynamic> updated) onCustomerUpdated;
  final VoidCallback onClose;

  const CustomerDetailSideSheet({
    super.key,
    required this.customer,
    required this.onCustomerUpdated,
    required this.onClose,
  });

  static void show(
    BuildContext context, {
    required Map<String, dynamic> customer,
    required Function(Map<String, dynamic>) onCustomerUpdated,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      // Desktop Right-side Sheet
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'CustomerDetailSideSheet',
        barrierColor: Colors.black.withValues(alpha: 0.35),
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (ctx, _, __) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 520,
                height: double.infinity,
                child: CustomerDetailSideSheet(
                  customer: customer,
                  onCustomerUpdated: onCustomerUpdated,
                  onClose: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (ctx, anim, _, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          );
        },
      );
    } else {
      // Mobile Bottom Sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return FractionallySizedBox(
            heightFactor: 0.9,
            child: CustomerDetailSideSheet(
              customer: customer,
              onCustomerUpdated: onCustomerUpdated,
              onClose: () => Navigator.of(ctx).pop(),
            ),
          );
        },
      );
    }
  }

  @override
  State<CustomerDetailSideSheet> createState() => _CustomerDetailSideSheetState();
}

class _CustomerDetailSideSheetState extends State<CustomerDetailSideSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CustomerPolicyService _policyService = CustomerPolicyService();
  final PolicyCrawlerService _crawlerService = PolicyCrawlerService();

  late TextEditingController _nameController;
  late TextEditingController _nicknameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _notesController;
  late TextEditingController _tagsController;

  List<CustomerEnrolledPolicy> _enrolledPolicies = [];
  CustomerBenefitSummary? _benefitSummary;
  bool _isLoadingPolicies = true;

  // Search catalog to enroll new policy
  final TextEditingController _searchCatalogController = TextEditingController();
  List<PolicyClauseItem> _catalogSearchResults = [];
  bool _isSearchingCatalog = false;
  bool _showEnrollSearchBox = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _nameController = TextEditingController(text: widget.customer['name'] ?? '');
    _nicknameController = TextEditingController(text: widget.customer['nickname'] ?? '');
    _phoneController = TextEditingController(text: widget.customer['phone'] ?? '');
    _emailController = TextEditingController(text: widget.customer['email'] ?? '');
    _notesController = TextEditingController(text: widget.customer['notes'] ?? '');
    final tags = (widget.customer['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
    _tagsController = TextEditingController(text: tags.join(', '));

    _loadCustomerPolicies();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    _searchCatalogController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerPolicies() async {
    setState(() => _isLoadingPolicies = true);
    final custId = widget.customer['id']?.toString() ?? '';
    final list = await _policyService.getCustomerPolicies(custId);
    final summary = _policyService.calculateCustomerBenefitSummary(list);

    if (mounted) {
      setState(() {
        _enrolledPolicies = list;
        _benefitSummary = summary;
        _isLoadingPolicies = false;
      });
    }
  }

  Future<void> _searchCatalog(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _catalogSearchResults = []);
      return;
    }
    setState(() => _isSearchingCatalog = true);
    final results = await _crawlerService.searchPolicyClauses(query: query, limit: 50);
    if (mounted) {
      setState(() {
        _catalogSearchResults = results;
        _isSearchingCatalog = false;
      });
    }
  }

  Future<void> _enrollPolicy(PolicyClauseItem item) async {
    final custId = widget.customer['id']?.toString() ?? '';
    await _policyService.enrollPolicyForCustomer(
      customerId: custId,
      policyClauseId: item.id,
      productName: item.productName,
      companyName: item.companyName,
      category: item.category,
      roomLimit: item.roomLimit,
      surgeryLimit: item.surgeryLimit,
      miscLimit: item.miscLimit,
      rawPdfUrl: item.rawPdfUrl,
      benefitsJson: item.benefitsJson,
    );

    CustomToast.show(context, '✅ 已加入已投保保單: ${item.productName}', ToastType.success);
    setState(() {
      _showEnrollSearchBox = false;
      _searchCatalogController.clear();
      _catalogSearchResults.clear();
    });
    _loadCustomerPolicies();
  }

  Future<void> _saveBasicInfo() async {
    final updated = Map<String, dynamic>.from(widget.customer);
    updated['name'] = _nameController.text.trim();
    updated['nickname'] = _nicknameController.text.trim();
    updated['phone'] = _phoneController.text.trim();
    updated['email'] = _emailController.text.trim();
    updated['notes'] = _notesController.text.trim();
    updated['tags'] = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    widget.onCustomerUpdated(updated);

    try {
      final custId = widget.customer['id']?.toString();
      if (custId != null) {
        await Supabase.instance.client.from('customers').update({
          'name': updated['name'],
          'nickname': updated['nickname'],
          'phone': updated['phone'],
          'email': updated['email'],
          'notes': updated['notes'],
          'tags': updated['tags'],
          'status': updated['status'] ?? 'active',
        }).eq('id', custId);
      }
      if (mounted) {
        CustomToast.show(context, '✅ 客戶檔案已即時儲存', ToastType.success);
      }
    } catch (e) {
      // Local updated
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final String name = _nameController.text.isEmpty ? '客戶檔案' : _nameController.text;
    final String nickname = _nicknameController.text;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(-4, 0)),
        ],
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1) : '客',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                          if (nickname.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('($nickname)', style: TextStyle(fontSize: 12, color: subTextColor)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('讀寫合一沉浸式檔案 • 本地 0 成本精算', style: TextStyle(fontSize: 11, color: subTextColor)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            decoration: BoxDecoration(color: bgColor, border: Border(bottom: BorderSide(color: borderColor))),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF10B981),
              unselectedLabelColor: subTextColor,
              indicatorColor: const Color(0xFF10B981),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.badge_rounded, size: 16), text: '基本資料'),
                Tab(icon: Icon(Icons.health_and_safety_rounded, size: 16), text: '保單健檢與缺口'),
                Tab(icon: Icon(Icons.history_edu_rounded, size: 16), text: '拜訪歷程'),
              ],
            ),
          ),

          // Tab Body
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Basic Info & Tags (In-place editing)
                _buildBasicInfoTab(isDark, cardBg, borderColor, textColor, subTextColor),

                // Tab 2: Enrolled Policies & 0-Cost Actuarial Summary
                _buildPoliciesAndGapTab(isDark, cardBg, borderColor, textColor, subTextColor),

                // Tab 3: Visit Notes & History
                _buildVisitHistoryTab(isDark, cardBg, borderColor, textColor, subTextColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '客戶姓名', isDense: true, border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(labelText: '綽號 / 稱謂', isDense: true, border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: '聯絡電話 (點擊可快速撥打)', prefixIcon: Icon(Icons.phone_rounded, size: 18), isDense: true, border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: '電子信箱', prefixIcon: Icon(Icons.email_rounded, size: 18), isDense: true, border: OutlineInputBorder()),
          ),
          const SizedBox(height: 18),

          Text('🏷️ 客戶標籤管理：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          CategorizedTagAccordionSelector(
            tagsController: _tagsController,
            isDark: isDark,
            primaryColor: const Color(0xFF10B981),
          ),

          const SizedBox(height: 18),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '客戶隨手筆記 / 家庭背景備註',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          if (widget.customer['status'] == 'draft') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 2,
                ),
                onPressed: () {
                  final updated = Map<String, dynamic>.from(widget.customer);
                  updated['name'] = _nameController.text.trim();
                  updated['nickname'] = _nicknameController.text.trim();
                  updated['phone'] = _phoneController.text.trim();
                  updated['email'] = _emailController.text.trim();
                  updated['notes'] = _notesController.text.trim();
                  updated['tags'] = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  updated['status'] = 'active'; // 轉正為正式客戶
                  _saveBasicInfo();
                  CustomToast.show(context, '🎉 已成功補齊資料並轉正為正式客戶！', ToastType.success);
                  widget.onClose();
                },
                icon: const Icon(Icons.verified_user_rounded, size: 20),
                label: const Text('✓ 確認補齊資料，正式入庫轉正', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: _saveBasicInfo,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('即時儲存基本資料', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoliciesAndGapTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    if (_isLoadingPolicies) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 0-Cost Actuarial Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calculate_rounded, color: Color(0xFF10B981), size: 18),
                        SizedBox(width: 8),
                        Text('🧮 5 大理賠桶總額 (0 成本本地精算)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(6)),
                      child: const Text('已納入健檢', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSummaryRow('病房給付總額', '${_benefitSummary?.totalRoomDaily ?? 0} 元/日', Icons.hotel_rounded),
                _buildSummaryRow('手術給付上限', '${_benefitSummary?.totalSurgeryMax ?? 0} 元', Icons.medical_services_rounded),
                _buildSummaryRow('自費雜費總額', '${_benefitSummary?.totalMiscMax ?? 0} 元', Icons.receipt_rounded),
                _buildSummaryRow('癌症重疾一次金', '${(_benefitSummary?.totalCancerCriticalMax ?? 0) ~/ 10000} 萬元', Icons.coronavirus_rounded),
                _buildSummaryRow('車險/超額責任險', '${(_benefitSummary?.totalLiabilityMax ?? 0) ~/ 10000} 萬元', Icons.car_crash_rounded),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Red Gaps Warning Card
          if (_benefitSummary != null && _benefitSummary!.hasCriticalGap) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                      SizedBox(width: 6),
                      Text('🚨 偵測到重大自費保障缺口：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._benefitSummary!.detectedGaps.map((gap) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• $gap', style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Enrolled Policies Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('已投保保單清單 (${_enrolledPolicies.length} 張)：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
              OutlinedButton.icon(
                onPressed: () => setState(() => _showEnrollSearchBox = !_showEnrollSearchBox),
                icon: Icon(_showEnrollSearchBox ? Icons.close_rounded : Icons.add_rounded, size: 16),
                label: Text(_showEnrollSearchBox ? '收合搜尋' : '+ 搜尋 1.1萬+ 條款加入', style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0EA5E9), side: const BorderSide(color: Color(0xFF0EA5E9))),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Search catalog box
          if (_showEnrollSearchBox) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCatalogController,
                    onChanged: _searchCatalog,
                    decoration: const InputDecoration(
                      hintText: '輸入保單名稱快速搜尋 (如: 國泰真安心、富邦超額責任)...',
                      hintStyle: TextStyle(fontSize: 12),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_isSearchingCatalog)
                    const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                  else if (_catalogSearchResults.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _catalogSearchResults.length,
                      itemBuilder: (ctx, i) {
                        final item = _catalogSearchResults[i];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.productName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: Text('${item.companyName} • ${item.category}', style: TextStyle(fontSize: 10, color: subTextColor)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                            onPressed: () => _enrollPolicy(item),
                            child: const Text('加入', style: TextStyle(fontSize: 11)),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Policy list cards
          if (_enrolledPolicies.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('目前尚未加入任何已購保單，點擊上方按鈕搜尋 11,722 筆庫存加入。', style: TextStyle(fontSize: 12, color: subTextColor), textAlign: TextAlign.center),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _enrolledPolicies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final p = _enrolledPolicies[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.productName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 2),
                            Text('${p.companyName} • ${p.category}', style: TextStyle(fontSize: 10, color: subTextColor)),
                            Text('病房: ${p.roomLimit} | 手術: ${p.surgeryLimit} | 雜費: ${p.miscLimit}', style: const TextStyle(fontSize: 10, color: Color(0xFF10B981))),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        onPressed: () async {
                          await _policyService.removePolicyForCustomer(widget.customer['id'], p.id);
                          _loadCustomerPolicies();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildVisitHistoryTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic_none_rounded, color: Color(0xFF6366F1), size: 18),
              const SizedBox(width: 6),
              Text('語音速記與拜訪紀錄：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const SizedBox(height: 12),
          // 🎙️ 內嵌隨手語音錄音與轉錄
          VoiceRecorderWidget(
            primaryColor: const Color(0xFF10B981),
            isDark: isDark,
            onTranscribed: (text) {
              if (text.trim().isNotEmpty) {
                final old = _notesController.text.trim();
                final now = DateTime.now();
                final dateStr = '${now.month}/${now.day} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                final updated = old.isEmpty ? '[$dateStr 拜訪語音速記]\n$text' : '$old\n\n[$dateStr 拜訪語音速記]\n$text';
                setState(() {
                  _notesController.text = updated;
                });
                _saveBasicInfo();
                CustomToast.show(context, '✅ 語音速記已轉錄並自動追加儲存！', ToastType.success);
              }
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              _notesController.text.isEmpty ? '尚無語音拜訪速記紀錄。可點擊上方麥克風隨手錄音自動轉錄儲存。' : _notesController.text,
              style: TextStyle(fontSize: 12, color: textColor, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF10B981)),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
        ],
      ),
    );
  }
}
