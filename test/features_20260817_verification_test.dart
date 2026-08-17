import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/customer_policy_service.dart';
import 'package:insurance_helper/services/policy_crawler_service.dart';
import 'package:insurance_helper/services/tag_categorizer.dart';

void main() {
  group('1. TagCategorizer Custom Color Priority Test', () {
    test('Custom HEX color overrides default fallback and preset colors', () {
      // Register custom tag color
      TagCategorizer.registerCustomColor('新光主力客戶', '#E11D48');
      TagCategorizer.registerCustomColor('重要VIP', '#10B981');

      expect(TagCategorizer.customTagColors['新光主力客戶'], '#E11D48');
      expect(TagCategorizer.customTagColors['重要vip'], '#10B981');

      final styleDark = TagCategorizer.getStyle('新光主力客戶', true);
      final styleLight = TagCategorizer.getStyle('新光主力客戶', false);

      expect(styleDark.categoryName, '自訂標籤');
      expect(styleLight.categoryName, '自訂標籤');
    });
  });

  group('2. CustomerPolicyService 0-Cost Actuarial Calculation Test', () {
    test('Correctly calculates 5 claim buckets and identifies gaps', () {
      final List<CustomerEnrolledPolicy> mockPolicies = [
        CustomerEnrolledPolicy(
          id: 'CP-01',
          customerId: 'cust_01',
          policyClauseId: 'PC-01',
          productName: '真順心終身醫療健康保險',
          companyName: '國泰人壽',
          category: '實支實付醫療險',
          roomLimit: '2,000 元/日',
          surgeryLimit: '50,000 元',
          miscLimit: '150,000 元',
          roomDailyValue: 2000,
          surgeryMaxValue: 50000,
          miscMaxValue: 150000,
          rawPdfUrl: 'https://example.com',
          enrolledAt: DateTime.now(),
        ),
        CustomerEnrolledPolicy(
          id: 'CP-02',
          customerId: 'cust_01',
          policyClauseId: 'PC-02',
          productName: '愛馨防癌終身健康保險',
          companyName: '富邦人壽',
          category: '防癌險',
          roomLimit: '0 元/日',
          surgeryLimit: '0 元',
          miscLimit: '0 元',
          roomDailyValue: 0,
          surgeryMaxValue: 0,
          miscMaxValue: 0,
          rawPdfUrl: 'https://example.com',
          enrolledAt: DateTime.now(),
        ),
        CustomerEnrolledPolicy(
          id: 'CP-03',
          customerId: 'cust_01',
          policyClauseId: 'PC-03',
          productName: '超額責任綜合保險',
          companyName: '富邦產物',
          category: '車險責任',
          roomLimit: '0 元/日',
          surgeryLimit: '0 元',
          miscLimit: '0 元',
          roomDailyValue: 0,
          surgeryMaxValue: 0,
          miscMaxValue: 0,
          rawPdfUrl: 'https://example.com',
          enrolledAt: DateTime.now(),
        ),
      ];

      final service = CustomerPolicyService();
      final summary = service.calculateCustomerBenefitSummary(mockPolicies);

      // Verify 5 buckets sum
      expect(summary.totalRoomDaily, 2000);
      expect(summary.totalSurgeryMax, 50000);
      expect(summary.totalMiscMax, 150000);
      expect(summary.totalCancerCriticalMax, 1000000); // Triggered by '防癌險'
      expect(summary.totalLiabilityMax, 10000000); // Triggered by '車險責任'

      // Verify gaps calculation against benchmarks
      expect(summary.roomGap, 1500); // 3500 - 2000 = 1500
      expect(summary.surgeryGap, 200000); // 250000 - 50000 = 200000
      expect(summary.miscGap, 50000); // 200000 - 150000 = 50000
      expect(summary.cancerGap, 0); // 1000000 >= 1000000
      expect(summary.liabilityGap, 0); // 10000000 >= 10000000

      expect(summary.hasCriticalGap, isTrue);
      expect(summary.detectedGaps.length, 3);
    });

    test('Cross-company Policy PK clause trap extraction', () {
      final service = CustomerPolicyService();

      final rawA = {
        'id': 'pk_1',
        'product_name': '安心住院甲型',
        'company_name': '國泰人壽',
        'category': '實支實付醫療險',
        'tags': ['限定手術 (2-2-7)', '列舉式條款', '需正本收據', '不含耗材'],
      };

      final rawB = {
        'id': 'pk_2',
        'product_name': '好安心乙型',
        'company_name': '全球人壽',
        'category': '實支實付醫療險',
        'tags': ['概括式條款', '副本收據可'],
      };

      final pkA = service.extractPolicyPkDetail(rawA);
      final pkB = service.extractPolicyPkDetail(rawB);

      // Verify PK A trap detection
      expect(pkA.is227Restricted, isTrue);
      expect(pkA.clauseType, contains('列舉式'));
      expect(pkA.receiptType, contains('正本'));
      expect(pkA.outpatientSurgeryMaterialCovered, isFalse);

      // Verify PK B advantageous terms
      expect(pkB.is227Restricted, isFalse);
      expect(pkB.clauseType, contains('概括式'));
      expect(pkB.receiptType, contains('副本'));
      expect(pkB.outpatientSurgeryMaterialCovered, isTrue);
    });
  });

  group('3. PolicyCrawlerService Static Company Directory Test', () {
    test('Contains exactly 20 life insurance companies and 26 PC/channel companies (Total 46)', () {
      expect(PolicyCrawlerService.lifeCompanies.length, 20);
      expect(PolicyCrawlerService.pcCompanies.length, 26);
      expect(PolicyCrawlerService.lifeCompanies.length + PolicyCrawlerService.pcCompanies.length, 46);

      // Verify specific sample companies exist
      expect(PolicyCrawlerService.lifeCompanies, contains('富邦人壽'));
      expect(PolicyCrawlerService.lifeCompanies, contains('國泰人壽'));
      expect(PolicyCrawlerService.lifeCompanies, contains('南山人壽'));

      expect(PolicyCrawlerService.pcCompanies, contains('富邦產物'));
      expect(PolicyCrawlerService.pcCompanies, contains('新光產物'));
      expect(PolicyCrawlerService.pcCompanies, contains('公勝保經專屬通路'));
    });
  });
}
