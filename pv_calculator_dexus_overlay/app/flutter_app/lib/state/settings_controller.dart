import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Languages the app ships translations for. The `null` entry on
/// [SettingsController.locale] means "follow the system locale";
/// MaterialApp resolves to the closest supported translation, falling
/// back to German (the template language).
const List<Locale> kSupportedLocales = [
  Locale('de'),
  Locale('en'),
  Locale('fr'),
  Locale('es'),
];

/// Holds user-facing app preferences (theme mode, language) and persists
/// them via [SharedPreferences].
///
/// Writes are fire-and-forget: the in-memory value updates and listeners
/// are notified immediately, so the UI flips before the async `setString`
/// completes. A failed write leaves the in-memory choice in effect for
/// the session.
class SettingsController extends ChangeNotifier {
  SettingsController({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const String themeModeKey = 'pv_theme_mode';
  static const String localeKey = 'pv_locale';

  final SharedPreferences? _prefsOverride;

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;

  /// `null` means "follow the system locale". Otherwise one of
  /// [kSupportedLocales].
  Locale? get locale => _locale;

  /// `true` once [load] has read the persisted preferences.
  bool get loaded => _loaded;

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  /// Reads persisted preferences. Safe to call multiple times.
  Future<void> load() async {
    final prefs = await _prefs();
    final rawTheme = prefs.getString(themeModeKey);
    _themeMode = _decodeTheme(rawTheme) ?? ThemeMode.system;
    final rawLocale = prefs.getString(localeKey);
    _locale = _decodeLocale(rawLocale);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await _prefs();
    await prefs.setString(themeModeKey, _encodeTheme(mode));
  }

  /// Pass `null` to follow the system locale.
  Future<void> setLocale(Locale? locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await _prefs();
    if (locale == null) {
      await prefs.remove(localeKey);
    } else {
      await prefs.setString(localeKey, locale.languageCode);
    }
  }

  static ThemeMode? _decodeTheme(String? raw) {
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

  static String _encodeTheme(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  /// Returns `null` when [raw] is empty, missing, or names a language
  /// the app doesn't ship translations for — treated as "follow system".
  static Locale? _decodeLocale(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final l in kSupportedLocales) {
      if (l.languageCode == raw) return l;
    }
    return null;
  }
}
