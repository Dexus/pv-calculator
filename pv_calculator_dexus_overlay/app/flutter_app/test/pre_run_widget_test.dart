import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/config.dart';
import 'package:pv_calculator_app/pages/results_tab.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_engine/pv_engine.dart';

import '_test_localization.dart';

void main() {
  testWidgets('SOC pre-run dropdown shows manual + single warm-up labels',
      (tester) async {
    final controller = ProjectController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: germanMaterialApp(home: const ResultsTab()),
      ),
    );

    // The simulation-params card is collapsed by default; expand it.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pre-run-mode-dropdown')), findsOneWidget);
    // The dropdown shows the currently-selected mode (singleWarmUp).
    expect(find.text('Einfacher Vorlauf'), findsWidgets);
  });

  testWidgets(
      'switching to cyclic convergence reveals tolerance + max-iter fields',
      (tester) async {
    // This assertion only makes sense in a Pro build; if the build flag
    // is off the dropdown entry is disabled and the test is skipped.
    if (!kProFeatures) {
      return;
    }
    final controller = ProjectController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: germanMaterialApp(home: const ResultsTab()),
      ),
    );

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('convergence-tolerance-field')), findsNothing);

    await tester.tap(find.byKey(const Key('pre-run-mode-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zyklische Konvergenz').last);
    await tester.pumpAndSettle();

    expect(controller.draft.preRunMode, PreRunMode.cyclicConvergence);
    expect(controller.draft.days, 365,
        reason: 'cyclic convergence pins days to 365 to match engine validation');
    expect(controller.draft.preRunDays, 0);
    expect(find.byKey(const Key('convergence-tolerance-field')), findsOneWidget);
    expect(
        find.byKey(const Key('max-convergence-iterations-field')), findsOneWidget);
  });

  testWidgets('non-Pro build labels the cyclic entry "(Pro)"', (tester) async {
    if (kProFeatures) {
      return;
    }
    final controller = ProjectController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: germanMaterialApp(home: const ResultsTab()),
      ),
    );
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pre-run-mode-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('Zyklische Konvergenz (Pro)'), findsWidgets);
  });

  testWidgets('Pre-Run section renders after a cyclic-mode run', (tester) async {
    if (!kProFeatures) {
      return;
    }
    final controller = ProjectController();
    controller.draft
      ..preRunMode = PreRunMode.cyclicConvergence
      ..preRunDays = 0
      ..days = 365;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: germanMaterialApp(home: const ResultsTab()),
      ),
    );
    controller.run();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pre-run-mode-card')), findsOneWidget);
    expect(find.byKey(const Key('pre-run-iterations-card')), findsOneWidget);
    expect(find.byKey(const Key('pre-run-converged-card')), findsOneWidget);
  });
}
