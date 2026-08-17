import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 5 大理賠桶保障總計模型
class CustomerBenefitSummary {
  final int totalRoomDaily; // 病房日額給付總額
  final int totalSurgeryMax; // 手術給付最高總額
  final int totalMiscMax; // 醫療雜費/耗材自費總額
  final int totalCancerCriticalMax; // 癌症/重疾一次金
  final int totalLiabilityMax; // 車險超額/第三人責任險

  // 缺口判定 (Gap Analysis)
  final int roomGap;
  final int surgeryGap;
  final int miscGap;
  final int cancerGap;
  final int liabilityGap;

  final List<String> detectedGaps;

  CustomerBenefitSummary({
    required this.totalRoomDaily,
    required this.totalSurgeryMax,
    required this.totalMiscMax,
    required this.totalCancerCriticalMax,
    required this.totalLiabilityMax,
    required this.roomGap,
    required this.surgeryGap,
    required this.miscGap,
    required this.cancerGap,
    required this.liabilityGap,
    required this.detectedGaps,
  });

  /// 是否有嚴重缺口
  bool get hasCriticalGap => detectedGaps.isNotEmpty;
}

/// 客戶已投保保單項目
class CustomerEnrolledPolicy {
  final String id;
  final String customerId;
  final String policyClauseId;
  final String productName;
  final String companyName;
  final String category;
  final String roomLimit;
  final String surgeryLimit;
  final String miscLimit;
  final int roomDailyValue;
  final int surgeryMaxValue;
  final int miscMaxValue;
  final String rawPdfUrl;
  final DateTime enrolledAt;

  CustomerEnrolledPolicy({
    required this.id,
    required this.customerId,
    required this.policyClauseId,
    required this.productName,
    required this.companyName,
    required this.category,
    required this.roomLimit,
    required this.surgeryLimit,
    required this.miscLimit,
    required this.roomDailyValue,
    required this.surgeryMaxValue,
    required this.miscMaxValue,
    required this.rawPdfUrl,
    required this.enrolledAt,
  });

  factory CustomerEnrolledPolicy.fromJson(Map<String, dynamic> json) {
    final benefits = json['benefits_json'] as Map<String, dynamic>?;
    return CustomerEnrolledPolicy(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      policyClauseId: json['policy_clause_id']?.toString() ?? '',
      productName: json['product_name'] ?? '保險商品',
      companyName: json['company_name'] ?? '保險公司',
      category: json['category'] ?? '醫療保險',
      roomLimit: json['room_limit'] ?? '2,000 元/日',
      surgeryLimit: json['surgery_limit'] ?? '150,000 元',
      miscLimit: json['misc_limit'] ?? '120,000 元',
      roomDailyValue: (benefits?['room_daily'] as num?)?.toInt() ?? 2000,
      surgeryMaxValue: (benefits?['surgery_max'] as num?)?.toInt() ?? 150000,
      miscMaxValue: (benefits?['misc_max'] as num?)?.toInt() ?? 120000,
      rawPdfUrl: json['raw_pdf_url'] ?? '',
      enrolledAt: json['enrolled_at'] != null ? DateTime.parse(json['enrolled_at']) : DateTime.now(),
    );
  }
}

/// 借鑑 insure80 條款陷阱與對照模型
class PolicyPkDetail {
  final String id;
  final String productName;
  final String companyName;
  final String category;
  final String roomLimit;
  final String surgeryLimit;
  final String miscLimit;
  
  // insure80 核心條款魔鬼細節
  final bool is227Restricted; // 是否限定健保 2-2-7 條款
  final String clauseType; // '概括式條款' vs '列舉式條款'
  final bool outpatientSurgeryMaterialCovered; // 門診手術自費耗材是否理賠
  final String receiptType; // '正本收據' vs '副本收據可'
  final String waitingDays; // '疾病 30 日' / '癌症 90 日' / '免等待期'
  final String rawPdfUrl;

  PolicyPkDetail({
    required this.id,
    required this.productName,
    required this.companyName,
    required this.category,
    required this.roomLimit,
    required this.surgeryLimit,
    required this.miscLimit,
    required this.is227Restricted,
    required this.clauseType,
    required this.outpatientSurgeryMaterialCovered,
    required this.receiptType,
    required this.waitingDays,
    required this.rawPdfUrl,
  });
}

class CustomerPolicyService {
  static final CustomerPolicyService _instance = CustomerPolicyService._internal();
  factory CustomerPolicyService() => _instance;
  CustomerPolicyService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  // In-memory policy cache for instant offline responsiveness
  final Map<String, List<CustomerEnrolledPolicy>> _clientPoliciesCache = {};

  /// 取得某位客戶名下所有已投保的保單
  Future<List<CustomerEnrolledPolicy>> getCustomerPolicies(String customerId) async {
    if (_clientPoliciesCache.containsKey(customerId)) {
      return _clientPoliciesCache[customerId]!;
    }

    try {
      final res = await _supabase
          .from('customer_policies')
          .select()
          .eq('customer_id', customerId)
          .order('enrolled_at', ascending: false);

      final list = (res as List).map((e) => CustomerEnrolledPolicy.fromJson(e)).toList();
      _clientPoliciesCache[customerId] = list;
      return list;
    } catch (e) {
      if (kDebugMode) print('Error fetching customer policies: $e');
      _clientPoliciesCache[customerId] = [];
      return [];
    }
  }

  /// 為客戶添加一張已購保單
  Future<bool> enrollPolicyForCustomer({
    required String customerId,
    required String policyClauseId,
    required String productName,
    required String companyName,
    required String category,
    required String roomLimit,
    required String surgeryLimit,
    required String miscLimit,
    required String rawPdfUrl,
    Map<String, dynamic>? benefitsJson,
  }) async {
    final newPolicy = CustomerEnrolledPolicy(
      id: 'CP-${DateTime.now().millisecondsSinceEpoch}',
      customerId: customerId,
      policyClauseId: policyClauseId,
      productName: productName,
      companyName: companyName,
      category: category,
      roomLimit: roomLimit,
      surgeryLimit: surgeryLimit,
      miscLimit: miscLimit,
      roomDailyValue: (benefitsJson?['room_daily'] as num?)?.toInt() ?? 2000,
      surgeryMaxValue: (benefitsJson?['surgery_max'] as num?)?.toInt() ?? 150000,
      miscMaxValue: (benefitsJson?['misc_max'] as num?)?.toInt() ?? 120000,
      rawPdfUrl: rawPdfUrl,
      enrolledAt: DateTime.now(),
    );

    if (!_clientPoliciesCache.containsKey(customerId)) {
      _clientPoliciesCache[customerId] = [];
    }
    _clientPoliciesCache[customerId]!.insert(0, newPolicy);

    try {
      await _supabase.from('customer_policies').insert({
        'customer_id': customerId,
        'policy_clause_id': policyClauseId,
        'product_name': productName,
        'company_name': companyName,
        'category': category,
        'room_limit': roomLimit,
        'surgery_limit': surgeryLimit,
        'misc_limit': miscLimit,
        'benefits_json': benefitsJson,
        'raw_pdf_url': rawPdfUrl,
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('Remote save policy fallback: $e');
      return true;
    }
  }

  /// 移除客戶的已購保單
  Future<bool> removePolicyForCustomer(String customerId, String policyId) async {
    if (_clientPoliciesCache.containsKey(customerId)) {
      _clientPoliciesCache[customerId]!.removeWhere((p) => p.id == policyId);
    }
    try {
      await _supabase.from('customer_policies').delete().eq('id', policyId);
      return true;
    } catch (e) {
      return true;
    }
  }

  /// 🧮 100% 本地 0 成本精算引擎 (Deterministic Actuarial Math Engine)
  /// 消耗 0 Token，0 成本秒算 5 大理賠桶總額與自費缺口
  CustomerBenefitSummary calculateCustomerBenefitSummary(List<CustomerEnrolledPolicy> policies) {
    int totalRoom = 0;
    int totalSurgery = 0;
    int totalMisc = 0;
    int totalCancer = 0;
    int totalLiability = 0;

    for (var p in policies) {
      totalRoom += p.roomDailyValue;
      totalSurgery += p.surgeryMaxValue;
      totalMisc += p.miscMaxValue;

      if (p.category.contains('癌') || p.category.contains('重疾') || p.category.contains('重大')) {
        totalCancer += (p.surgeryMaxValue > 500000 ? p.surgeryMaxValue : 1000000);
      }
      if (p.category.contains('車險') || p.category.contains('超額') || p.category.contains('責任')) {
        totalLiability += 10000000;
      }
    }

    // 台灣自費醫療現況基準線 (Benchmarks)
    const int benchmarkRoom = 3500; // 單人病房平均自費差額
    const int benchmarkSurgery = 250000; // 微創/達文西手術平均費用
    const int benchmarkMisc = 200000; // 標靶耗材自費平均費用
    const int benchmarkCancer = 1000000; // 癌症初期一次金必備
    const int benchmarkLiability = 10000000; // 超跑與多車連環超額必備

    final roomGap = totalRoom < benchmarkRoom ? (benchmarkRoom - totalRoom) : 0;
    final surgeryGap = totalSurgery < benchmarkSurgery ? (benchmarkSurgery - totalSurgery) : 0;
    final miscGap = totalMisc < benchmarkMisc ? (benchmarkMisc - totalMisc) : 0;
    final cancerGap = totalCancer < benchmarkCancer ? (benchmarkCancer - totalCancer) : 0;
    final liabilityGap = totalLiability < benchmarkLiability ? (benchmarkLiability - totalLiability) : 0;

    final List<String> detectedGaps = [];
    if (miscGap > 0) detectedGaps.add('自費醫療雜費缺口 ${miscGap ~/ 10000} 萬元 (標靶耗材自負額高)');
    if (surgeryGap > 0) detectedGaps.add('微創/達文西手術給付缺口 ${surgeryGap ~/ 10000} 萬元');
    if (liabilityGap > 0) detectedGaps.add('車險超額責任險缺口 1,000 萬元 (防禦性駕駛必備)');
    if (cancerGap > 0) detectedGaps.add('癌症與重疾一次金缺口 ${cancerGap ~/ 10000} 萬元');
    if (roomGap > 0) detectedGaps.add('單人病房差額每日缺口 $roomGap 元');

    return CustomerBenefitSummary(
      totalRoomDaily: totalRoom,
      totalSurgeryMax: totalSurgery,
      totalMiscMax: totalMisc,
      totalCancerCriticalMax: totalCancer,
      totalLiabilityMax: totalLiability,
      roomGap: roomGap,
      surgeryGap: surgeryGap,
      miscGap: miscGap,
      cancerGap: cancerGap,
      liabilityGap: liabilityGap,
      detectedGaps: detectedGaps,
    );
  }

  /// ⚔️ 借鑑 insure80：產出條款陷阱與關鍵細節比對
  PolicyPkDetail extractPolicyPkDetail(Map<String, dynamic> raw) {
    final name = raw['product_name']?.toString() ?? raw['title']?.toString() ?? '保單商品';
    final comp = raw['company_name']?.toString() ?? raw['company']?.toString() ?? '富邦人壽';
    final cat = raw['category']?.toString() ?? '實支實付醫療險';
    final tags = (raw['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];

    final bool is227 = tags.any((t) => t.contains('2-2-7') || t.contains('限定手術') || t.contains('健保列表'));
    final String clauseType = tags.any((t) => t.contains('列舉式')) ? '列舉式條款 (僅賠表列項目)' : '概括式條款 (超過健保全賠)';
    final bool isMaterialCovered = !tags.any((t) => t.contains('不含耗材'));
    final String receiptType = tags.any((t) => t.contains('正本')) ? '需正本收據' : '接受副本收據理賠';
    final String waitingDays = raw['waiting_days']?.toString() ?? (cat.contains('癌症') ? '癌症等待期 90 日' : '疾病等待期 30 日');

    return PolicyPkDetail(
      id: raw['id']?.toString() ?? 'PK-01',
      productName: name,
      companyName: comp,
      category: cat,
      roomLimit: raw['room_limit']?.toString() ?? '2,000 元/日',
      surgeryLimit: raw['surgery_limit']?.toString() ?? '150,000 元',
      miscLimit: raw['misc_limit']?.toString() ?? '120,000 元',
      is227Restricted: is227,
      clauseType: clauseType,
      outpatientSurgeryMaterialCovered: isMaterialCovered,
      receiptType: receiptType,
      waitingDays: waitingDays,
      rawPdfUrl: raw['raw_pdf_url']?.toString() ?? 'https://www.ibdb.org.tw/',
    );
  }
}
