import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/widgets/quick_start_wizard.dart';

import '_test_localization.dart';

/// Hosts the wizard behind a single Material button so each test can
/// drive the dialog without re-implementing the launcher.
Widget _host(ValueChanged<QuickStartResult?> onResult) {
  return germanMaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            key: const Key('open-wizard'),
            onPressed: () async {
              final result = await showQuickStartWizard(context);
              onResult(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openWizard(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-wizard')));
  await tester.pumpAndSettle();
}

Future<void> _continue(WidgetTester tester, int step) async {
  await tester.tap(find.byKey(Key('wizard-continue-$step')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('happy path builds a draft with one array, one inverter, one battery',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    QuickStartResult? captured;
    await tester.pumpWidget(_host((r) => captured = r));
    await _openWizard(tester);

    // Step 0 — site
    await tester.enterText(find.byKey(const Key('wizard-name')), 'Balkon');
    await tester.pump();
    await _continue(tester, 0);

    // Step 1 — array (defaults are valid, just advance)
    await _continue(tester, 1);

    // Step 2 — battery (default ON, advance)
    await _continue(tester, 2);

    // Step 3 — load (default valid)
    await _continue(tester, 3);

    // Step 4 — summary → finish
    await _continue(tester, 4);

    expect(captured, isNotNull);
    expect(captured!.projectName, 'Balkon');
    final draft = captured!.draft;
    expect(draft.arrays.length, 1);
    expect(draft.inverters.length, 1);
    expect(draft.arrays.first.inverterId, draft.inverters.first.id,
        reason: 'array must reference the inverter the wizard created');
    expect(draft.batteries.length, 1);
    expect(draft.microInverterBanks, isEmpty);
    expect(draft.topology.enabled, isFalse);
    expect(draft.usesAdvancedFeatures, isFalse,
        reason: 'a wizard-built draft must not exercise any expert-only feature');
    expect(draft.loadProfile.dailyKwh, greaterThan(0));

    // Engine validation must succeed on the resulting SimulationConfig.
    expect(() => draft.build().validate(), returnsNormally);
  });

  testWidgets('skipping the battery produces a draft with batteries: []',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    QuickStartResult? captured;
    await tester.pumpWidget(_host((r) => captured = r));
    await _openWizard(tester);

    await tester.enterText(find.byKey(const Key('wizard-name')), 'Solo PV');
    await tester.pump();
    await _continue(tester, 0);
    await _continue(tester, 1);

    // Step 2 — flip the battery switch off, then advance.
    await tester.tap(find.byKey(const Key('wizard-add-battery')));
    await tester.pumpAndSettle();
    await _continue(tester, 2);

    await _continue(tester, 3);
    await _continue(tester, 4);

    expect(captured, isNotNull);
    expect(captured!.draft.batteries, isEmpty);
    expect(() => captured!.draft.build().validate(), returnsNormally);
  });

  testWidgets('cancel at step 0 returns null and creates no project',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    var callbackFired = false;
    QuickStartResult? captured;
    await tester.pumpWidget(_host((r) {
      callbackFired = true;
      captured = r;
    }));
    await _openWizard(tester);

    await tester.tap(find.byKey(const Key('wizard-close')));
    await tester.pumpAndSettle();

    expect(callbackFired, isTrue, reason: 'launcher must complete');
    expect(captured, isNull);
  });

  testWidgets('continue is disabled until the site step is filled in',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host((_) {}));
    await _openWizard(tester);

    final continueButton =
        tester.widget<FilledButton>(find.byKey(const Key('wizard-continue-0')));
    expect(continueButton.onPressed, isNull,
        reason:
            'empty project name must keep "Weiter" disabled — Stepper.controlsBuilder gates on _canContinue');
  });
}
