import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart';
import 'package:insurance_helper/screens/home_screen.dart';
import 'package:insurance_helper/screens/customer_management_tab.dart';

void main() {
  testWidgets('App loads LoginScreen in offline preview mode', (WidgetTester tester) async {
    isOfflineMode = true;
    offlineReason = '測試環境';

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('insurance_helper'), findsOneWidget);
    expect(find.text('業務員登入'), findsOneWidget);
  });

  testWidgets('HomeScreen sidebar navigation and Customer Tab CRUD offline tests', (WidgetTester tester) async {
    isOfflineMode = true;
    offlineReason = '測試環境';

    // 1. Render HomeScreen directly
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify top week strip calendar is visible under "今日行程"
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('2026年7月'), findsOneWidget);

    // 2. Navigate to "客戶管理"
    // Since width defaults to a smaller size in tester, the drawer burger button should be visible.
    // Let's open drawer first.
    final Finder drawerFinder = find.byType(Drawer);
    if (drawerFinder.evaluate().isEmpty) {
      // If drawer is closed, find drawer icon/button and tap it
      final Finder iconButtonFinder = find.byIcon(Icons.menu);
      if (iconButtonFinder.evaluate().isNotEmpty) {
        await tester.tap(iconButtonFinder);
        await tester.pumpAndSettle();
      }
    }

    // Find and tap "客戶管理" item
    final Finder customerMenuItem = find.text('客戶管理');
    expect(customerMenuItem, findsOneWidget);
    await tester.tap(customerMenuItem);
    await tester.pumpAndSettle();

    // Verify top week strip calendar is HIDDEN (UX Optimization)
    expect(find.text('2026年7月'), findsNothing);

    // Verify Customer tab components are loaded
    expect(find.byType(CustomerManagementTab), findsOneWidget);
    expect(find.text('林君雅'), findsOneWidget); // Initial mock data
    expect(find.text('王小明'), findsOneWidget);
    expect(find.text('陳美玲'), findsOneWidget);

    // 3. Search customer
    await tester.enterText(find.byType(TextField).first, '王小明');
    await tester.pumpAndSettle();
    expect(find.text('林君雅'), findsNothing);
    expect(find.widgetWithText(Card, '王小明'), findsOneWidget);

    // Clear search
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    expect(find.text('林君雅'), findsOneWidget);

    // 4. Test Add Customer Dialog
    final Finder addBtn = find.text('新增客戶');
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // Dialog title check
    expect(find.text('新增客戶檔案'), findsOneWidget);

    // Fill form
    await tester.enterText(find.widgetWithText(TextField, '客戶姓名 (必填)'), '張大千');
    await tester.enterText(find.widgetWithText(TextField, '電話號碼'), '0999-111222');
    await tester.enterText(find.widgetWithText(TextField, 'Email 信箱'), 'daqian.zhang@gmail.com');
    await tester.enterText(find.widgetWithText(TextField, '標籤 (逗號區隔)'), '水墨畫, 高淨值');
    await tester.enterText(find.widgetWithText(TextField, '備註紀錄'), '重要客戶');

    // Click Save
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    // Verify new customer added to list
    expect(find.text('張大千'), findsOneWidget);
    expect(find.text('0999-111222'), findsOneWidget);
    expect(find.text('水墨畫'), findsOneWidget);
  });
}
