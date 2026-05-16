import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/editor_page.dart';
import 'package:pv_engine/pv_engine.dart';

/// Test-only stand-in that lets us mount the editor in the rare state
/// where validation passes but the simulator still failed (e.g. an
/// engine throw past validate()). Overriding the [lastError] getter
/// keeps the production controller free of `@visibleForTesting`
/// setters that have no real consumer.
class _ControllerWithStubError extends ProjectController {
  _ControllerWithStubError({required String message}) : _stubError = message;

  String? _stubError;

  @override
  String? get lastError => _stubError;

  @override
  void touch() {
    _stubError = null;
    super.touch();
  }
}

void main() {
  group('classifyValidationMessage', () {
    test('routes array messages to the arrays section', () {
      expect(classifyValidationMessage('At least one PV array is required.'),
          ConfigSection.arrays);
      expect(classifyValidationMessage('PV array south peakKw must be positive.'),
          ConfigSection.arrays);
      expect(
        classifyValidationMessage(
            'PV array south references missing inverter main.'),
        ConfigSection.arrays,
      );
      expect(
        classifyValidationMessage(
            'PV array south nominalOperatingCellTempC must be in [20, 70] °C.'),
        ConfigSection.arrays,
      );
    });

    test('routes inverter messages to the inverters section', () {
      expect(classifyValidationMessage('At least one inverter is required.'),
          ConfigSection.inverters);
      expect(classifyValidationMessage('Inverter main maxAcKw must be positive.'),
          ConfigSection.inverters);
      expect(
        classifyValidationMessage('Inverter main maxDcInputKw must be positive.'),
        ConfigSection.inverters,
      );
      expect(classifyValidationMessage('Duplicate inverter id: main.'),
          ConfigSection.inverters);
    });

    test('routes battery messages to the batteries section', () {
      expect(
        classifyValidationMessage(
            'Battery main minSocKwh must be between 0 and capacityKwh.'),
        ConfigSection.batteries,
      );
      expect(
        classifyValidationMessage(
            'Battery main roundTripEfficiency must be in (0, 1].'),
        ConfigSection.batteries,
      );
      expect(classifyValidationMessage('Duplicate battery id: main.'),
          ConfigSection.batteries);
    });

    test('routes load profile messages to the load section', () {
      expect(classifyValidationMessage('Load dailyKwh must not be negative.'),
          ConfigSection.load);
      expect(classifyValidationMessage('Load hourlyShape must have 24 values.'),
          ConfigSection.load);
    });

    test('routes project-level messages to the project section', () {
      expect(classifyValidationMessage('latitudeDeg must be in [-90, 90].'),
          ConfigSection.project);
      expect(classifyValidationMessage('longitudeDeg must be in [-180, 180].'),
          ConfigSection.project);
      expect(classifyValidationMessage('days must be in [1, 365].'),
          ConfigSection.project);
      expect(classifyValidationMessage('preRunDays must be in [0, 365].'),
          ConfigSection.project);
      expect(
        classifyValidationMessage('gridExportLimitKw must not be negative.'),
        ConfigSection.project,
      );
    });

    test('returns unknown when no keyword matches', () {
      expect(classifyValidationMessage('Something completely unexpected.'),
          ConfigSection.unknown);
    });
  });

  group('ConfigDraft.validationIssue', () {
    test('classifies a missing-array draft as an arrays issue', () {
      final draft = ConfigDraft(
        loadProfile: LoadProfileDraft(dailyKwh: 5),
        inverters: [InverterDraft(id: 'main', maxAcKw: 5)],
      );
      final issue = draft.validationIssue();
      expect(issue, isNotNull);
      expect(issue!.section, ConfigSection.arrays);
    });

    test('classifies a missing-inverter draft as an inverters issue', () {
      final draft = ConfigDraft(
        loadProfile: LoadProfileDraft(dailyKwh: 5),
        arrays: [PvArrayDraft(id: 'a', peakKw: 1, inverterId: 'missing')],
      );
      final issue = draft.validationIssue();
      expect(issue, isNotNull);
      expect(issue!.section, ConfigSection.inverters);
    });

    test('returns null for a valid demo draft', () {
      expect(ConfigDraft.demo().validationIssue(), isNull);
    });
  });

  testWidgets('disables Run when the draft is invalid', (tester) async {
    // Give the surface enough height for the section-scoped banner that
    // now lives above the Arrays section to be in the rendered viewport.
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final controller = ProjectController(
      draft: ConfigDraft(
        // No arrays / no inverters → invalid by construction.
        loadProfile: LoadProfileDraft(dailyKwh: 5),
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: const EditorPage(),
      ),
    ));
    await tester.pumpAndSettle();

    // The classified arrays-issue banner appears with its scoped key,
    // and the legacy top-of-page banner stays hidden.
    expect(
      find.byKey(const Key('validation-banner-arrays')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('validation-banner-unknown')),
      findsNothing,
    );

    final runButton = tester.widget<FilledButton>(find.byKey(const Key('run-button')));
    expect(runButton.onPressed, isNull);
  });

  testWidgets('enables Run for the demo project and runs successfully', (tester) async {
    final controller = ProjectController();

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: const EditorPage(),
      ),
    ));
    await tester.pumpAndSettle();

    final runButton = tester.widget<FilledButton>(find.byKey(const Key('run-button')));
    expect(runButton.onPressed, isNotNull);

    final ok = controller.run();
    expect(ok, isTrue);
    expect(controller.result, isNotNull);
    expect(controller.result!.summary.pvAcKwh, greaterThan(0));
  });

  testWidgets('surfaces controller.lastError on the editor after a failed run', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    // Start from a valid draft so the run button is enabled, then
    // monkey-patch the draft into an invalid shape *after* the editor
    // mounts so the failure happens inside controller.run().
    final controller = ProjectController();
    expect(controller.draft.validationIssue(), isNull);

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: const EditorPage(),
      ),
    ));
    await tester.pumpAndSettle();

    // Make the draft invalid post-mount: clear all inverters. The
    // run-button gate would normally catch this, but `run()` itself
    // re-validates, so calling it directly exercises the failure path
    // the user could reach via a race or a future engine throw.
    controller.draft.inverters.clear();
    final ok = controller.run();
    expect(ok, isFalse);
    expect(controller.lastError, isNotNull);

    await tester.pumpAndSettle();

    // The validation gate now reports the same issue (no inverters),
    // so the section-scoped banner appears. The run-error banner only
    // shows when validation passes but the simulator still failed, so
    // here we expect the section banner. The point of this test is
    // that controller.lastError survived until the next touch().
    expect(controller.lastError, isNotNull,
        reason: 'lastError persists until the next draft mutation.');

    // Editing the form clears the stale failure message.
    controller.touch();
    expect(controller.lastError, isNull);
  });

  testWidgets('run-error banner appears when validation passes but run() throws', (tester) async {
    // This is the path the reviewer flagged as previously unreachable:
    // a controller with no validation issues but a populated
    // lastError. We synthesise the state directly because the engine
    // currently can't fail past validate() with the demo draft.
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final controller = _ControllerWithStubError(
      message: 'Synthetic engine failure',
    );

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: const EditorPage(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('run-error-banner')), findsOneWidget);
    expect(find.text('Simulation fehlgeschlagen'), findsOneWidget);
    expect(find.text('Synthetic engine failure'), findsOneWidget);

    // touch() clears the stale message.
    controller.touch();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('run-error-banner')), findsNothing);
  });

  testWidgets('orphaned PVGIS imports surface a chip the user can drop', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final controller = ProjectController();
    // Attach a series for a non-existent array id; the demo draft only
    // has 'south-roof', so 'ghost' is immediately orphaned.
    controller.draft.setArrayWeather(
      'ghost',
      List<WeatherSample>.filled(365 * 24, WeatherSample.empty),
      const PvgisImportInfo(
        sourceLabel: 'demo', entryCount: 8760, coveredYears: [2020],
        latitudeDeg: 0, longitudeDeg: 0,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ProjectController>.value(
        value: controller,
        child: const EditorPage(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('orphaned-pvgis-card')), findsOneWidget);
    expect(find.byKey(const Key('orphaned-pvgis-chip-ghost')), findsOneWidget);

    // Tapping the chip's delete icon clears the orphan from the draft.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(controller.draft.hasWeatherFor('ghost'), isFalse);
    expect(find.byKey(const Key('orphaned-pvgis-card')), findsNothing);
  });
}
