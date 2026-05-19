import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'catalog/catalog_repository.dart';
import 'l10n/generated/app_localizations.dart';
import 'pages/main_scaffold.dart';
import 'persistence/database.dart';
import 'persistence/irradiance_cache_repository.dart';
import 'persistence/project_repository.dart';
import 'persistence/scenario_repository.dart';
import 'persistence/simulation_run_repository.dart';
import 'persistence/sp_migration.dart';
import 'state/optimizer_controller.dart';
import 'state/project_controller.dart';
import 'state/scenario_comparison_controller.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppDatabase database;
  try {
    database = await AppDatabase.open();
  } catch (error, stack) {
    // On web, an AppDatabase.open() failure means the sqlite3 WASM bundle
    // failed to load or instantiate. Without this guard, runApp() is never
    // called and the user sees a blank canvas with no diagnostic — the
    // error only surfaces in the JS console. Surface it visibly instead.
    debugPrint('main: AppDatabase.open() failed — $error\n$stack');
    runApp(_DatabaseInitErrorApp(error: error));
    return;
  }
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

/// Last-resort fallback when AppDatabase.open() throws before any normal
/// UI has been mounted. AppLocalizations is not available here (no
/// MaterialApp context yet), so the copy is bilingual DE/EN.
class _DatabaseInitErrorApp extends StatelessWidget {
  const _DatabaseInitErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PV Calculator',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Datenbank konnte nicht initialisiert werden.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Could not initialize the database. On web this usually '
                      'means that sqlite3.wasm failed to load — reload the '
                      'page or clear the site data and try again.',
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      '$error',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PvCalculatorApp extends StatelessWidget {
  const PvCalculatorApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    // One shared IrradianceCacheRepository — both the ProjectController
    // (writes/reads through it on load) and any consumer that resolves
    // it via `Provider.of` need to see the same SQL-backed store.
    // Two instances would be functionally equivalent today (the repo is
    // stateless beyond the AppDatabase handle), but a shared instance
    // keeps DI legible and future-proofs in-memory state/metrics.
    final irradianceCache = IrradianceCacheRepository(database);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsController()..load()),
        ChangeNotifierProvider(
          create: (_) => ProjectController(irradianceCache: irradianceCache),
        ),
        Provider<AppDatabase>.value(value: database),
        Provider<ProjectRepository>(create: (_) => ProjectRepository(database)),
        Provider<ScenarioRepository>(create: (_) => ScenarioRepository(database)),
        Provider<SimulationRunRepository>(create: (_) => SimulationRunRepository(database)),
        Provider<IrradianceCacheRepository>.value(value: irradianceCache),
        ChangeNotifierProvider<CatalogRepository>(
          create: (_) => CatalogRepository.standard(database),
        ),
        ChangeNotifierProvider<ScenarioComparisonController>(
          create: (ctx) => ScenarioComparisonController(
            scenarios: ScenarioRepository(database),
            runs: SimulationRunRepository(database),
          ),
        ),
        ChangeNotifierProvider<OptimizerController>(
          create: (_) => OptimizerController(),
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
