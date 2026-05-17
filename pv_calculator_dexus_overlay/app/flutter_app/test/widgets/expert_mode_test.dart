import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/pages/results_tab.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/state/settings_controller.dart';
import 'package:pv_calculator_app/widgets/forms/dispatch_policy_section.dart';
import 'package:pv_calculator_app/widgets/forms/micro_inverter_banks_section.dart';
import 'package:pv_calculator_app/widgets/forms/topology_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../_test_localization.dart';

Future<SettingsController> _settings({bool expert = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = SettingsController(prefs: prefs);
  await controller.load();
  if (expert) await controller.setExpertMode(true);
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
  testWidgets(
      'expert mode off: advanced sections hidden, hint card visible',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 2400));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final project = ProjectController();
    final settings = await _settings();

    await tester.pumpWidget(_host(project, settings));
    await tester.pumpAndSettle();

    expect(find.byType(TopologySection), findsNothing);
    expect(find.byType(MicroInverterBanksSection), findsNothing);
    expect(find.byType(DispatchPolicySection), findsNothing);
    expect(find.byKey(const Key('enable-expert-hint')), findsOneWidget);
    // The auto-detect banner only shows when the draft already uses an
    // advanced feature — the demo project does not.
    expect(find.byKey(const Key('advanced-scenario-banner')), findsNothing);
  });

  testWidgets(
      'expert mode on: advanced sections visible, hint card hidden',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 2400));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final project = ProjectController();
    final settings = await _settings(expert: true);

    await tester.pumpWidget(_host(project, settings));
    await tester.pumpAndSettle();

    expect(find.byType(TopologySection), findsOneWidget);
    expect(find.byType(MicroInverterBanksSection), findsOneWidget);
    expect(find.byType(DispatchPolicySection), findsOneWidget);
    expect(find.byKey(const Key('enable-expert-hint')), findsNothing);
    expect(find.byKey(const Key('advanced-scenario-banner')), findsNothing);
  });

  testWidgets(
      'expert mode off + advanced-features draft: banner shows above hint',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 2400));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final project = ProjectController();
    // Mark the draft as using advanced features without flipping the
    // engine into anything that would fail validation — just enable
    // the topology editor flag. The demo arrays already reference an
    // inverter, so `topology.build()` would succeed if the engine
    // were to run, but this test never runs the simulation.
    project.draft.topology.enabled = true;

    final settings = await _settings();

    await tester.pumpWidget(_host(project, settings));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('advanced-scenario-banner')), findsOneWidget);
    expect(find.byKey(const Key('enable-expert-hint')), findsOneWidget);
    // Sections are still hidden because expert mode is off; the banner
    // is the only signal the user gets.
    expect(find.byType(TopologySection), findsNothing);
  });

  testWidgets('toggling expert mode at runtime flips section visibility',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 2400));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final project = ProjectController();
    final settings = await _settings();

    await tester.pumpWidget(_host(project, settings));
    await tester.pumpAndSettle();

    expect(find.byType(TopologySection), findsNothing);

    await settings.setExpertMode(true);
    await tester.pumpAndSettle();

    expect(find.byType(TopologySection), findsOneWidget);
    expect(find.byKey(const Key('enable-expert-hint')), findsNothing);
  });

  test('ConfigDraft.usesAdvancedFeatures detects topology / banks / dispatch',
      () {
    final base = ConfigDraft.demo();
    expect(base.usesAdvancedFeatures, isFalse);

    final withTopology = ConfigDraft.demo()..topology.enabled = true;
    expect(withTopology.usesAdvancedFeatures, isTrue);

    final withDispatch = ConfigDraft.demo()
      ..dispatchPolicy = DispatchPolicyDraft(
        kind: DispatchPolicyKind.batteryReserve,
        reserveSocFraction: 0.3,
      );
    expect(withDispatch.usesAdvancedFeatures, isTrue);
  });
}
