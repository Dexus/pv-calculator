import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to ThemeMode.system on an empty store', () async {
    final prefs = await SharedPreferences.getInstance();
    final controller = SettingsController(prefs: prefs);
    await controller.load();

    expect(controller.themeMode, ThemeMode.system);
    expect(controller.loaded, isTrue);
  });

  test('setThemeMode persists the choice and notifies listeners', () async {
    final prefs = await SharedPreferences.getInstance();
    final controller = SettingsController(prefs: prefs);
    await controller.load();

    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setThemeMode(ThemeMode.dark);
    expect(controller.themeMode, ThemeMode.dark);
    expect(notifications, 1);
    expect(prefs.getString(SettingsController.themeModeKey), 'dark');

    // Re-creating from the same prefs picks up the persisted value.
    final reloaded = SettingsController(prefs: prefs);
    await reloaded.load();
    expect(reloaded.themeMode, ThemeMode.dark);
  });

  test('setThemeMode is a no-op when the value is unchanged', () async {
    final prefs = await SharedPreferences.getInstance();
    final controller = SettingsController(prefs: prefs);
    await controller.load();

    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setThemeMode(ThemeMode.system);
    expect(notifications, 0);
  });

  test('load tolerates an unknown persisted value by falling back to system', () async {
    SharedPreferences.setMockInitialValues({
      SettingsController.themeModeKey: 'sepia',
    });
    final prefs = await SharedPreferences.getInstance();
    final controller = SettingsController(prefs: prefs);
    await controller.load();

    expect(controller.themeMode, ThemeMode.system);
  });
}
