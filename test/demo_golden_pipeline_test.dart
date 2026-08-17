import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart';
import 'package:insurance_helper/screens/home_screen.dart';
import 'package:insurance_helper/screens/customer_management_tab.dart';
import 'package:insurance_helper/services/customer_policy_service.dart';
import 'package:insurance_helper/services/tag_categorizer.dart';
import 'package:insurance_helper/widgets/categorized_tag_accordion_selector.dart';
import 'package:insurance_helper/widgets/voice_recorder_widget.dart';

void main() {
  group('專題 Demo 核心流程黃金閉環 (Golden Pipeline E2E Test)', () {
    testWidgets('Step 1 -> Step 2 -> Step 3: 登入跳過 -> 客戶管理新增打標 -> 語音排程入口驗證', (WidgetTester tester) async {
      isOfflineMode = true;
      offlineReason = 'Demo 測試驗收環境';

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. 啟動 App (Step 1: 登入頁)
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('insurance_helper'), findsOneWidget);
      expect(find.text('業務員登入'), findsOneWidget);

      // 點擊「直接跳過登入」進入 HomeScreen
      final Finder skipBtn = find.text('直接跳過登入');
      expect(skipBtn, findsOneWidget);
      await tester.tap(skipBtn);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 500));

      // 驗證首頁已載入
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('今日行程'), findsWidgets);

      // 2. 導航至客戶管理 (Step 2: 客戶管理與打標)
      final Finder customerMenu = find.text('客戶管理');
      expect(customerMenu, findsWidgets);
      await tester.tap(customerMenu.first);
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.byType(CustomerManagementTab), findsOneWidget);

      // 開啟新增客戶對話框
      final Finder addCustomerBtn = find.text('新增客戶');
      expect(addCustomerBtn, findsOneWidget);
      await tester.tap(addCustomerBtn);
      await tester.pump(const Duration(milliseconds: 1000));

      // 驗證對話框必備元件：輸入框、分類風琴標籤選取器、語音錄音備註列
      expect(find.byType(TextField), findsWidgets);
      expect(find.byType(CategorizedTagAccordionSelector), findsOneWidget);
      expect(find.byType(VoiceRecorderWidget), findsOneWidget);

      // 關閉新增對話框
      final Finder cancelBtn = find.text('取消');
      if (cancelBtn.evaluate().isNotEmpty) {
        await tester.tap(cancelBtn.first);
        await tester.pump(const Duration(milliseconds: 500));
      }

      // 3. 驗證 Step 3: 今日行程語音智慧排程 FAB 與入口
      final Finder calendarMenu = find.text('今日行程');
      if (calendarMenu.evaluate().isNotEmpty) {
        await tester.tap(calendarMenu.first);
        await tester.pump(const Duration(milliseconds: 1000));
      }
      expect(find.byIcon(Icons.mic), findsWidgets);

      // 清除 Toast pending timers
      await tester.pump(const Duration(seconds: 4));
    });

    test('Step 4: 0 成本保單健檢精算與保障缺口秒算測試', () {
      final List<CustomerEnrolledPolicy> samplePolicies = [
        CustomerEnrolledPolicy(
          id: 'CP-01',
          customerId: 'cust_01',
          policyClauseId: 'PC-01',
          productName: '超安心醫療保險',
          companyName: '國泰人壽',
          category: '實支實付醫療險',
          roomLimit: '2,500 元/日',
          surgeryLimit: '150,000 元',
          miscLimit: '200,000 元',
          roomDailyValue: 2500,
          surgeryMaxValue: 150000,
          miscMaxValue: 200000,
          rawPdfUrl: 'https://example.com',
          enrolledAt: DateTime.now(),
        ),
        CustomerEnrolledPolicy(
          id: 'CP-02',
          customerId: 'cust_01',
          policyClauseId: 'PC-02',
          productName: '愛常在重大傷病定期健康保險',
          companyName: '富邦人壽',
          category: '重大傷病險',
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
      final summary = service.calculateCustomerBenefitSummary(samplePolicies);

      expect(summary.totalRoomDaily, equals(2500));
      expect(summary.totalSurgeryMax, equals(150000));
      expect(summary.totalMiscMax, equals(200000));
      expect(summary.totalCancerCriticalMax, equals(1000000)); // Default benchmark value for critical illness
      expect(summary.roomGap, equals(1000)); // 3500 - 2500 = 1000

      // 檢查缺口分析結果包含建議
      expect(summary.detectedGaps, isNotEmpty);
    });

    test('標籤色彩與多分類映射解析度測試', () {
      TagCategorizer.registerCustomColor('重要VIP', '#10B981');
      final style = TagCategorizer.getStyle('重要VIP', true);
      expect(style.categoryName, equals('自訂標籤'));

      final healthStyle = TagCategorizer.getStyle('高血壓', true);
      expect(healthStyle.categoryName, equals('健康與體況'));
    });
  });
}
