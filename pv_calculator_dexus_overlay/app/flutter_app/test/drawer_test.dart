import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/main.dart';
import 'package:pv_calculator_app/widgets/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('drawer opens settings page from the project list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PvCalculatorApp());
    await tester.pumpAndSettle();

    final scaffoldFinder = find.byType(Scaffold).first;
    final ScaffoldState scaffoldState = tester.state(scaffoldFinder);
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('drawer-settings')), findsOneWidget);

    await tester.tap(find.byKey(const Key('drawer-settings')));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Erscheinungsbild'), findsOneWidget);
  });
}
