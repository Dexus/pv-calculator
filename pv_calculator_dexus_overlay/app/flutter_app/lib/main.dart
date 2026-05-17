import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/generated/app_localizations.dart';
import 'state/project_controller.dart';
import 'state/settings_controller.dart';
import 'widgets/project_list_page.dart';

void main() => runApp(const PvCalculatorApp());

class PvCalculatorApp extends StatelessWidget {
  const PvCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsController()..load()),
        ChangeNotifierProvider(create: (_) => ProjectController()),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          onGenerateTitle: (ctx) => AppLocalizations.of(ctx).projectListTitle,
          themeMode: settings.themeMode,
          locale: settings.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: const ProjectListPage(),
        ),
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.amber,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(),
    ),
  );
}
