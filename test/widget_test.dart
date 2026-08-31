import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:insurance_helper/main.dart';
import 'package:insurance_helper/screens/home_screen.dart';
import 'package:insurance_helper/screens/customer_management_tab.dart';
import 'package:insurance_helper/widgets/categorized_tag_accordion_selector.dart';
import 'package:insurance_helper/widgets/voice_recorder_widget.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('App loads LoginScreen in offline preview mode', (WidgetTester tester) async {
    isOfflineMode = true;
    offlineReason = '測試環境';

    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('insurance_helper'), findsOneWidget);
    expect(find.text('業務員登入'), findsOneWidget);
  });

  testWidgets('HomeScreen sidebar navigation and Customer Tab UI offline tests', (WidgetTester tester) async {
    isOfflineMode = true;
    offlineReason = '測試環境';

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. Launch full App
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 500));

    // 2. Click "直接跳過登入" to navigate to HomeScreen
    final Finder skipLoginBtn = find.text('直接跳過登入');
    expect(skipLoginBtn, findsOneWidget);
    await tester.tap(skipLoginBtn);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // 3. Verify HomeScreen loaded
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('今日行程'), findsWidgets);

    // 4. Navigate to "客戶管理"
    final Finder customerMenuItem = find.text('客戶管理');
    expect(customerMenuItem, findsWidgets);
    await tester.tap(customerMenuItem.first);
    await tester.pump(const Duration(milliseconds: 1000));

    // 5. Verify Customer tab components are loaded
    expect(find.byType(CustomerManagementTab), findsOneWidget);

    // 6. Test Add Customer Dialog
    final Finder addBtn = find.text('新增客戶');
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pump(const Duration(milliseconds: 1000));

    // Verify dialog components exist
    expect(find.byType(TextField), findsWidgets);
    expect(find.byType(CategorizedTagAccordionSelector), findsOneWidget);
    expect(find.byType(VoiceRecorderWidget), findsOneWidget);

    // Close Dialog with cancel button
    final Finder cancelBtn = find.text('取消');
    if (cancelBtn.evaluate().isNotEmpty) {
      await tester.tap(cancelBtn.first);
      await tester.pump(const Duration(milliseconds: 500));
    }

    // Flush any pending Toast timers
    await tester.pump(const Duration(seconds: 4));
  });
}
