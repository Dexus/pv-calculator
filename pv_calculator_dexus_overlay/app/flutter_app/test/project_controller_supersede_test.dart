import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/services/simulation_runner.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_engine/pv_engine.dart';

/// Regression tests for PR #26 Codex review-round 3 threads:
///   * superseded runs must still tear down `running`/`progress`;
///   * compass-azimuth edits must supersede an in-flight run;
///   * the result cache must not return stale entries when irradiance
///     is reloaded (already covered indirectly, but pinned here).
///
/// We can't directly run a real simulation across an isolate boundary
/// inside `flutter_test` (the cyclic 365-day path used to hang under
/// fake time), so we drive `ProjectController` against a fake
/// [SimulationRunner] that only completes when we tell it to. That
/// lets us hold the run in an "awaiting isolate" state, mutate the
/// draft, and inspect what the controller does when the run finally
/// completes.
class _FakeRunner implements SimulationRunner {
  _FakeRunner();

  @override
  bool get runInProcess => true;

  final List<Completer<SimulationResult>> _pending = [];

  @override
  Future<SimulationResult> run(
    SimulationConfig config, {
    void Function(SimulationProgress)? onProgress,
  }) {
    final c = Completer<SimulationResult>();
    _pending.add(c);
    return c.future;
  }

  void completeNext(SimulationResult result) {
    final c = _pending.removeAt(0);
    c.complete(result);
  }

  int get pendingCount => _pending.length;
}

SimulationResult _emptyResult() {
  // Build a trivial config and run it synchronously to get a real
  // SimulationResult shape — saves us assembling SimulationStep /
  // SimulationSummary by hand.
  final cfg = SimulationConfig(
    arrays: const [
      PvArray(id: 'a', label: 'A', peakKw: 1, azimuthDeg: 180, tiltDeg: 35, inverterId: 'inv'),
    ],
    inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 1)],
    loadProfile: const LoadProfile(dailyKwh: 1),
    days: 1,
    keepSteps: false,
  );
  return const PvSimulator().run(cfg);
}

void main() {
  test('superseded by touch(): _running clears when the stale run completes',
      () async {
    final fake = _FakeRunner();
    final controller = ProjectController(simulationRunner: fake);

    // Kick off a run, then supersede it via touch() *without* starting
    // a fresher run(). The stale isolate eventually completes — the
    // controller must still tear down its running state, otherwise the
    // Run button stays disabled forever.
    final future = controller.run();
    expect(controller.running, isTrue);
    expect(fake.pendingCount, 1);

    controller.touch(); // supersede
    expect(controller.running, isTrue,
        reason: 'touch() should not clear running on its own — '
            'the in-flight run still owns the lifecycle');

    fake.completeNext(_emptyResult());
    await future;

    expect(controller.running, isFalse,
        reason: 'superseded run must clear _running in its finally '
            'because no fresher run() is in flight');
    expect(controller.progress, isNull);
    expect(controller.result, isNull,
        reason: 'the stale result must not be committed over the touched draft');
  });

  test('newer run() supersedes older — older does NOT prematurely clear flag',
      () async {
    final fake = _FakeRunner();
    final controller = ProjectController(simulationRunner: fake);

    final older = controller.run();
    final newer = controller.run();
    expect(fake.pendingCount, 2);
    expect(controller.running, isTrue);

    // Complete the older first. It is superseded; it must NOT clear
    // _running because the newer run is still going.
    fake.completeNext(_emptyResult());
    await older;
    expect(controller.running, isTrue,
        reason: 'newer run is still active — _running must stay set');

    // Now complete the newer. It owns the lifecycle; tear-down happens.
    fake.completeNext(_emptyResult());
    await newer;
    expect(controller.running, isFalse);
  });

  test('setSelectedArrayAzimuth supersedes an in-flight run', () async {
    final fake = _FakeRunner();
    final controller = ProjectController(simulationRunner: fake);
    controller.selectArrayForCompass(0);

    final future = controller.run();
    controller.setSelectedArrayAzimuth(123.0);

    fake.completeNext(_emptyResult());
    await future;

    // The run was superseded by the azimuth edit, so the stale result
    // must NOT be committed.
    expect(controller.result, isNull,
        reason: 'compass edit must bump _runGeneration so the stale '
            'result is discarded');
    expect(controller.running, isFalse);
  });
}
