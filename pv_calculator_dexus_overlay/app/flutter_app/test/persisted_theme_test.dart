import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/main.dart';
import 'package:pv_calculator_app/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers the integration path that was previously unverified: a value
/// persisted under [SettingsController.themeModeKey] / [localeKey] must
/// reach [MaterialApp.themeMode] / [MaterialApp.locale] after the app
/// constructs and the async load completes.
void main() {
  testWidgets('persisted dark theme drives MaterialApp.themeMode at startup', (tester) async {
    SharedPreferences.setMockInitialValues({
      SettingsController.themeModeKey: 'dark',
    });

    await tester.pumpWidget(const PvCalculatorApp());
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
  });

  testWidgets('persisted locale drives MaterialApp.locale at startup', (tester) async {
    SharedPreferences.setMockInitialValues({
      SettingsController.localeKey: 'es',
    });

    await tester.pumpWidget(const PvCalculatorApp());
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.locale, const Locale('es'));
  });

  testWidgets('empty store leaves MaterialApp at system defaults', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const PvCalculatorApp());
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.system);
    expect(materialApp.locale, isNull);
  });
}
