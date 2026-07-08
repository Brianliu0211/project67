// This is a basic Flutter widget test for MyApp.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/main.dart';

void main() {
  testWidgets('App loads LoginScreen in offline preview mode', (WidgetTester tester) async {
    // Set global flag to true for testing offline mode
    isOfflineMode = true;
    offlineReason = '測試環境';

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that LoginScreen is rendered by checking for the App title and buttons
    expect(find.text('insurance_helper'), findsOneWidget);
    expect(find.text('業務員登入'), findsOneWidget);
  });
}
