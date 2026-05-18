import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/pages/optimizer_page.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/optimizer_controller.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/results/optimizer_results_table.dart';

import '_test_localization.dart';

ConfigDraft _smallDraft() {
  return ConfigDraft(
    arrays: [
      PvArrayDraft(
        id: 'south',
        label: 'South',
        peakKw: 5.0,
        azimuthDeg: 180,
        tiltDeg: 30,
        inverterId: 'main',
      ),
    ],
    inverters: [
      InverterDraft(id: 'main', label: 'Main', maxAcKw: 5.0),
    ],
    batteries: [
      BatteryDraft(
        id: 'main',
        label: 'Main',
        capacityKwh: 5.0,
        maxChargeKw: 2.5,
        maxDischargeKw: 2.5,
      ),
    ],
    loadProfile: LoadProfileDraft(dailyKwh: 12.0),
    days: 1,
  );
}

Widget _host(ProjectController project, OptimizerController optimizer) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProjectController>.value(value: project),
      ChangeNotifierProvider<OptimizerController>.value(value: optimizer),
    ],
    child: germanMaterialApp(home: const OptimizerPage()),
  );
}

void main() {
  testWidgets('renders sections and is initially idle', (tester) async {
    final project = ProjectController(draft: _smallDraft());
    final optimizer = OptimizerController();
    await tester.pumpWidget(_host(project, optimizer));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('optimizer-objective')), findsOneWidget);
    expect(find.byKey(const Key('optimizer-battery-min')), findsOneWidget);
    expect(find.byKey(const Key('optimizer-battery-max')), findsOneWidget);
    expect(find.byKey(const Key('optimizer-battery-steps')), findsOneWidget);
    expect(find.byKey(const Key('optimizer-price-pv')), findsOneWidget);
    expect(find.byKey(const Key('optimizer-run')), findsOneWidget);
    // No results yet.
    expect(find.byKey(const Key('optimizer-counters')), findsNothing);
    expect(find.byKey(const Key('optimizer-no-candidates')), findsNothing);
  });

  testWidgets('run populates a top-N table with stable row keys', (tester) async {
    final project = ProjectController(draft: _smallDraft());
    final optimizer = OptimizerController();
    await tester.pumpWidget(_host(project, optimizer));
    await tester.pumpAndSettle();

    // Defaults: battery 5..15 (3 steps), inverter 4..8 (3 steps),
    // pvScale 0.8..1.4 (4 steps) = 3 × 3 × 4 = 36 combos. Each
    // candidate runs a full year (the optimizer forces days = 365),
    // so 36 × ~50 ms = ~1.8 s — fits comfortably in widget-test
    // budgets but worth keeping an eye on if CI gets slower.
    await tester.ensureVisible(find.byKey(const Key('optimizer-run')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('optimizer-run')));
    // Yield once so the controller's "running" state paints and the
    // synchronous sweep gets a chance to execute.
    await tester.pump();
    // Now drive the future to completion.
    await tester.pumpAndSettle();

    expect(optimizer.running, isFalse);
    expect(optimizer.lastResult, isNotNull);
    expect(optimizer.lastResult!.evaluated, equals(36));
    // topN defaults to 20 → 20 candidates after truncation.
    expect(optimizer.lastResult!.candidates.length, equals(20));
    expect(find.byKey(const Key('optimizer-counters')), findsOneWidget);
    expect(find.byType(OptimizerResultsTable), findsOneWidget);
  });

  testWidgets('budget below cheapest combo yields empty table + message', (tester) async {
    final project = ProjectController(draft: _smallDraft());
    final optimizer = OptimizerController();
    await tester.pumpWidget(_host(project, optimizer));
    await tester.pumpAndSettle();

    // Set the budget to 1 €.
    await tester.enterText(find.byKey(const Key('optimizer-budget')), '1');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('optimizer-run')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('optimizer-run')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(optimizer.lastResult, isNotNull);
    expect(optimizer.lastResult!.candidates, isEmpty);
    expect(optimizer.lastResult!.skippedOverBudget, greaterThan(0));
    expect(find.byKey(const Key('optimizer-no-candidates')), findsOneWidget);
  });

  testWidgets('optional-array checkbox flags the array for on/off sweep',
      (tester) async {
    final draft = _smallDraft();
    draft.arrays.add(PvArrayDraft(
      id: 'east',
      label: 'East',
      peakKw: 3.0,
      azimuthDeg: 90,
      tiltDeg: 30,
      inverterId: 'main',
    ));
    final project = ProjectController(draft: draft);
    final optimizer = OptimizerController();
    await tester.pumpWidget(_host(project, optimizer));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('optimizer-optional-east')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('optimizer-optional-east')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('optimizer-optional-east')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('optimizer-run')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('optimizer-run')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(optimizer.lastResult, isNotNull);
    // 3 × 3 × 4 = 36 combos × 2 subsets (east on/off) = 72.
    expect(optimizer.lastResult!.evaluated, equals(72));
  });
}
