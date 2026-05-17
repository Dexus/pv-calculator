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
/// Writes are best-effort: the in-memory value updates and listeners are
/// notified immediately, so the UI flips before the async `setString`
/// completes. Persistence errors are caught and logged; the in-memory
/// choice still applies for the rest of the session.
///
/// Race with [load]: if the user changes a setting before the initial
/// [load] completes, that user choice wins — load() will not overwrite
/// fields the user has already touched.
class SettingsController extends ChangeNotifier {
  SettingsController({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const String themeModeKey = 'pv_theme_mode';
  static const String localeKey = 'pv_locale';
  static const String expertModeKey = 'pv_expert_mode';

  final SharedPreferences? _prefsOverride;

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  bool _expertMode = false;
  bool _loaded = false;

  // Track per-field whether the user has explicitly set the value
  // during this session. load() respects these so a slow async read
  // can't clobber a user choice that landed first.
  bool _themeModeUserSet = false;
  bool _localeUserSet = false;
  bool _expertModeUserSet = false;

  ThemeMode get themeMode => _themeMode;

  /// `null` means "follow the system locale". Otherwise one of
  /// [kSupportedLocales].
  Locale? get locale => _locale;

  /// When `true`, the Auswertung tab reveals advanced sections
  /// (topology editor, micro-inverter banks, dispatch policy). Defaults
  /// to `false` so first-time users see a simpler form — PRD R-04
  /// mitigation ("Topologie-Editor kann Nutzer überfordern").
  bool get expertMode => _expertMode;

  /// `true` once [load] has read the persisted preferences.
  bool get loaded => _loaded;

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  /// Reads persisted preferences. Safe to call multiple times — only
  /// the first run flips [loaded]; later runs are no-ops on fields the
  /// user has already overridden.
  Future<void> load() async {
    final SharedPreferences prefs;
    try {
      prefs = await _prefs();
    } catch (e, st) {
      // Platform persistence layer unavailable (rare). Keep defaults
      // and mark loaded so the UI doesn't wait forever on a splash.
      _loaded = true;
      debugPrint('SettingsController.load: prefs unavailable: $e\n$st');
      notifyListeners();
      return;
    }
    if (!_themeModeUserSet) {
      _themeMode = _decodeTheme(prefs.getString(themeModeKey)) ?? ThemeMode.system;
    }
    if (!_localeUserSet) {
      _locale = _decodeLocale(prefs.getString(localeKey));
    }
    if (!_expertModeUserSet) {
      _expertMode = prefs.getBool(expertModeKey) ?? false;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeModeUserSet = true;
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await _prefs();
      await prefs.setString(themeModeKey, _encodeTheme(mode));
    } catch (e, st) {
      debugPrint('SettingsController.setThemeMode: persist failed: $e\n$st');
    }
  }

  Future<void> setExpertMode(bool value) async {
    _expertModeUserSet = true;
    if (_expertMode == value) return;
    _expertMode = value;
    notifyListeners();
    try {
      final prefs = await _prefs();
      await prefs.setBool(expertModeKey, value);
    } catch (e, st) {
      debugPrint('SettingsController.setExpertMode: persist failed: $e\n$st');
    }
  }

  /// Pass `null` to follow the system locale. Locales outside
  /// [kSupportedLocales] are normalised to `null` so the picker never
  /// ends up displaying a value with no matching radio option.
  Future<void> setLocale(Locale? locale) async {
    _localeUserSet = true;
    final normalised = _normaliseLocale(locale);
    if (_locale == normalised) return;
    _locale = normalised;
    notifyListeners();
    try {
      final prefs = await _prefs();
      if (normalised == null) {
        await prefs.remove(localeKey);
      } else {
        await prefs.setString(localeKey, normalised.languageCode);
      }
    } catch (e, st) {
      debugPrint('SettingsController.setLocale: persist failed: $e\n$st');
    }
  }

  static Locale? _normaliseLocale(Locale? input) {
    if (input == null) return null;
    for (final l in kSupportedLocales) {
      if (l.languageCode == input.languageCode) return l;
    }
    return null;
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
