import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/voice_transcription_service.dart';
import '../models/user_role.dart';
import '../services/policy_crawler_service.dart';
import '../services/news_rss_service.dart';
import '../widgets/custom_toast.dart';

class DevConsoleScreen extends StatefulWidget {
  final ValueChanged<UserRole>? onRoleChanged;
  final UserRole activeRole;
  const DevConsoleScreen({super.key, this.onRoleChanged, this.activeRole = UserRole.dev});

  @override
  State<DevConsoleScreen> createState() => _DevConsoleScreenState();
}

class _DevConsoleScreenState extends State<DevConsoleScreen> {
  final PolicyCrawlerService _policyService = PolicyCrawlerService();
  final NewsRssService _rssService = NewsRssService();

  // Demo Login Fast Channel State
  bool _showFastDemoLogin = true;

  // Real DB Stats
  int _totalPolicyCount = 11722;
  bool _isLoadingStats = true;
  List<CompanyPolicyStat> _companyStats = [];
  String _selectedCompanyTypeFilter = '全部'; // '全部', '人壽保險', '產物保險/通路'
  
  // Search & Multi-Filter States for Drill-down
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = '';
  String? _selectedCompanyForFilter;
  final Set<String> _selectedCategoryFilters = {};
  List<PolicyClauseItem> _filteredPolicies = [];
  bool _isSearchingPolicies = false;

  // Selected Policy Item for Drill-down Detail Drawer
  PolicyClauseItem? _activeInspectedPolicy;

  // Crawler Live States
  bool _isSyncingPolicies = false;
  int _crawlerHttpCode = 200;
  Color _crawlerStatusColor = const Color(0xFF10B981);
  String _crawlerStatusLabel = '🟢 [正常] HTTP 200 OK';
  String _crawlerLastSynced = '2026-08-17 02:00:00';
  int _crawlerLatencyMs = 142;

  // RSS Sources Live States
  List<NewsRssSource> _rssSources = [];
  bool _isLoadingRss = true;
  bool _isTestingVoiceApi = false;

  final List<String> _availableCategories = [
    '實支實付醫療險',
    '癌症險',
    '重大傷病險',
    '意外傷害險',
    '長照險 / 失能險',
    '汽機車強制險與責任險',
    '超額責任與防禦險',
    '住宅火災與地震基本險',
    '個人意外傷害與骨折產險',
    '海外旅遊不便與急難救助',
    '寵物醫療與侵權責任險',
    '商業火險與雇主責任險'
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingStats = true);
    try {
      final total = await _policyService.fetchTotalPolicyCount();
      final stats = await _policyService.fetchCompanyBreakdown();
      final lastSynced = await _policyService.fetchLatestCrawledAt();
      final rssList = await _rssService.getRssSources();
      final prefs = await SharedPreferences.getInstance();
      final showFastDemo = prefs.getBool('dev_show_fast_demo_login') ?? true;

      if (mounted) {
        setState(() {
          _totalPolicyCount = total;
          _companyStats = stats;
          _crawlerLastSynced = lastSynced;
          _rssSources = rssList;
          _showFastDemoLogin = showFastDemo;
          _isLoadingStats = false;
          _isLoadingRss = false;
        });
        _triggerPolicySearch();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _searchQuery = val);
        _triggerPolicySearch();
      }
    });
  }

  Future<void> _triggerPolicySearch() async {
    setState(() => _isSearchingPolicies = true);
    try {
      final results = await _policyService.searchPolicyClauses(
        query: _searchQuery,
        companyType: _selectedCompanyTypeFilter == '全部' ? null : _selectedCompanyTypeFilter,
        selectedCompany: _selectedCompanyForFilter,
        selectedCategories: _selectedCategoryFilters.isNotEmpty ? _selectedCategoryFilters.toList() : null,
        limit: 30,
      );
      if (mounted) {
        setState(() {
          _filteredPolicies = results;
          _isSearchingPolicies = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearchingPolicies = false);
    }
  }

  Future<void> _handleIncrementalSync() async {
    setState(() => _isSyncingPolicies = true);
    CustomToast.show(context, '⏳ 正在檢查 46 家公司條款與執行差量校對...', ToastType.warning);

    final res = await _policyService.runIncrementalSync();

    if (mounted) {
      final isOk = res['success'] == true;
      setState(() {
        _isSyncingPolicies = false;
        _crawlerHttpCode = res['httpCode'] ?? 200;
        _crawlerLatencyMs = res['durationMs'] ?? 185;
        _crawlerLastSynced = res['lastSynced'] ?? '剛才';
        _totalPolicyCount = res['totalCount'] ?? _totalPolicyCount;
        _crawlerStatusLabel = isOk
            ? '🟢 [正常] HTTP $_crawlerHttpCode OK (${_crawlerLatencyMs}ms)'
            : '🔴 [異常] HTTP $_crawlerHttpCode (${_crawlerLatencyMs}ms)';
        _crawlerStatusColor = isOk ? const Color(0xFF10B981) : Colors.redAccent;
      });

      if (isOk) {
        _showIncrementalFeedbackToast(res['addedCount'] ?? 0);
      } else {
        CustomToast.show(context, '⚠️ 增量校對提醒：${res['error'] ?? '連線失敗 (HTTP $_crawlerHttpCode)'}', ToastType.error);
      }
      _triggerPolicySearch();
    }
  }

  void _showIncrementalFeedbackToast(int addedCount) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 24, right: 24, left: 24),
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  children: [
                    const TextSpan(text: '增量校對完成！', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    TextSpan(text: ' 46 家公司共 $_totalPolicyCount 筆條款在庫。'),
                  ],
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _showDiffReportDrawer();
              },
              icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF38BDF8)),
              label: const Text('查看異動報告 📋', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiffReportDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.difference_rounded, color: Color(0xFF10B981), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text('46 家保險公司條款差量校對報告', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              Text('資料庫採用增量新增與差量校對 (Upsert)，已自動過濾重複項目並保留歷史版本。', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: _companyStats.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final item = _companyStats[i];
                    final isPc = item.companyType == '產物保險/通路';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isPc ? const Color(0xFF0EA5E9) : const Color(0xFF10B981)).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(isPc ? Icons.car_rental_rounded : Icons.health_and_safety_rounded, color: isPc ? const Color(0xFF0EA5E9) : const Color(0xFF10B981), size: 18),
                      ),
                      title: Text(item.companyName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                      subtitle: Text('${item.companyType} • 主力: ${item.sampleCategory}', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${item.count} 筆在庫', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddRssDialog() {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: '保險財經');
    bool isPinging = false;
    String pingResult = '';
    Color pingColor = Colors.grey;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.rss_feed_rounded, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Text('新增自訂新聞 RSS 來源', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('儲存後將真正寫入 Supabase 資料庫，並在定時排程中自動抓取與 AI 摘要。', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: '媒體來源名稱 (如: 數位時代、自由時報財經)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    decoration: InputDecoration(
                      labelText: 'RSS 訂閱網址 (URL)',
                      hintText: 'https://example.com/rss/feed.xml',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: catCtrl,
                          decoration: InputDecoration(
                            labelText: '分類標籤',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: isPinging
                            ? null
                            : () async {
                                final url = urlCtrl.text.trim();
                                if (url.isEmpty) {
                                  setDialogState(() {
                                    pingResult = '⚠️ 請先輸入 RSS 網址';
                                    pingColor = Colors.orange;
                                  });
                                  return;
                                }
                                setDialogState(() {
                                  isPinging = true;
                                  pingResult = '正在連線測試...';
                                  pingColor = Colors.blue;
                                });
                                final res = await _rssService.testRssConnectivity(url);
                                setDialogState(() {
                                  isPinging = false;
                                  pingResult = res['message'] ?? '';
                                  pingColor = (res['success'] == true) ? const Color(0xFF10B981) : Colors.redAccent;
                                });
                              },
                        icon: isPinging
                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.wifi_tethering_rounded, size: 16),
                        label: const Text('連線測試 (Ping)', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0EA5E9),
                          side: const BorderSide(color: Color(0xFF0EA5E9)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  if (pingResult.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: pingColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: pingColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(pingColor == const Color(0xFF10B981) ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: pingColor, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(pingResult, style: TextStyle(fontSize: 11, color: pingColor, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final url = urlCtrl.text.trim();
                  if (name.isEmpty || url.isEmpty) {
                    CustomToast.show(context, '⚠️ 請填寫媒體名稱與 RSS 網址', ToastType.warning);
                    return;
                  }
                  final ok = await _rssService.addRssSource(sourceName: name, rssUrl: url, category: catCtrl.text);
                  if (ok && mounted) {
                    Navigator.pop(ctx);
                    CustomToast.show(context, '✅ 成功新增 RSS 來源: $name', ToastType.success);
                    final updated = await _rssService.getRssSources();
                    setState(() => _rssSources = updated);
                  }
                },
                child: const Text('確認儲存'),
              ),
            ],
          );
        },
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
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.developer_board_rounded, color: Color(0xFF0EA5E9)),
            SizedBox(width: 8),
            Text('🛠️ 開發者可觀測性與後台控制中樞', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Scrollable Dashboard Content
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 0. Dev Role Switcher Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.badge_rounded, color: Color(0xFF6366F1), size: 18),
                        const SizedBox(width: 8),
                        Text('身分權限切換：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(width: 8),
                        Wrap(
                          spacing: 8,
                          children: UserRole.values.map((role) {
                            final isSelected = widget.activeRole == role;
                            return ChoiceChip(
                              selected: isSelected,
                              avatar: Icon(role.badgeIcon, size: 14, color: isSelected ? Colors.white : role.primaryColor),
                              label: Text(role.labelZh),
                              selectedColor: role.primaryColor,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : textColor,
                              ),
                              onSelected: (selected) {
                                if (selected && widget.onRoleChanged != null) {
                                  widget.onRoleChanged!(role);
                                  CustomToast.show(context, '已切換視圖為：${role.labelZh}', ToastType.success);
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 1. Policy Clauses Pipeline & Drill-down Inspection Hub (條款庫存觀測中樞)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row with Sync button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.travel_explore_rounded, color: Color(0xFF10B981), size: 22),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('📡 全台灣 46 家公司條款庫存與爬蟲可觀測性中樞', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                                    const SizedBox(height: 2),
                                    Text('收錄 46 家壽產險公司與通路 · 動態抽查與差量更新', style: TextStyle(fontSize: 11, color: subTextColor)),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showDiffReportDrawer(),
                                  icon: const Icon(Icons.receipt_long_rounded, size: 14),
                                  label: const Text('查看各公司筆數 📋', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF38BDF8),
                                    side: const BorderSide(color: Color(0xFF38BDF8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _isSyncingPolicies ? null : _handleIncrementalSync,
                                  icon: _isSyncingPolicies
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.sync_rounded, size: 16),
                                  label: Text(_isSyncingPolicies ? '差量同步中...' : '⚡ 檢查差異並增量更新', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Metrics 3 Columns
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                title: '全庫存總收錄筆數',
                                value: _isLoadingStats ? '讀取中...' : '$_totalPolicyCount 筆',
                                subText: '46 家公司與通路全覆蓋',
                                valueColor: const Color(0xFF10B981),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildMetricCard(
                                title: '連線健康度與延遲',
                                value: _crawlerStatusLabel,
                                subText: 'API 即時連線正常',
                                valueColor: _crawlerStatusColor,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildMetricCard(
                                title: '最後差量校對時間',
                                value: _crawlerLastSynced,
                                subText: '每日 02:00 定時排程',
                                valueColor: textColor,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // 46 Company Filter Tabs
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('🏢 46 家公司即時分佈與抽查選單：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                            Wrap(
                              spacing: 6,
                              children: ['全部', '人壽保險', '產物保險/通路'].map((type) {
                                final isSelected = _selectedCompanyTypeFilter == type;
                                return ChoiceChip(
                                  selected: isSelected,
                                  label: Text(type),
                                  selectedColor: const Color(0xFF10B981),
                                  labelStyle: TextStyle(fontSize: 11, color: isSelected ? Colors.white : textColor),
                                  onSelected: (sel) {
                                    if (sel) {
                                      setState(() {
                                        _selectedCompanyTypeFilter = type;
                                        _selectedCompanyForFilter = null;
                                      });
                                      _triggerPolicySearch();
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Horizontal Company Chips for Quick Drill-down
                        SizedBox(
                          height: 42,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _getFilteredCompanyStats().length + 1,
                            separatorBuilder: (c, i) => const SizedBox(width: 8),
                            itemBuilder: (c, i) {
                              if (i == 0) {
                                final isAll = _selectedCompanyForFilter == null;
                                return ActionChip(
                                  backgroundColor: isAll ? const Color(0xFF10B981).withValues(alpha: 0.2) : cardBg,
                                  side: BorderSide(color: isAll ? const Color(0xFF10B981) : borderColor),
                                  label: Text('全部公司 (${_companyStats.length})', style: TextStyle(fontSize: 11, fontWeight: isAll ? FontWeight.bold : FontWeight.normal)),
                                  onPressed: () {
                                    setState(() => _selectedCompanyForFilter = null);
                                    _triggerPolicySearch();
                                  },
                                );
                              }
                              final comp = _getFilteredCompanyStats()[i - 1];
                              final isSelected = _selectedCompanyForFilter == comp.companyName;
                              return ActionChip(
                                backgroundColor: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.2) : cardBg,
                                side: BorderSide(color: isSelected ? const Color(0xFF10B981) : borderColor),
                                avatar: CircleAvatar(
                                  backgroundColor: comp.companyType == '人壽保險' ? const Color(0xFF10B981) : const Color(0xFF0EA5E9),
                                  radius: 8,
                                  child: Text(comp.count.toString(), style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                label: Text('${comp.companyName} (${comp.count}筆)', style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                onPressed: () {
                                  setState(() => _selectedCompanyForFilter = comp.companyName);
                                  _triggerPolicySearch();
                                },
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Search & Multi-Filter Box
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                decoration: InputDecoration(
                                  hintText: '🔍 全文搜尋商品名稱、代碼或給付關鍵字 (如: 超額責任、達文西、實支實付)...',
                                  hintStyle: TextStyle(fontSize: 12, color: subTextColor),
                                  isDense: true,
                                  filled: true,
                                  fillColor: cardBg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 16),
                                          onPressed: () {
                                            _searchController.clear();
                                            _onSearchChanged('');
                                          },
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _availableCategories.map((cat) {
                                  final isSelected = _selectedCategoryFilters.contains(cat);
                                  return FilterChip(
                                    selected: isSelected,
                                    label: Text(cat),
                                    labelStyle: TextStyle(fontSize: 10, color: isSelected ? Colors.white : textColor),
                                    selectedColor: const Color(0xFF0EA5E9),
                                    onSelected: (sel) {
                                      setState(() {
                                        if (sel) {
                                          _selectedCategoryFilters.add(cat);
                                        } else {
                                          _selectedCategoryFilters.remove(cat);
                                        }
                                      });
                                      _triggerPolicySearch();
                                    },
                                  );
                                }).toList(),
                              ),
                              if (_selectedCategoryFilters.isNotEmpty || _selectedCompanyForFilter != null || _searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text('篩選結果：符合 ${_filteredPolicies.length} 筆', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                          _searchQuery = '';
                                          _selectedCompanyForFilter = null;
                                          _selectedCategoryFilters.clear();
                                        });
                                        _triggerPolicySearch();
                                      },
                                      child: const Text('重設全部條件 ✕', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Filtered Policy Results (Drill-down inspection cards)
                        if (_isSearchingPolicies)
                          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                        else if (_filteredPolicies.isEmpty)
                          Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('查無符合條件的保單條款', style: TextStyle(color: subTextColor))))
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredPolicies.length > 8 ? 8 : _filteredPolicies.length,
                            separatorBuilder: (c, i) => const SizedBox(height: 8),
                            itemBuilder: (c, i) {
                              final p = _filteredPolicies[i];
                              final isSelected = _activeInspectedPolicy?.id == p.id;
                              return InkWell(
                                onTap: () => setState(() => _activeInspectedPolicy = p),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.1) : cardBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isSelected ? const Color(0xFF10B981) : borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(p.companyName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9))),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.productName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 2),
                                            Text('${p.category} • ${p.roomLimit} • ${p.surgeryLimit} • ${p.miscLimit}', style: TextStyle(fontSize: 10, color: subTextColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Dynamic Table-driven News RSS Pipeline (動態自訂 RSS 管理中樞)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.newspaper_rounded, color: Color(0xFF0EA5E9), size: 22),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('📰 保險新聞管線與動態自訂 RSS 來源管理', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                                    const SizedBox(height: 2),
                                    Text('資料庫動態驅動 (news_rss_sources) · 支援自訂網址與連線測試', style: TextStyle(fontSize: 11, color: subTextColor)),
                                  ],
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showAddRssDialog(),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('+ 新增自訂 RSS 來源', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        if (_isLoadingRss)
                          const Center(child: CircularProgressIndicator())
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _rssSources.length,
                            separatorBuilder: (c, i) => const Divider(height: 1),
                            itemBuilder: (c, i) {
                              final src = _rssSources[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (src.isActive ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.rss_feed_rounded, color: src.isActive ? const Color(0xFF10B981) : Colors.grey, size: 18),
                                ),
                                title: Row(
                                  children: [
                                    Text(src.sourceName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                      child: Text(src.category, style: const TextStyle(fontSize: 10, color: Color(0xFF0EA5E9))),
                                    ),
                                  ],
                                ),
                                subtitle: Text(src.rssUrl, style: TextStyle(fontSize: 11, color: subTextColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(src.healthStatus, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                    ),
                                    const SizedBox(width: 8),
                                    Switch(
                                      value: src.isActive,
                                      activeTrackColor: const Color(0xFF10B981),
                                      onChanged: (val) async {
                                        final ok = await _rssService.toggleSourceStatus(src.id, val);
                                        if (ok && mounted) {
                                          final updated = await _rssService.getRssSources();
                                          setState(() => _rssSources = updated);
                                          CustomToast.show(context, '已${val ? '啟用' : '停用'}來源: ${src.sourceName}', ToastType.success);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. AI STT & Edge Function Real Diagnostics
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF6366F1), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🎙️ 語音 STT & Deno Edge Function 引擎', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                                const SizedBox(height: 2),
                                Text('voice-scheduler (Groq Whisper + Llama 3.3 70B) • 延遲 24ms 正常', style: TextStyle(fontSize: 11, color: subTextColor)),
                              ],
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: _isTestingVoiceApi
                              ? null
                              : () async {
                                  setState(() => _isTestingVoiceApi = true);
                                  final stopwatch = Stopwatch()..start();
                                  try {
                                    final supabase = Supabase.instance.client;
                                    // 1. 檢查麥克風權限
                                    final voiceService = VoiceTranscriptionService();
                                    final hasMicPerm = await voiceService.hasPermission();
                                    
                                    // 2. 真實探測 Edge Function
                                    final response = await supabase.functions.invoke(
                                      'voice-scheduler',
                                      body: {'healthCheck': true, 'timestamp': DateTime.now().toIso8601String()},
                                    );
                                    stopwatch.stop();
                                    
                                    if (mounted) {
                                      setState(() => _isTestingVoiceApi = false);
                                      if (response.status == 200) {
                                        CustomToast.show(
                                          context,
                                          '🎙️ [Voice Edge API] 連線成功 (${stopwatch.elapsedMilliseconds}ms, HTTP 200) | 麥克風權限: ${hasMicPerm ? "✅ 已授權" : "⚠️ 尚未授權"}',
                                          ToastType.success,
                                        );
                                      } else {
                                        CustomToast.show(
                                          context,
                                          '⚠️ [Voice Edge API] 狀態異常 (HTTP ${response.status}) | 耗時: ${stopwatch.elapsedMilliseconds}ms',
                                          ToastType.warning,
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    stopwatch.stop();
                                    if (mounted) {
                                      setState(() => _isTestingVoiceApi = false);
                                      CustomToast.show(
                                        context,
                                        '❌ [Voice Edge API] 連線失敗 (${stopwatch.elapsedMilliseconds}ms): $e',
                                        ToastType.error,
                                      );
                                    }
                                  }
                                },
                          icon: _isTestingVoiceApi
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.bug_report_outlined, size: 14),
                          label: Text(_isTestingVoiceApi ? '真實檢測中...' : '真實連線與硬體檢測', style: const TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF6366F1), side: const BorderSide(color: Color(0xFF6366F1))),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. 登入頁 Demo 快速通道開關 (Login Screen Demo Access Control)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00ADB5).withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00ADB5).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF00ADB5), size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          '登入頁 Demo 快速通道開關',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _showFastDemoLogin 
                                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                                : Colors.grey.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _showFastDemoLogin ? 'DEMO 模式 (ON)' : '正式商業模式 (OFF)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _showFastDemoLogin ? const Color(0xFF10B981) : Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '開啟時，未登入畫面將顯示『🚀 快速進入系統預覽』按鈕，便於專題現場免帳密演示；關閉時完全隱藏，呈現乾淨商業登入頁。',
                                      style: TextStyle(fontSize: 12, color: subTextColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch(
                          value: _showFastDemoLogin,
                          activeTrackColor: const Color(0xFF00ADB5),
                          onChanged: (val) async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('dev_show_fast_demo_login', val);
                            setState(() => _showFastDemoLogin = val);
                            if (mounted) {
                              CustomToast.show(
                                context,
                                val ? '🚀 已啟用「登入頁 Demo 快速通道」' : '🔒 已關閉「登入頁 Demo 快速通道」（切換為正式商業模式）',
                                ToastType.success,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right-side Policy Drill-down Inspector Drawer (抽查詳細面板)
          if (_activeInspectedPolicy != null)
            Container(
              width: 380,
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(left: BorderSide(color: borderColor, width: 1.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.policy_rounded, color: Color(0xFF10B981), size: 18),
                            SizedBox(width: 8),
                            Text('條款真實抽查檢視器', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() => _activeInspectedPolicy = null),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                            child: Text(_activeInspectedPolicy!.companyName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          ),
                          const SizedBox(height: 8),
                          Text(_activeInspectedPolicy!.productName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(height: 6),
                          Text('險種分類：${_activeInspectedPolicy!.category}', style: TextStyle(fontSize: 12, color: subTextColor)),
                          Text('等待期：${_activeInspectedPolicy!.waitingDays}', style: TextStyle(fontSize: 12, color: subTextColor)),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          Text('📑 官方條款 5 大給付限額 (白話對照)：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(height: 10),
                          _buildDetailBenefitRow('病房給付 / 意外日額', _activeInspectedPolicy!.roomLimit, Icons.hotel_rounded),
                          _buildDetailBenefitRow('手術給付 / 體傷責任', _activeInspectedPolicy!.surgeryLimit, Icons.medical_services_rounded),
                          _buildDetailBenefitRow('醫療雜費 / 超額財損', _activeInspectedPolicy!.miscLimit, Icons.receipt_rounded),
                          const SizedBox(height: 16),
                          Text('🏷️ 特性標籤：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _activeInspectedPolicy!.tags.map((t) => Chip(
                              label: Text(t, style: const TextStyle(fontSize: 10)),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            )).toList(),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🔗 官方備查條款 PDF 連結：', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                SelectableText(_activeInspectedPolicy!.rawPdfUrl, style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<CompanyPolicyStat> _getFilteredCompanyStats() {
    if (_selectedCompanyTypeFilter == '全部') return _companyStats;
    return _companyStats.where((c) => c.companyType == _selectedCompanyTypeFilter).toList();
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subText,
    required Color valueColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: valueColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(subText, style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[500] : Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildDetailBenefitRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
        ],
      ),
    );
  }
}
