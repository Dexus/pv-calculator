import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/editor_page.dart';
import 'package:pv_calculator_app/widgets/results/results_page.dart';

void main() {
  testWidgets('Run button navigates to results page with non-zero KPIs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
}
