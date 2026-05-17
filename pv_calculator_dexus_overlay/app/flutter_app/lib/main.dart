import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/generated/app_localizations.dart';
import 'pages/main_scaffold.dart';
import 'persistence/database.dart';
import 'persistence/project_repository.dart';
import 'persistence/scenario_repository.dart';
import 'persistence/simulation_run_repository.dart';
import 'persistence/sp_migration.dart';
import 'state/project_controller.dart';
import 'state/scenario_comparison_controller.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  // One-shot migration of the legacy shared_preferences project list into
  // the new schema. Idempotent and silent on subsequent launches.
  final imported = await SharedPreferencesMigration(database: database)
      .migrateIfNeeded();
  if (imported > 0) {
    debugPrint('main: migrated $imported project(s) from shared_preferences.');
  }
  debugPrint('main: AppDatabase storage tier = ${database.storageTier.name}.');
  runApp(PvCalculatorApp(database: database));
}

class PvCalculatorApp extends StatelessWidget {
  const PvCalculatorApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsController()..load()),
        ChangeNotifierProvider(create: (_) => ProjectController()),
        Provider<AppDatabase>.value(value: database),
        Provider<ProjectRepository>(create: (_) => ProjectRepository(database)),
        Provider<ScenarioRepository>(create: (_) => ScenarioRepository(database)),
        Provider<SimulationRunRepository>(create: (_) => SimulationRunRepository(database)),
        ChangeNotifierProvider<ScenarioComparisonController>(
          create: (ctx) => ScenarioComparisonController(
            scenarios: ScenarioRepository(database),
            runs: SimulationRunRepository(database),
          ),
        ),
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
          home: const MainScaffold(),
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
