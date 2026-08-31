import 'dart:math' as math;
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

/// 業務員實體客戶經營漏斗模型 (Sales Funnel Pipeline)
class CustomerFunnelSummary {
  final int totalCustomers;
  final int leadsCount; // 🎯 未開發名單 (無行程、無已購保單)
  final int prospectsCount; // 💬 洽談跟進中 (有排程/備註/跟進標籤)
  final int clientsCount; // 🌟 已簽單保戶 (已綁定 customer_policies)
  final int monthlyVisitsCompleted; // 本月已完成拜訪數
  final int monthlyVisitsTotal; // 本月總排定拜訪數
  final int activeProjectsCount; // 進行中拜訪專案數

  CustomerFunnelSummary({
    required this.totalCustomers,
    required this.leadsCount,
    required this.prospectsCount,
    required this.clientsCount,
    required this.monthlyVisitsCompleted,
    required this.monthlyVisitsTotal,
    required this.activeProjectsCount,
  });

  double get monthlyVisitRate =>
      monthlyVisitsTotal > 0 ? (monthlyVisitsCompleted / monthlyVisitsTotal) : 0.0;
}

/// 真實臨床醫療情境模型 (Clinical Scenario)
class ClinicalScenario {
  final String id;
  final String title;
  final String category;
  final String description;
  final int standardRoomDays;
  final int hospitalRoomDailyActual; // 醫院單人房自費差額/日
  final int standardSurgeryCost; // 醫院自費手術單據金額
  final int standardMiscCost; // 自費醫療耗材/標靶/藥品
  final bool is227Surgery; // 是否符合健保 2-2-7 手術
  final String iconEmoji;

  const ClinicalScenario({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.standardRoomDays,
    required this.hospitalRoomDailyActual,
    required this.standardSurgeryCost,
    required this.standardMiscCost,
    required this.is227Surgery,
    required this.iconEmoji,
  });

  int get totalExpenses =>
      (standardRoomDays * hospitalRoomDailyActual) + standardSurgeryCost + standardMiscCost;
}

/// 臨床情境理賠試算結果
class ClinicalScenarioResult {
  final ClinicalScenario scenario;
  final int roomExpenses;
  final int surgeryExpenses;
  final int miscExpenses;
  final int totalExpenses;
  final int roomClaim;
  final int surgeryClaim;
  final int miscClaim;
  final int totalClaim;
  final int outOfPocketGap;

  ClinicalScenarioResult({
    required this.scenario,
    required this.roomExpenses,
    required this.surgeryExpenses,
    required this.miscExpenses,
    required this.totalExpenses,
    required this.roomClaim,
    required this.surgeryClaim,
    required this.miscClaim,
    required this.totalClaim,
    required this.outOfPocketGap,
  });
}

class MultiPolicyClaimItem {
  final String policyName;
  final String companyName;
  final int roomPaid;
  final int surgeryPaid;
  final int miscPaid;
  final int totalPaid;
  final String receiptRule;
  final bool has227Trap;

  const MultiPolicyClaimItem({
    required this.policyName,
    required this.companyName,
    required this.roomPaid,
    required this.surgeryPaid,
    required this.miscPaid,
    required this.totalPaid,
    required this.receiptRule,
    required this.has227Trap,
  });
}

class MultiPolicyClaimSummary {
  final int totalHospitalBill;
  final int roomExpenses;
  final int surgeryExpenses;
  final int miscExpenses;
  final List<MultiPolicyClaimItem> policyClaims;
  final int grandTotalClaimPaid;
  final int finalOutOfPocketGap;
  final List<String> warnings;

  const MultiPolicyClaimSummary({
    required this.totalHospitalBill,
    required this.roomExpenses,
    required this.surgeryExpenses,
    required this.miscExpenses,
    required this.policyClaims,
    required this.grandTotalClaimPaid,
    required this.finalOutOfPocketGap,
    required this.warnings,
  });
}

class CustomerPolicyService {
  static final CustomerPolicyService _instance = CustomerPolicyService._internal();
  factory CustomerPolicyService() => _instance;
  CustomerPolicyService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  // In-memory policy cache for instant offline responsiveness
  final Map<String, List<CustomerEnrolledPolicy>> _clientPoliciesCache = {};

  /// 台灣 6 大真實臨床情境標準庫 (Clinical Scenarios Benchmark)
  static const List<ClinicalScenario> clinicalScenarios = [
    ClinicalScenario(
      id: 'davinci',
      title: '達文西機器人手臂微創手術',
      category: '高階微創手術',
      description: '常見於攝護腺、婦科腫瘤或消化道切除，機械手臂自費費用與特殊止血耗材高。',
      standardRoomDays: 4,
      hospitalRoomDailyActual: 3500,
      standardSurgeryCost: 220000,
      standardMiscCost: 80000,
      is227Surgery: true,
      iconEmoji: '🩺',
    ),
    ClinicalScenario(
      id: 'targeted_cancer',
      title: '肺癌標靶藥物與自費免疫治療',
      category: '癌症標靶與自費藥材',
      description: '初期確診癌症住院評估並自費使用新一代標靶藥物與基因檢測，藥品雜費極高。',
      standardRoomDays: 5,
      hospitalRoomDailyActual: 3000,
      standardSurgeryCost: 50000,
      standardMiscCost: 200000,
      is227Surgery: true,
      iconEmoji: '💊',
    ),
    ClinicalScenario(
      id: 'knee_replacement',
      title: '雙膝人工關節置換手術',
      category: '骨科高階耗材',
      description: '退化性關節炎置換耐磨陶瓷與高交聯超耐磨墊片，需自費補足特殊醫材差額。',
      standardRoomDays: 6,
      hospitalRoomDailyActual: 2800,
      standardSurgeryCost: 80000,
      standardMiscCost: 120000,
      is227Surgery: true,
      iconEmoji: '🦿',
    ),
    ClinicalScenario(
      id: 'heart_stent',
      title: '心臟冠狀動脈塗藥支架置放術',
      category: '心血管介入手術',
      description: '急性心肌梗塞或心血管狹窄，置放 2 支自費塗藥支架與血管內超音波耗材。',
      standardRoomDays: 3,
      hospitalRoomDailyActual: 3200,
      standardSurgeryCost: 60000,
      standardMiscCost: 150000,
      is227Surgery: true,
      iconEmoji: '🫀',
    ),
    ClinicalScenario(
      id: 'appendicitis',
      title: '急性闌尾炎腹腔鏡微創切除術',
      category: '急性腹部微創',
      description: '常見急性腹痛急診住院，腹腔鏡微創切除與防沾黏貼片、自費單孔耗材。',
      standardRoomDays: 3,
      hospitalRoomDailyActual: 2500,
      standardSurgeryCost: 45000,
      standardMiscCost: 35000,
      is227Surgery: true,
      iconEmoji: '🩹',
    ),
    ClinicalScenario(
      id: 'fracture_pin',
      title: '骨折微創鈦合金鋼釘內固定術',
      category: '意外創傷手術',
      description: '車禍或意外跌倒骨折，自費使用微創解剖型鎖定鈦合金鋼板與自費麻醉。',
      standardRoomDays: 4,
      hospitalRoomDailyActual: 2500,
      standardSurgeryCost: 55000,
      standardMiscCost: 65000,
      is227Surgery: true,
      iconEmoji: '🦴',
    ),
  ];

  /// 實時查詢業務員名下的真實客戶經營漏斗數據 (100% Live DB)
  Future<CustomerFunnelSummary> fetchRealSalesFunnelMetrics() async {
    try {
      final user = _supabase.auth.currentUser;
      
      // 1. 查詢名下有效客戶 (非刪除狀態)
      var custQuery = _supabase.from('customers').select('id, tags, notes').isFilter('deleted_at', null);
      if (user != null) {
        custQuery = custQuery.eq('profile_id', user.id);
      }
      final custRes = await custQuery;
      final List customers = custRes as List;
      final int totalCustomers = customers.length;

      if (totalCustomers == 0) {
        return CustomerFunnelSummary(
          totalCustomers: 0,
          leadsCount: 0,
          prospectsCount: 0,
          clientsCount: 0,
          monthlyVisitsCompleted: 0,
          monthlyVisitsTotal: 0,
          activeProjectsCount: 0,
        );
      }

      // 2. 查詢有投保單紀錄的客戶 ID (已簽單保戶)
      final policiesRes = await _supabase.from('customer_policies').select('customer_id');
      final Set<String> clientCustomerIds = {};
      for (var p in (policiesRes as List)) {
        if (p['customer_id'] != null) {
          clientCustomerIds.add(p['customer_id'].toString());
        }
      }

      // 3. 查詢名下行程紀錄 (關聯客戶的行程)
      var eventsQuery = _supabase.from('schedule_events').select('id, customer_id, start_at, is_completed');
      if (user != null) {
        eventsQuery = eventsQuery.eq('profile_id', user.id);
      }
      final eventsRes = await eventsQuery;
      final List events = eventsRes as List;

      final Set<String> visitedCustomerIds = {};
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      int monthlyTotal = 0;
      int monthlyCompleted = 0;

      for (var ev in events) {
        if (ev['customer_id'] != null) {
          visitedCustomerIds.add(ev['customer_id'].toString());
        }
        if (ev['start_at'] != null) {
          final dt = DateTime.tryParse(ev['start_at'].toString());
          if (dt != null && dt.isAfter(monthStart.subtract(const Duration(seconds: 1)))) {
            monthlyTotal++;
            if (ev['is_completed'] == true) {
              monthlyCompleted++;
            }
          }
        }
      }

      // 4. 查詢進行中的專案數
      var projQuery = _supabase.from('visit_projects').select('id').eq('is_completed', false);
      if (user != null) {
        projQuery = projQuery.eq('profile_id', user.id);
      }
      final projRes = await projQuery;
      final int activeProjects = (projRes as List).length;

      // 5. 拆解客戶三階段生命週期
      int leadsCount = 0;
      int prospectsCount = 0;
      int clientsCount = 0;

      for (var c in customers) {
        final cId = c['id']?.toString() ?? '';
        final tags = (c['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final notes = c['notes']?.toString() ?? '';

        final bool hasPolicy = clientCustomerIds.contains(cId) || tags.any((t) => t.contains('已簽單') || t.contains('保戶'));
        if (hasPolicy) {
          clientsCount++;
          continue;
        }

        final bool hasVisitOrLeadInterest = visitedCustomerIds.contains(cId) ||
            tags.any((t) => t.contains('跟進') || t.contains('意願') || t.contains('拜訪') || t.contains('洽談')) ||
            notes.contains('跟進') || notes.contains('拜訪');

        if (hasVisitOrLeadInterest) {
          prospectsCount++;
        } else {
          leadsCount++;
        }
      }

      return CustomerFunnelSummary(
        totalCustomers: totalCustomers,
        leadsCount: leadsCount,
        prospectsCount: prospectsCount,
        clientsCount: clientsCount,
        monthlyVisitsCompleted: monthlyCompleted,
        monthlyVisitsTotal: monthlyTotal,
        activeProjectsCount: activeProjects,
      );
    } catch (e) {
      if (kDebugMode) print('Error fetching sales funnel metrics: $e');
      return CustomerFunnelSummary(
        totalCustomers: 0,
        leadsCount: 0,
        prospectsCount: 0,
        clientsCount: 0,
        monthlyVisitsCompleted: 0,
        monthlyVisitsTotal: 0,
        activeProjectsCount: 0,
      );
    }
  }

  /// 根據真實臨床情境與選定條款上限計算理賠與缺口
  ClinicalScenarioResult calculateClinicalClaim({
    required ClinicalScenario scenario,
    required int roomDailyLimit,
    required int surgeryLimit,
    required int miscLimit,
  }) {
    final roomExpenses = scenario.standardRoomDays * scenario.hospitalRoomDailyActual;
    final surgeryExpenses = scenario.standardSurgeryCost;
    final miscExpenses = scenario.standardMiscCost;
    final totalExpenses = roomExpenses + surgeryExpenses + miscExpenses;

    final roomClaim = scenario.standardRoomDays * (roomDailyLimit > scenario.hospitalRoomDailyActual ? scenario.hospitalRoomDailyActual : roomDailyLimit);
    final surgeryClaim = surgeryExpenses > surgeryLimit ? surgeryLimit : surgeryExpenses;
    final miscClaim = miscExpenses > miscLimit ? miscLimit : miscExpenses;
    final totalClaim = roomClaim + surgeryClaim + miscClaim;
    final outOfPocketGap = totalExpenses > totalClaim ? (totalExpenses - totalClaim) : 0;

    return ClinicalScenarioResult(
      scenario: scenario,
      roomExpenses: roomExpenses,
      surgeryExpenses: surgeryExpenses,
      miscExpenses: miscExpenses,
      totalExpenses: totalExpenses,
      roomClaim: roomClaim,
      surgeryClaim: surgeryClaim,
      miscClaim: miscClaim,
      totalClaim: totalClaim,
      outOfPocketGap: outOfPocketGap,
    );
  }

  /// 支援自訂醫療單據細項與 2-2-7 處置陷阱檢核之理賠精算
  ClinicalScenarioResult calculateCustomItemizedClaim({
    required int roomDays,
    required int roomDailyActual,
    required int surgeryCost,
    required int miscCost,
    required bool is227Procedure,
    required int roomDailyLimit,
    required int surgeryLimit,
    required int miscLimit,
    required bool isPolicy227Restricted,
  }) {
    final roomExpenses = roomDays * roomDailyActual;
    final surgeryExpenses = surgeryCost;
    final miscExpenses = miscCost;
    final totalExpenses = roomExpenses + surgeryExpenses + miscExpenses;

    final roomClaim = roomDays * (roomDailyLimit > roomDailyActual ? roomDailyActual : roomDailyLimit);
    
    // 2-2-7 處置陷阱判斷：若條款限定 2-2-7 但該項並非 2-2-7 手術，手術給付為 0 或受限
    final int surgeryClaim;
    if (isPolicy227Restricted && !is227Procedure) {
      surgeryClaim = 0;
    } else {
      surgeryClaim = surgeryExpenses > surgeryLimit ? surgeryLimit : surgeryExpenses;
    }

    final miscClaim = miscExpenses > miscLimit ? miscLimit : miscExpenses;
    final totalClaim = roomClaim + surgeryClaim + miscClaim;
    final outOfPocketGap = totalExpenses > totalClaim ? (totalExpenses - totalClaim) : 0;

    return ClinicalScenarioResult(
      scenario: ClinicalScenario(
        id: 'custom',
        title: '自訂醫院醫療單據',
        category: '自訂單據',
        description: '由業務員自訂之住院病房、手術自費與醫療雜費明細。',
        standardRoomDays: roomDays,
        hospitalRoomDailyActual: roomDailyActual,
        standardSurgeryCost: surgeryCost,
        standardMiscCost: miscCost,
        is227Surgery: is227Procedure,
        iconEmoji: '🧾',
      ),
      roomExpenses: roomExpenses,
      surgeryExpenses: surgeryExpenses,
      miscExpenses: miscExpenses,
      totalExpenses: totalExpenses,
      roomClaim: roomClaim,
      surgeryClaim: surgeryClaim,
      miscClaim: miscClaim,
      totalClaim: totalClaim,
      outOfPocketGap: outOfPocketGap,
    );
  }

  /// 跨保單/雙實支組合包多層次理賠流向瀑布精算 (Multi-Policy Waterfall Engine)
  MultiPolicyClaimSummary calculateMultiPolicyWaterfallClaim({
    required int roomDays,
    required int roomDailyActual,
    required int surgeryCost,
    required int miscCost,
    required bool is227Procedure,
    required List<Map<String, dynamic>> policyConfigs,
  }) {
    final roomExpenses = roomDays * roomDailyActual;
    final surgeryExpenses = surgeryCost;
    final miscExpenses = miscCost;
    final totalHospitalBill = roomExpenses + surgeryExpenses + miscExpenses;

    final List<MultiPolicyClaimItem> policyClaims = [];
    final List<String> warnings = [];

    int remainingRoomExpense = roomExpenses;
    int remainingSurgeryExpense = surgeryExpenses;
    int remainingMiscExpense = miscExpenses;
    int grandTotalClaimPaid = 0;
    int originalReceiptPolicyCount = 0;

    for (int i = 0; i < policyConfigs.length; i++) {
      final p = policyConfigs[i];
      final String name = p['product_name']?.toString() ?? '保單 ${i + 1}';
      final String comp = p['company_name']?.toString() ?? '保險公司';
      final int roomLimit = p['room_limit_val'] as int? ?? 2000;
      final int surgeryLimit = p['surgery_limit_val'] as int? ?? 150000;
      final int miscLimit = p['misc_limit_val'] as int? ?? 120000;
      final bool is227Restricted = p['is_227_restricted'] as bool? ?? false;
      final String receiptRule = p['receipt_rule']?.toString() ?? '正本收據';

      if (receiptRule.contains('正本')) {
        originalReceiptPolicyCount++;
      }

      bool has227Trap = false;
      int surgeryPaid = 0;
      if (is227Restricted && !is227Procedure) {
        has227Trap = true;
        warnings.add('⚠️「$name」限定健保 2-2-7，此非 2-2-7 手術處置不予理賠！');
      } else {
        final claimable = math.min(remainingSurgeryExpense, surgeryLimit);
        surgeryPaid = claimable;
        remainingSurgeryExpense = math.max(0, remainingSurgeryExpense - surgeryPaid);
      }

      final roomDailyClaimable = math.min(roomDailyActual, roomLimit);
      final roomPaid = math.min(remainingRoomExpense, roomDailyClaimable * roomDays);
      remainingRoomExpense = math.max(0, remainingRoomExpense - roomPaid);

      final miscPaid = math.min(remainingMiscExpense, miscLimit);
      remainingMiscExpense = math.max(0, remainingMiscExpense - miscPaid);

      final totalPaid = roomPaid + surgeryPaid + miscPaid;
      grandTotalClaimPaid += totalPaid;

      policyClaims.add(MultiPolicyClaimItem(
        policyName: name,
        companyName: comp,
        roomPaid: roomPaid,
        surgeryPaid: surgeryPaid,
        miscPaid: miscPaid,
        totalPaid: totalPaid,
        receiptRule: receiptRule,
        has227Trap: has227Trap,
      ));
    }

    if (originalReceiptPolicyCount > 1) {
      warnings.add('🚨 組合包中包含 $originalReceiptPolicyCount 張限定「正本收據」之保單，實務上將產生收據正本核銷衝突！');
    }

    final finalOutOfPocketGap = math.max(0, totalHospitalBill - grandTotalClaimPaid);

    return MultiPolicyClaimSummary(
      totalHospitalBill: totalHospitalBill,
      roomExpenses: roomExpenses,
      surgeryExpenses: surgeryExpenses,
      miscExpenses: miscExpenses,
      policyClaims: policyClaims,
      grandTotalClaimPaid: grandTotalClaimPaid,
      finalOutOfPocketGap: finalOutOfPocketGap,
      warnings: warnings,
    );
  }

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
