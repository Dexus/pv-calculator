import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/editor_page.dart';
import 'package:pv_calculator_app/widgets/results/results_page.dart';

void main() {
  testWidgets('Run button navigates to results page with non-zero KPIs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final controller = ProjectController();

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: Builder(
          builder: (context) => EditorPage(
            onRunRequested: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChangeNotifierProvider<ProjectController>.value(
                    value: controller,
                    child: const ResultsPage(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(EditorPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('run-button')));
    await tester.pumpAndSettle();

    expect(find.byType(ResultsPage), findsOneWidget);
    expect(find.text('Jahreskennzahlen'), findsOneWidget);
    expect(controller.result, isNotNull);
    expect(controller.result!.summary.pvAcKwh, greaterThan(0));
    // Monthly table rendered with all twelve month labels.
    expect(find.text('Jan'), findsOneWidget);
    expect(find.text('Dez'), findsOneWidget);
    // CSV buttons exist.
    expect(find.byKey(const Key('export-steps-csv')), findsOneWidget);
    expect(find.byKey(const Key('export-monthly-csv')), findsOneWidget);
  });

  testWidgets('ResultsPage renders a run-error card when run() failed', (tester) async {
    // Drive the controller into the (rare) state where a previous run
    // failed: no result, but lastError populated. This is reachable in
    // production if a freshly-loaded project happens to fail validation
    // between the editor's gate and the simulator.
    final controller = ProjectController(
      draft: ConfigDraft(
        // No arrays — engine rejects this during run().
        inverters: [InverterDraft(id: 'main', maxAcKw: 5)],
        loadProfile: LoadProfileDraft(dailyKwh: 5),
      ),
    );
    final ok = controller.run();
    expect(ok, isFalse);
    expect(controller.lastError, isNotNull);
    expect(controller.result, isNull);

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: const ResultsPage(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('results-run-error-card')), findsOneWidget);
    expect(find.text('Simulation fehlgeschlagen'), findsOneWidget);
  });

  testWidgets('ResultsPage empty state offers a back button', (tester) async {
    final controller = ProjectController();
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: const ResultsPage(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Keine Simulation ausgeführt.'), findsOneWidget);
    expect(find.text('Zurück zur Konfiguration'), findsOneWidget);
    expect(find.byKey(const Key('results-run-error-card')), findsNothing);
  });
}
