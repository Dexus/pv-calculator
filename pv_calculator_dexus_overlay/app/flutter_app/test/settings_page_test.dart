import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/state/settings_controller.dart';
import 'package:pv_calculator_app/widgets/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsController> _freshController() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = SettingsController(prefs: prefs);
  await controller.load();
  return controller;
}

Widget _host(SettingsController controller) {
  return ChangeNotifierProvider<SettingsController>.value(
    value: controller,
    child: const MaterialApp(home: SettingsPage()),
  );
}

void main() {
  testWidgets('selecting dark mode updates the controller', (tester) async {
    final controller = await _freshController();

    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();

    expect(controller.themeMode, ThemeMode.system);

    await tester.tap(find.byKey(const Key('theme-mode-dark')));
    await tester.pumpAndSettle();

    expect(controller.themeMode, ThemeMode.dark);
  });

  testWidgets('selecting light mode updates the controller', (tester) async {
    final controller = await _freshController();

    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('theme-mode-light')));
    await tester.pumpAndSettle();

    expect(controller.themeMode, ThemeMode.light);
  });
}
