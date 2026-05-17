import 'package:flutter/material.dart';
import 'package:pv_calculator_app/l10n/generated/app_localizations.dart';

/// Wraps [child] in a [MaterialApp] pinned to German so widget tests
/// that assert specific German strings keep matching regardless of the
/// host machine's locale. Add `localizationsDelegates` and
/// `supportedLocales` so any `AppLocalizations.of(context)` lookups
/// inside [child] succeed.
MaterialApp germanMaterialApp({required Widget home}) {
  return MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
