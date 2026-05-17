import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/state/settings_controller.dart';
import 'package:pv_calculator_app/widgets/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_test_localization.dart';

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
    child: germanMaterialApp(home: const SettingsPage()),
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

  testWidgets('selecting Spanish locale persists the choice', (tester) async {
    // The default 800x600 surface clips the language radios below the
    // theme block — give the page enough height that every radio is
    // hit-testable.
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final controller = await _freshController();

    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();

    expect(controller.locale, isNull);

    await tester.tap(find.byKey(const Key('locale-es')));
    await tester.pumpAndSettle();

    expect(controller.locale, const Locale('es'));

    // System option clears the override back to null.
    await tester.tap(find.byKey(const Key('locale-system')));
    await tester.pumpAndSettle();

    expect(controller.locale, isNull);
  });
}
