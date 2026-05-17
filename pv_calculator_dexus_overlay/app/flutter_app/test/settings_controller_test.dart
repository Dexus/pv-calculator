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

  test('a setThemeMode that beats a slow load() is not overwritten', () async {
    // Reproduces the race the reviewer flagged: persisted value differs
    // from the user's in-flight choice. The fix guarantees user wins.
    SharedPreferences.setMockInitialValues({
      SettingsController.themeModeKey: 'dark',
    });
    final prefs = await SharedPreferences.getInstance();
    final controller = SettingsController(prefs: prefs);

    // Kick off load without awaiting, then immediately set the
    // opposite value as if the user tapped before load completed.
    final loadFuture = controller.load();
    await controller.setThemeMode(ThemeMode.light);
    await loadFuture;

    expect(controller.themeMode, ThemeMode.light,
        reason: 'User choice must win over a late-arriving load.');
  });

  test('setLocale persists the choice and decodes back on reload', () async {
    final prefs = await SharedPreferences.getInstance();
    final controller = SettingsController(prefs: prefs);
    await controller.load();

    await controller.setLocale(const Locale('fr'));
    expect(controller.locale, const Locale('fr'));
    expect(prefs.getString(SettingsController.localeKey), 'fr');

    await controller.setLocale(null);
    expect(controller.locale, isNull);
    expect(prefs.getString(SettingsController.localeKey), isNull);
  });

  test('setLocale normalises unsupported locales to null', () async {
    final prefs = await SharedPreferences.getInstance();
    final controller = SettingsController(prefs: prefs);
    await controller.load();

    // A locale outside kSupportedLocales must not reach MaterialApp;
    // it would leave the picker with no matching radio option.
    await controller.setLocale(const Locale('pt'));
    expect(controller.locale, isNull);
    expect(prefs.getString(SettingsController.localeKey), isNull);
  });

  test('load ignores a persisted locale outside kSupportedLocales', () async {
    SharedPreferences.setMockInitialValues({
      SettingsController.localeKey: 'zh',
    });
    final prefs = await SharedPreferences.getInstance();
    final controller = SettingsController(prefs: prefs);
    await controller.load();

    expect(controller.locale, isNull,
        reason: 'Unknown persisted languages must fall back to "follow system".');
  });
}
