import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_info.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/settings_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l.settingsAppearance,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (mode) {
              if (mode != null) settings.setThemeMode(mode);
            },
            child: Column(children: [
              RadioListTile<ThemeMode>(
                key: const Key('theme-mode-system'),
                title: Text(l.settingsThemeSystem),
                subtitle: Text(l.settingsThemeSystemDesc),
                value: ThemeMode.system,
              ),
              RadioListTile<ThemeMode>(
                key: const Key('theme-mode-light'),
                title: Text(l.settingsThemeLight),
                value: ThemeMode.light,
              ),
              RadioListTile<ThemeMode>(
                key: const Key('theme-mode-dark'),
                title: Text(l.settingsThemeDark),
                value: ThemeMode.dark,
              ),
            ]),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              l.settingsLanguage,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          RadioGroup<Locale?>(
            groupValue: settings.locale,
            onChanged: (locale) => settings.setLocale(locale),
            child: Column(children: [
              RadioListTile<Locale?>(
                key: const Key('locale-system'),
                title: Text(l.settingsLanguageSystem),
                subtitle: Text(l.settingsLanguageSystemDesc),
                value: null,
              ),
              for (final locale in kSupportedLocales)
                RadioListTile<Locale?>(
                  key: Key('locale-${locale.languageCode}'),
                  title: Text(_nativeLanguageName(locale.languageCode)),
                  value: locale,
                ),
            ]),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              l.settingsAdvanced,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SwitchListTile(
            key: const Key('expert-mode-toggle'),
            secondary: const Icon(Icons.tune),
            title: Text(l.settingsExpertMode),
            subtitle: Text(l.settingsExpertModeDesc),
            value: settings.expertMode,
            onChanged: (value) => settings.setExpertMode(value),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l.settingsAboutApp),
            onTap: () => showAppAboutDialog(context),
          ),
        ],
      ),
    );
  }
}

void showAppAboutDialog(BuildContext context) {
  final l = AppLocalizations.of(context);
  showAboutDialog(
    context: context,
    applicationName: 'PV Calculator',
    applicationVersion: appVersion,
    applicationLegalese: '© Dexus — AGPL-3.0',
    children: [
      const SizedBox(height: 12),
      Text(l.settingsAboutBody),
    ],
  );
}

/// Native (endonym) name for a supported language code. Names are
/// intentionally in each language's own form ("Deutsch", "English", …)
/// regardless of the current locale, so users can find their language
/// even when the UI is in one they don't read. Falls back to the raw
/// code if a new locale is added to [kSupportedLocales] without an
/// endonym entry here — analyzer + a future translator catches the gap.
String _nativeLanguageName(String languageCode) {
  switch (languageCode) {
    case 'de':
      return 'Deutsch';
    case 'en':
      return 'English';
    case 'fr':
      return 'Français';
    case 'es':
      return 'Español';
  }
  return languageCode;
}
