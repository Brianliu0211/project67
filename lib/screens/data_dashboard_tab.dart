import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/customer_policy_service.dart';
import '../services/policy_crawler_service.dart';
import '../widgets/custom_toast.dart';
import 'policy_comparison_screen.dart';

class DataDashboardTab extends StatefulWidget {
  final Function(String menu)? onMenuChanged;

  const DataDashboardTab({super.key, this.onMenuChanged});

  @override
  State<DataDashboardTab> createState() => _DataDashboardTabState();
}

class _DataDashboardTabState extends State<DataDashboardTab> {
  final PolicyCrawlerService _policyService = PolicyCrawlerService();
  final CustomerPolicyService _customerPolicyService = CustomerPolicyService();

  bool _isLoading = true;
  bool _isSearching = false;
  int _totalLiveClausesCount = 0;

  // Real Funnel Metrics
  CustomerFunnelSummary _funnelSummary = CustomerFunnelSummary(
    totalCustomers: 0,
    leadsCount: 0,
    prospectsCount: 0,
    clientsCount: 0,
    monthlyVisitsCompleted: 0,
    monthlyVisitsTotal: 0,
    activeProjectsCount: 0,
  );

  // Selected Products for Side-by-Side Comparison (2 to 8 items)
  final List<PolicyClauseItem> _selectedProducts = [];

  // Filter State
  String _activeCategory = '全部';
  String _activeCompany = '全部公司';
  final TextEditingController _searchController = TextEditingController();

  // Search Results
  List<PolicyClauseItem> _clauseItems = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _filteredCount = 0;

  // SafeCheck Categories
  final List<String> _categoryFilters = [
    '全部',
    '實支實付醫療險',
    '日額型醫療險',
    '手術險',
    '癌症險',
    '重大傷病險',
    '長照險 / 失能險',
    '意外傷害險',
    '定期壽險',
    '終身壽險',
    '儲蓄險 / 年金險',
    '汽機車責任與超額險',
    '火險與產物責任險',
    '旅平不便險',
    '寵物險',
  ];

  @override
  void initState() {
    super.initState();
    _fetchInitialLiveDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialLiveDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // 1. 動態取得資料庫真實條款總數 (12,090+)
      final totalCount = await _policyService.fetchTotalPolicyCount();
      
      // 2. 實時聚合名下客戶真實經營漏斗 (未開發 / 跟進中 / 已簽單保戶 / 本月拜訪達成率)
      final funnel = await _customerPolicyService.fetchRealSalesFunnelMetrics();

      if (mounted) {
        setState(() {
          _totalLiveClausesCount = totalCount;
          _funnelSummary = funnel;
        });
      }

      // 3. 載入第一頁實體條款資料
      await _executeClauseSearch(resetPage: true);
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '資料載入異常: $e', ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _executeClauseSearch({bool resetPage = false}) async {
    if (resetPage) {
      _currentPage = 1;
    }
    setState(() => _isSearching = true);

    try {
      final selectedCats = _activeCategory == '全部' ? null : [_activeCategory];

      final result = await _policyService.searchPolicyClausesPaged(
        query: _searchController.text.trim(),
        selectedCompany: _activeCompany == '全部公司' ? null : _activeCompany,
        selectedCategories: selectedCats,
        page: _currentPage,
        pageSize: 12,
      );

      if (mounted) {
        setState(() {
          _clauseItems = result.items;
          _filteredCount = result.totalCount;
          _totalPages = result.totalPages;
        });
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _toggleProductSelection(PolicyClauseItem prod) {
    setState(() {
      final index = _selectedProducts.indexWhere((p) => p.id == prod.id);
      if (index != -1) {
        _selectedProducts.removeAt(index);
      } else {
        if (_selectedProducts.length >= 8) {
          CustomToast.show(context, '⚠️ 最多僅能同時選擇 8 款商品進行橫向並排比較', ToastType.warning);
        } else {
          _selectedProducts.add(prod);
        }
      }
    });
  }

  void _openComparisonScreen() {
    if (_selectedProducts.isEmpty) {
      CustomToast.show(context, '請先在下方勾選要比較的商品 (2~8 款)', ToastType.warning);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => PolicyComparisonScreen(
          initialProducts: _selectedProducts,
        ),
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

    final formatter = NumberFormat('#,###');

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchInitialLiveDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. 🔴 頂部真實業務漏斗指標卡 (Sales Funnel & Live DB Metrics)
                        Row(
                          children: [
                            Expanded(
                              child: _buildFunnelCard(
                                title: '名下客戶總量',
                                mainVal: '${_funnelSummary.totalCustomers} 位',
                                subtitle: '🌟 保戶 ${_funnelSummary.clientsCount} | 💬 跟進 ${_funnelSummary.prospectsCount} | 🎯 未開發 ${_funnelSummary.leadsCount}',
                                icon: Icons.people_alt_rounded,
                                color: const Color(0xFF6366F1),
                                isDark: isDark,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textColor: textColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFunnelCard(
                                title: '本月拜訪戰況',
                                mainVal: '${_funnelSummary.monthlyVisitsCompleted} / ${_funnelSummary.monthlyVisitsTotal} 次',
                                subtitle: '達成率 ${(_funnelSummary.monthlyVisitRate * 100).toInt()}% • 實體行程對接',
                                icon: Icons.event_available_rounded,
                                color: const Color(0xFF10B981),
                                isDark: isDark,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textColor: textColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFunnelCard(
                                title: '推動中拜訪專案',
                                mainVal: '${_funnelSummary.activeProjectsCount} 個專案',
                                subtitle: 'CRM 名單勾選核銷進行中',
                                icon: Icons.assignment_turned_in_rounded,
                                color: const Color(0xFFF59E0B),
                                isDark: isDark,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textColor: textColor,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 2. 🌸 搜尋列與動態計數 Header (對齊 SafeCheck 截圖 1)
                        Container(
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
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      onSubmitted: (_) => _executeClauseSearch(resetPage: true),
                                      decoration: InputDecoration(
                                        hintText: '搜尋商品名稱、代碼、保險公司...',
                                        prefixIcon: const Icon(Icons.search_rounded),
                                        suffixIcon: _searchController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear_rounded, size: 18),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  _executeClauseSearch(resetPage: true);
                                                },
                                              )
                                            : null,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: () => _executeClauseSearch(resetPage: true),
                                    icon: const Icon(Icons.search_rounded, size: 16),
                                    label: const Text('搜尋', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE53E3E), // SafeCheck signature red
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // 動態即時筆數 Badge
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final hasFilter = _activeCategory != '全部' || _activeCompany != '全部公司' || _searchController.text.trim().isNotEmpty;
                                      final displayCount = hasFilter ? _filteredCount : _totalLiveClausesCount;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE53E3E).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.filter_list_rounded, size: 14, color: Color(0xFFE53E3E)),
                                            const SizedBox(width: 4),
                                            Text(
                                              '篩選 找到 ${formatter.format(displayCount)} 款商品 (資料庫全量 ${formatter.format(_totalLiveClausesCount)} 款)',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE53E3E)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  if (_selectedProducts.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: _openComparisonScreen,
                                      icon: const Icon(Icons.compare_arrows_rounded, size: 16, color: Color(0xFFE53E3E)),
                                      label: Text('前往並排比較 (${_selectedProducts.length}/8)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE53E3E))),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // 險種大分類 ChoiceChips
                              const Text('險種分類：', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 6),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _categoryFilters.map((cat) {
                                    final isSel = _activeCategory == cat;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                        selected: isSel,
                                        selectedColor: const Color(0xFFE53E3E),
                                        labelStyle: TextStyle(color: isSel ? Colors.white : textColor),
                                        onSelected: (_) {
                                          setState(() => _activeCategory = cat);
                                          _executeClauseSearch(resetPage: true);
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // 3. 🌸 商品卡片網格清單 (對齊 SafeCheck 截圖 2)
                        _isSearching
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            : _clauseItems.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.all(40),
                                    alignment: Alignment.center,
                                    child: Column(
                                      children: [
                                        Icon(Icons.search_off_rounded, size: 48, color: subTextColor),
                                        const SizedBox(height: 12),
                                        Text('未找到符合條件的條款商品', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                                        const SizedBox(height: 4),
                                        Text('請嘗試調整搜尋關鍵字或險種分類', style: TextStyle(fontSize: 12, color: subTextColor)),
                                      ],
                                    ),
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final crossAxisCount = constraints.maxWidth > 1000
                                          ? 3
                                          : constraints.maxWidth > 650
                                              ? 2
                                              : 1;
                                      return GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: crossAxisCount,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          mainAxisExtent: 220,
                                        ),
                                        itemCount: _clauseItems.length,
                                        itemBuilder: (ctx, idx) {
                                          final prod = _clauseItems[idx];
                                          final isSelected = _selectedProducts.any((p) => p.id == prod.id);
                                          return _buildProductCard(
                                            prod: prod,
                                            isSelected: isSelected,
                                            isDark: isDark,
                                            cardBg: cardBg,
                                            borderColor: borderColor,
                                            textColor: textColor,
                                            subTextColor: subTextColor,
                                          );
                                        },
                                      );
                                    },
                                  ),

                        const SizedBox(height: 16),

                        // 分頁導航控制器
                        if (_totalPages > 1)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: _currentPage > 1
                                    ? () {
                                        setState(() => _currentPage--);
                                        _executeClauseSearch();
                                      }
                                    : null,
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              Text('第 $_currentPage / $_totalPages 頁', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                              IconButton(
                                onPressed: _currentPage < _totalPages
                                    ? () {
                                        setState(() => _currentPage++);
                                        _executeClauseSearch();
                                      }
                                    : null,
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

          // 4. ⚔️ 底部亮橘色浮動選取列 (對齊 SafeCheck 截圖 2)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _selectedProducts.isNotEmpty
                  ? Container(
                      key: const ValueKey('safecheck_bar'),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53E3E), // SafeCheck signature Orange/Red
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '已選 ${_selectedProducts.length}/8 款商品',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedProducts.map((p) => p.id.length > 6 ? p.id.substring(0, 6).toUpperCase() : p.id.toUpperCase()).join('  '),
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => setState(() => _selectedProducts.clear()),
                                child: const Text('清除', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _openComparisonScreen,
                                icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFE53E3E),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                label: const Text('開始比較', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  // 業務漏斗指標卡
  Widget _buildFunnelCard({
    required String title,
    required String mainVal,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
  }) {
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
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(mainVal, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // SafeCheck 風格商品卡片 (對齊 SafeCheck 截圖 2)
  Widget _buildProductCard({
    required PolicyClauseItem prod,
    required bool isSelected,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    final code = prod.id.length > 8 ? prod.id.substring(0, 8).toUpperCase() : prod.id.toUpperCase();

    return InkWell(
      onTap: () => _toggleProductSelection(prod),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFE53E3E) : borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 6, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Code & Selection Checkbox
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE53E3E) : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFFE53E3E) : Colors.grey.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        isSelected ? Icons.check : Icons.add,
                        size: 12,
                        color: isSelected ? Colors.white : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Company & Category
                Row(
                  children: [
                    Text(prod.companyName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE53E3E))),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(prod.category, style: const TextStyle(fontSize: 9.5, color: Color(0xFF6366F1), fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Product Name
                Text(
                  prod.productName,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),

            // Bottom Waiting days & limits
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('• ${prod.waitingDays}', style: TextStyle(fontSize: 10.5, color: subTextColor), overflow: TextOverflow.ellipsis),
                    ),
                    Text('雜費 ${prod.miscLimit}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
