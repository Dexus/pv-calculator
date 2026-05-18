import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/pages/results_tab.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/state/settings_controller.dart';
import 'package:pv_engine/pv_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_test_localization.dart';

Future<SettingsController> _settings() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = SettingsController(prefs: prefs);
  await controller.load();
  return controller;
}

Widget _host(ProjectController project, SettingsController settings) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProjectController>.value(value: project),
      ChangeNotifierProvider<SettingsController>.value(value: settings),
    ],
    child: germanMaterialApp(home: const ResultsTab()),
  );
}

void main() {
  group('ConfigDraft.validationWarnings', () {
    test('clean demo only emits the irradiance-missing hint', () {
      final warnings = ConfigDraft.demo().validationWarnings();
      expect(warnings.map((w) => w.code), ['irradiance-missing']);
      expect(warnings.single.severity, WarningSeverity.hint);
    });

    test('inverter-oversized fires when DC peak > 1.3× AC cap', () {
      final draft = ConfigDraft.demo();
      draft.inverters.first.maxAcKw = 2.0;
      draft.arrays.first.peakKw = 6.0; // 3.0× the AC cap
      final codes = draft.validationWarnings().map((w) => w.code).toList();
      expect(codes, contains('inverter-oversized'));
    });

    test('inverter-oversized stays silent at exactly 1.3× ratio', () {
      final draft = ConfigDraft.demo();
      draft.inverters.first.maxAcKw = 2.0;
      draft.arrays.first.peakKw = 2.6; // ratio == 1.30
      final codes = draft.validationWarnings().map((w) => w.code).toList();
      expect(codes, isNot(contains('inverter-oversized')),
          reason: 'threshold is strictly > 1.3, equality should not fire');
    });

    test('battery-min-soc-high fires when minSOC > 50% of capacity', () {
      final draft = ConfigDraft.demo();
      draft.batteries.first
        ..capacityKwh = 10
        ..minSocKwh = 6;
      final codes = draft.validationWarnings().map((w) => w.code).toList();
      expect(codes, contains('battery-min-soc-high'));
    });

    test('bank-exceeds-discharge fires when bank AC > battery discharge', () {
      final draft = ConfigDraft.demo();
      // Demo battery: 3.0 kW discharge; add a bank that demands 4 kW.
      draft.microInverterBanks.add(MicroInverterBankDraft(
        id: 'bank-1',
        batteryId: draft.batteries.first.id,
        count: 5,
        unitRatedPowerW: 800,
      ));
      final codes = draft.validationWarnings().map((w) => w.code).toList();
      expect(codes, contains('bank-exceeds-discharge'));
    });
  });

  group('_WarningsSection renders warning cards in ResultsTab', () {
    testWidgets('hint card is shown for the demo project', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 2400));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      final project = ProjectController();
      final settings = await _settings();
      await tester.pumpWidget(_host(project, settings));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('warning-irradiance-missing')),
          findsOneWidget);
    });

    testWidgets('warning card appears when bank exceeds battery discharge',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 2400));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      final project = ProjectController();
      project.draft.microInverterBanks.add(MicroInverterBankDraft(
        id: 'bank-1',
        batteryId: project.draft.batteries.first.id,
        count: 5,
        unitRatedPowerW: 800,
      ));

      final settings = await _settings();
      await tester.pumpWidget(_host(project, settings));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('warning-bank-exceeds-discharge')),
          findsOneWidget);
    });

    testWidgets(
        'section title hides when the draft emits no warnings or hints',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 2400));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      final project = ProjectController();
      // Suppress the irradiance-missing hint by attaching a stub
      // 365×24 series; that is the only finding the demo draft would
      // otherwise raise.
      project.draft.siteIrradiance.samples = HorizontalIrradianceSeries(
        samples: List.filled(
          365 * 24,
          const HorizontalIrradianceSample(
            globalHorizontalWPerM2: 0,
            diffuseHorizontalWPerM2: 0,
            ambientTempC: 25,
          ),
        ),
        year: 2022,
        latitudeDeg: project.draft.latitudeDeg,
        longitudeDeg: project.draft.longitudeDeg,
      );
      expect(project.draft.validationWarnings(), isEmpty,
          reason: 'pre-condition: stub series must remove every finding');

      final settings = await _settings();
      await tester.pumpWidget(_host(project, settings));
      await tester.pumpAndSettle();

      expect(find.text('Hinweise zur Konfiguration'), findsNothing,
          reason: 'no warnings ⇒ the section header should not render');
    });

    testWidgets(
        'section title is visible while the demo draft still has the missing-irradiance hint',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 2400));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      final project = ProjectController();
      final settings = await _settings();
      await tester.pumpWidget(_host(project, settings));
      await tester.pumpAndSettle();

      expect(find.text('Hinweise zur Konfiguration'), findsOneWidget);
      expect(find.byKey(const Key('warning-irradiance-missing')),
          findsOneWidget);
    });
  });
}
