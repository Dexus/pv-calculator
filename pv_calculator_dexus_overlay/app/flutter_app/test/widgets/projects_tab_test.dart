import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/l10n/generated/app_localizations.dart';
import 'package:pv_calculator_app/pages/projects_tab.dart';
import 'package:pv_calculator_app/persistence/database.dart';
import 'package:pv_calculator_app/persistence/project_repository.dart';
import 'package:pv_calculator_app/persistence/scenario_repository.dart';
import 'package:pv_calculator_app/persistence/simulation_run_repository.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/state/scenario_comparison_controller.dart';

/// Hosts [ProjectsTab] inside the minimum scaffold it requires:
/// `DefaultTabController` (the open-scenario tap calls `animateTo(1)`) and
/// the provider tree built up in `main.dart`. Each test gets its own
/// in-memory db so seeded fixtures don't leak.
Widget _host(AppDatabase db) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProjectController>(create: (_) => ProjectController()),
      Provider<AppDatabase>.value(value: db),
      Provider<ProjectRepository>(create: (_) => ProjectRepository(db)),
      Provider<ScenarioRepository>(create: (_) => ScenarioRepository(db)),
      Provider<SimulationRunRepository>(create: (_) => SimulationRunRepository(db)),
      ChangeNotifierProvider<ScenarioComparisonController>(
        create: (_) => ScenarioComparisonController(
          scenarios: ScenarioRepository(db),
          runs: SimulationRunRepository(db),
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const DefaultTabController(
        length: 2,
        child: Scaffold(body: ProjectsTab()),
      ),
    ),
  );
}

void main() {
  late AppDatabase db;
  late ProjectRepository projects;
  late ScenarioRepository scenarios;

  setUp(() {
    db = AppDatabase.memory();
    projects = ProjectRepository(db);
    scenarios = ScenarioRepository(db);
  });

  tearDown(() => db.close());

  testWidgets('renders project ▸ scenarios tree with both scenarios', (tester) async {
    final project = projects.createProject(name: 'My House');
    scenarios.create(
      projectId: project.id,
      siteId: projects.defaultSiteFor(project.id)?.id,
      name: 'Variant A',
      config: ConfigDraft.demo().build(),
    );
    scenarios.create(
      projectId: project.id,
      siteId: projects.defaultSiteFor(project.id)?.id,
      name: 'Variant B',
      config: ConfigDraft.demo().build(),
    );

    await tester.pumpWidget(_host(db));
    await tester.pumpAndSettle();

    expect(find.text('My House'), findsOneWidget);
    expect(find.text('2 Szenarien'), findsOneWidget);
    expect(find.text('Variant A'), findsOneWidget);
    expect(find.text('Variant B'), findsOneWidget);
  });

  testWidgets('Vergleichen button is disabled until ≥2 scenarios are checked',
      (tester) async {
    final project = projects.createProject(name: 'P');
    scenarios.create(
      projectId: project.id,
      siteId: projects.defaultSiteFor(project.id)?.id,
      name: 'A',
      config: ConfigDraft.demo().build(),
    );
    scenarios.create(
      projectId: project.id,
      siteId: projects.defaultSiteFor(project.id)?.id,
      name: 'B',
      config: ConfigDraft.demo().build(),
    );

    await tester.pumpWidget(_host(db));
    await tester.pumpAndSettle();

    FilledButton compareButton() => tester.widget<FilledButton>(
          find.ancestor(
            of: find.textContaining('Vergleichen'),
            matching: find.byType(FilledButton),
          ),
        );

    expect(compareButton().onPressed, isNull,
        reason: 'no scenarios selected → disabled');
    expect(find.text('Vergleichen (0)'), findsOneWidget);

    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsNWidgets(2));
    await tester.tap(checkboxes.first);
    await tester.pumpAndSettle();
    expect(compareButton().onPressed, isNull,
        reason: '1 selected is still not enough');
    expect(find.text('Vergleichen (1)'), findsOneWidget);

    await tester.tap(checkboxes.last);
    await tester.pumpAndSettle();
    expect(compareButton().onPressed, isNotNull,
        reason: '2 selected enables the button');
    expect(find.text('Vergleichen (2)'), findsOneWidget);
  });

  testWidgets('Duplicate button on a scenario clones it under the same project',
      (tester) async {
    final project = projects.createProject(name: 'P');
    scenarios.create(
      projectId: project.id,
      siteId: projects.defaultSiteFor(project.id)?.id,
      name: 'Source',
      config: ConfigDraft.demo().build(),
    );

    await tester.pumpWidget(_host(db));
    await tester.pumpAndSettle();

    // ICU plural: singular German is "1 Szenario", plural "N Szenarien".
    expect(find.text('1 Szenario'), findsOneWidget);
    await tester.tap(find.byTooltip('Duplizieren'));
    await tester.pumpAndSettle();

    expect(find.text('2 Szenarien'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Source (2)'), findsOneWidget,
        reason: 'duplicate suggests "<name> (2)"');

    final stored = scenarios.listForProject(project.id);
    expect(stored, hasLength(2));
    expect(stored.first.inputHash, equals(stored.last.inputHash),
        reason: 'unchanged config keeps the same hash on duplicate');
  });

  testWidgets('shows the empty-state placeholder when no project exists',
      (tester) async {
    await tester.pumpWidget(_host(db));
    await tester.pumpAndSettle();

    // Localized empty-state copy from `projectListEmpty`.
    expect(find.byIcon(Icons.solar_power), findsOneWidget);
  });
}
