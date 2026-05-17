import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds user-facing app preferences (currently: theme mode) and persists
/// them via [SharedPreferences].
///
/// Theme writes are fire-and-forget: the in-memory value updates and
/// listeners are notified immediately, so the UI flips before the async
/// `setString` completes. A failed write leaves the in-memory choice in
/// effect for the session.
class SettingsController extends ChangeNotifier {
  SettingsController({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const String themeModeKey = 'pv_theme_mode';

  final SharedPreferences? _prefsOverride;

  ThemeMode _themeMode = ThemeMode.system;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;

  /// `true` once [load] has read the persisted preferences.
  bool get loaded => _loaded;

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  /// Reads persisted preferences. Safe to call multiple times.
  Future<void> load() async {
    final prefs = await _prefs();
    final raw = prefs.getString(themeModeKey);
    _themeMode = _decode(raw) ?? ThemeMode.system;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await _prefs();
    await prefs.setString(themeModeKey, _encode(mode));
  }

  static ThemeMode? _decode(String? raw) {
    switch (raw) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
    }
    return null;
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }
}
