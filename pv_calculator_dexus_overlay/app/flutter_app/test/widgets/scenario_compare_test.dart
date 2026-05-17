import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/pages/scenario_compare_page.dart';
import 'package:pv_calculator_app/persistence/database.dart';
import 'package:pv_calculator_app/persistence/project_repository.dart';
import 'package:pv_calculator_app/persistence/scenario_repository.dart';
import 'package:pv_calculator_app/persistence/simulation_run_repository.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/scenario_comparison_controller.dart';

Widget _host({
  required AppDatabase db,
  required ScenarioComparisonController controller,
}) {
  return MultiProvider(
    providers: [
      Provider<AppDatabase>.value(value: db),
      Provider<ProjectRepository>.value(value: ProjectRepository(db)),
      Provider<ScenarioRepository>.value(value: ScenarioRepository(db)),
      Provider<SimulationRunRepository>.value(value: SimulationRunRepository(db)),
      ChangeNotifierProvider<ScenarioComparisonController>.value(value: controller),
    ],
    child: const MaterialApp(home: ScenarioComparePage()),
  );
}

void main() {
  testWidgets('comparison page resolves two scenarios and renders the KPI table',
      (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final projects = ProjectRepository(db);
    final scenarios = ScenarioRepository(db);
    final runs = SimulationRunRepository(db);

    final project = projects.createProject(name: 'Sample');
    final a = scenarios.create(
      projectId: project.id,
      siteId: projects.defaultSiteFor(project.id)?.id,
      name: 'Variant A',
      config: ConfigDraft.demo().build(),
    );
    final b = scenarios.create(
      projectId: project.id,
      siteId: projects.defaultSiteFor(project.id)?.id,
      name: 'Variant B',
      config: ConfigDraft.demo().build(),
    );

    final controller =
        ScenarioComparisonController(scenarios: scenarios, runs: runs)
          ..replaceSelection([a.id, b.id]);

    await tester.pumpWidget(_host(db: db, controller: controller));
    // First pump triggers the postFrame resolve(); pumpAndSettle waits
    // for the in-process simulator to finish (small demo config).
    await tester.pumpAndSettle();

    expect(find.text('Szenariovergleich'), findsOneWidget);
    expect(find.text('Variant A'), findsWidgets);
    expect(find.text('Variant B'), findsWidgets);
    // Header columns from the KPI table.
    expect(find.text('PV AC (kWh)'), findsOneWidget);
    expect(find.text('Autarkie %'), findsOneWidget);
  });

  testWidgets('placeholder shows when selection is empty', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final controller = ScenarioComparisonController(
      scenarios: ScenarioRepository(db),
      runs: SimulationRunRepository(db),
    );
    await tester.pumpWidget(_host(db: db, controller: controller));
    await tester.pumpAndSettle();

    expect(
      find.text('Wähle mindestens zwei Szenarien aus dem Projekte-Tab.'),
      findsOneWidget,
    );
  });
}
