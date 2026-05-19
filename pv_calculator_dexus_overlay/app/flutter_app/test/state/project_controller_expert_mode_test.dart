import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage for the deferred "Auto-Enable Expertenmodus" item
/// (ROADMAP §Phase 8 Verschoben): loading a scenario that uses advanced
/// editor sections (topology, micro-inverter banks, non-default dispatch
/// policy, charge controllers) flips `expertMode` on so the user does
/// not have to chase a banner before the gated panels appear.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ConfigDraft advancedDraft() {
    final draft = ConfigDraft.demo();
    draft.dispatchPolicy.kind = DispatchPolicyKind.batteryReserve;
    expect(draft.usesAdvancedFeatures, isTrue,
        reason: 'fixture sanity: predicate must agree the draft is advanced');
    return draft;
  }

  test('loadDraft on an advanced scenario auto-enables expert mode', () async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsController(prefs: prefs);
    await settings.load();
    expect(settings.expertMode, isFalse);

    final controller = ProjectController(settings: settings);
    controller.loadDraft('Advanced project', advancedDraft());

    expect(settings.expertMode, isTrue);
    // Persistence is best-effort and runs in the background; pump once
    // so the setter's awaited `prefs.setBool` lands before we assert.
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getBool(SettingsController.expertModeKey), isTrue);
  });

  test('loadDraft on a basic scenario leaves expert mode untouched',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsController(prefs: prefs);
    await settings.load();

    var notifications = 0;
    settings.addListener(() => notifications++);

    final controller = ProjectController(settings: settings);
    controller.loadDraft('Demo project', ConfigDraft.demo());

    expect(settings.expertMode, isFalse);
    expect(notifications, 0,
        reason: 'a basic draft must not poke the SettingsController');
  });

  test('loadDraft is a no-op on settings when expert mode is already on',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsController(prefs: prefs);
    await settings.load();
    await settings.setExpertMode(true);
    expect(settings.expertMode, isTrue);

    var notifications = 0;
    settings.addListener(() => notifications++);

    final controller = ProjectController(settings: settings);
    controller.loadDraft('Advanced project', advancedDraft());

    expect(settings.expertMode, isTrue);
    expect(notifications, 0,
        reason: 'auto-enable must short-circuit when expertMode is true');
  });

  test('loadDraft works without a SettingsController (legacy callers)',
      () async {
    // Existing widget tests construct ProjectController without wiring
    // a SettingsController. The null branch must stay a clean no-op.
    final controller = ProjectController();
    controller.loadDraft('Advanced project', advancedDraft());
    // No assertion needed beyond "does not throw" — the test fails on
    // an unhandled exception.
    expect(controller.draft.usesAdvancedFeatures, isTrue);
  });
}
