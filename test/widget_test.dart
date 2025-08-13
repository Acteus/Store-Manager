// This is a basic Flutter widget test for POS Inventory System.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_inventory_system/main.dart';

void main() {
  testWidgets('POS Inventory App loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: POSInventoryApp()));

    // Verify that the app loads with the main navigation
    expect(find.text('POS & Inventory System'), findsOneWidget);

    // Verify that navigation items are present
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
  });
}
