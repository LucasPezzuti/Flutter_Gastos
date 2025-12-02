// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/services/theme_service.dart';

void main() {
  testWidgets('App loads dashboard screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    final themeService = ThemeService();
    await tester.pumpWidget(ExpenseTrackerApp(themeService: themeService));

    // Wait for the widget to be built
    await tester.pump();

    // Verify that the dashboard screen loads with the app title
    expect(find.text('GastoTorta'), findsOneWidget);
    
    // Verify that the floating action button is present
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
