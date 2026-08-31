import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/customer_policy_service.dart';
import 'package:insurance_helper/services/policy_crawler_service.dart';

void main() {
  group('CustomerFunnelSummary Tests', () {
    test('Calculates monthly visit rate properly', () {
      final summary = CustomerFunnelSummary(
        totalCustomers: 27,
        leadsCount: 12,
        prospectsCount: 12,
        clientsCount: 3,
        monthlyVisitsCompleted: 8,
        monthlyVisitsTotal: 10,
        activeProjectsCount: 3,
      );

      expect(summary.totalCustomers, 27);
      expect(summary.leadsCount, 12);
      expect(summary.prospectsCount, 12);
      expect(summary.clientsCount, 3);
      expect(summary.monthlyVisitsCompleted, 8);
      expect(summary.monthlyVisitsTotal, 10);
      expect(summary.monthlyVisitRate, 0.8);
      expect(summary.activeProjectsCount, 3);
    });

    test('Zero total visits does not divide by zero', () {
      final summary = CustomerFunnelSummary(
        totalCustomers: 0,
        leadsCount: 0,
        prospectsCount: 0,
        clientsCount: 0,
        monthlyVisitsCompleted: 0,
        monthlyVisitsTotal: 0,
        activeProjectsCount: 0,
      );

      expect(summary.monthlyVisitRate, 0.0);
    });
  });

  group('Clinical Scenario Claim Engine Tests', () {
    final service = CustomerPolicyService();

    test('6 standard clinical scenarios are initialized properly', () {
      expect(CustomerPolicyService.clinicalScenarios.length, 6);
      final davinci = CustomerPolicyService.clinicalScenarios.firstWhere((s) => s.id == 'davinci');
      expect(davinci.title, '達文西機器人手臂微創手術');
      expect(davinci.totalExpenses, (4 * 3500) + 220000 + 80000); // 14,000 + 220,000 + 80,000 = 314,000
    });

    test('Calculates claim and out-of-pocket gap accurately for Da Vinci surgery', () {
      final davinci = CustomerPolicyService.clinicalScenarios.firstWhere((s) => s.id == 'davinci');
      
      // Policy limits: Room 2000/day, Surgery 150,000, Misc 120,000
      final result = service.calculateClinicalClaim(
        scenario: davinci,
        roomDailyLimit: 2000,
        surgeryLimit: 150000,
        miscLimit: 120000,
      );

      // Expenses
      expect(result.roomExpenses, 4 * 3500); // 14,000
      expect(result.surgeryExpenses, 220000);
      expect(result.miscExpenses, 80000);
      expect(result.totalExpenses, 314000);

      // Claim payments
      expect(result.roomClaim, 4 * 2000); // 8,000 (limited to 2,000/day)
      expect(result.surgeryClaim, 150000); // 150,000 (capped at 150,000)
      expect(result.miscClaim, 80000); // 80,000 (below limit of 120,000)
      expect(result.totalClaim, 8000 + 150000 + 80000); // 238,000

      // Out of pocket gap
      expect(result.outOfPocketGap, 314000 - 238000); // 76,000 gap
    });

    test('Zero out-of-pocket gap when policy fully covers expenses', () {
      final appendicitis = CustomerPolicyService.clinicalScenarios.firstWhere((s) => s.id == 'appendicitis');
      
      // High-tier policy limits: Room 3000/day, Surgery 200,000, Misc 200,000
      final result = service.calculateClinicalClaim(
        scenario: appendicitis,
        roomDailyLimit: 3000,
        surgeryLimit: 200000,
        miscLimit: 200000,
      );

      expect(result.outOfPocketGap, 0);
    });
  });

  group('PolicyClauseItem Model Tests', () {
    test('fromJson parses live database clause data correctly', () {
      final json = {
        'id': 'pc-1234-uuid',
        'product_name': '安心住院醫療終身保險',
        'company_name': '富邦人壽',
        'category': '實支實付醫療險',
        'waiting_days': '疾病等待期 30 日',
        'tags': ['概括式條款', '健保 2-2-7 手術給付'],
        'room_limit': '2,500 元/日',
        'surgery_limit': '180,000 元',
        'misc_limit': '150,000 元',
        'raw_pdf_url': 'https://example.com/policy.pdf',
        'benefits_json': {'room_daily': 2500, 'surgery_max': 180000},
        'crawled_at': '2026-08-31T12:00:00Z',
      };

      final item = PolicyClauseItem.fromJson(json);
      expect(item.id, 'pc-1234-uuid');
      expect(item.productName, '安心住院醫療終身保險');
      expect(item.companyName, '富邦人壽');
      expect(item.category, '實支實付醫療險');
      expect(item.roomLimit, '2,500 元/日');
      expect(item.surgeryLimit, '180,000 元');
      expect(item.miscLimit, '150,000 元');
      expect(item.rawPdfUrl, 'https://example.com/policy.pdf');
    });
  });

  group('Policy Category Filter Expansion Tests', () {
    test('expands UI short category labels to real database category strings', () {
      expect(PolicyCrawlerService.expandCategoryFilter('手術險'), contains('手術醫療終身險'));
      expect(PolicyCrawlerService.expandCategoryFilter('日額型醫療險'), contains('日額型住院醫療險'));
      expect(PolicyCrawlerService.expandCategoryFilter('癌症險'), containsAll(['癌症險', '癌症一次給付金險', '癌症住院療程險']));
      expect(PolicyCrawlerService.expandCategoryFilter('重大傷病險'), containsAll(['重大傷病險', '特定傷病險']));
      expect(PolicyCrawlerService.expandCategoryFilter('長照險 / 失能險'), containsAll(['長照險 / 失能險', '巴氏量表長照險', '失能扶助險']));
      expect(PolicyCrawlerService.expandCategoryFilter('定期壽險'), containsAll(['定期壽險', '房貸壽險', '微型照顧保單']));
      expect(PolicyCrawlerService.expandCategoryFilter('汽機車責任與超額險'), containsAll(['汽機車強制險與責任險', '超額責任與防禦險']));
    });
  });

  group('Custom Itemized Claim & 2-2-7 Trap Tests', () {
    final service = CustomerPolicyService();

    test('Identifies 2-2-7 trap when surgery is a procedure and policy is restricted', () {
      final result = service.calculateCustomItemizedClaim(
        roomDays: 3,
        roomDailyActual: 3000,
        surgeryCost: 80000,
        miscCost: 50000,
        is227Procedure: false, // Not a 2-2-7 surgery
        roomDailyLimit: 2000,
        surgeryLimit: 100000,
        miscLimit: 80000,
        isPolicy227Restricted: true, // Policy is restricted to 2-2-7
      );

      // Surgery claim should be 0 due to 2-2-7 restriction
      expect(result.surgeryClaim, 0);
      expect(result.roomClaim, 3 * 2000); // 6,000
      expect(result.miscClaim, 50000);
      expect(result.totalClaim, 56000);
      expect(result.totalExpenses, (3 * 3000) + 80000 + 50000); // 139,000
      expect(result.outOfPocketGap, 139000 - 56000); // 83,000 gap
    });
  });

  group('Multi-Policy Waterfall Claim Tests', () {
    final service = CustomerPolicyService();

    test('Calculates multi-policy double-reimbursement waterfall accurately', () {
      final summary = service.calculateMultiPolicyWaterfallClaim(
        roomDays: 4,
        roomDailyActual: 3500, // Total room 14,000
        surgeryCost: 220000,
        miscCost: 80000,
        is227Procedure: true,
        policyConfigs: [
          {
            'product_name': '實支實付 A (正本)',
            'company_name': '富邦人壽',
            'room_limit_val': 2000, // Pays 8,000
            'surgery_limit_val': 150000, // Pays 150,000
            'misc_limit_val': 50000, // Pays 50,000
            'is_227_restricted': false,
            'receipt_rule': '正本收據',
          },
          {
            'product_name': '實支實付 B (副本)',
            'company_name': '全球人壽',
            'room_limit_val': 2000, // Covers remaining 6,000
            'surgery_limit_val': 100000, // Covers remaining 70,000
            'misc_limit_val': 50000, // Covers remaining 30,000
            'is_227_restricted': false,
            'receipt_rule': '副本收據',
          },
        ],
      );

      expect(summary.totalHospitalBill, (4 * 3500) + 220000 + 80000); // 314,000
      expect(summary.policyClaims.length, 2);
      
      // Policy A paid: 8,000 + 150,000 + 50,000 = 208,000
      expect(summary.policyClaims[0].totalPaid, 208000);
      
      // Policy B paid remaining: 6,000 + 70,000 + 30,000 = 106,000
      expect(summary.policyClaims[1].totalPaid, 106000);

      // Grand total paid: 208,000 + 106,000 = 314,000
      expect(summary.grandTotalClaimPaid, 314000);
      expect(summary.finalOutOfPocketGap, 0); // 100% fully covered!
    });
  });
}
