import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Phase 9 — C2: the engine emits [SimulationProgress] on day boundaries
/// when an `onProgress` callback is supplied. The events let the app
/// drive a progress bar from across an isolate boundary; the engine itself
/// adds no `dart:async`, `package:flutter`, or `Isolate` dependency.
void main() {
  SimulationConfig baseConfig({
    int preRunDays = 0,
    PreRunMode mode = PreRunMode.singleWarmUp,
    int days = 7,
  }) =>
      SimulationConfig(
        arrays: const [
          PvArray(id: 'a', label: 'A', peakKw: 5, azimuthDeg: 180, tiltDeg: 35, inverterId: 'inv'),
        ],
        inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 5)],
        loadProfile: const LoadProfile(dailyKwh: 8),
        startDayOfYear: 1,
        days: days,
        preRunDays: preRunDays,
        preRunMode: mode,
      );

  test('reporting phase emits one event per day (no pre-run)', () {
    final events = <SimulationProgress>[];
    const PvSimulator().run(baseConfig(days: 5), onProgress: events.add);

    expect(events, hasLength(5));
    for (var i = 0; i < events.length; i++) {
      expect(events[i].phase, SimulationPhase.reporting);
      expect(events[i].completedDays, i + 1);
      expect(events[i].totalDays, 5);
      expect(events[i].iteration, 1);
    }
    expect(events.last.fraction, 1.0);
  });

  test('pre-run + reporting emit in order, with different phases', () {
    final events = <SimulationProgress>[];
    const PvSimulator().run(
      baseConfig(preRunDays: 3, days: 4),
      onProgress: events.add,
    );

    expect(events, hasLength(7));
    expect(events.take(3).every((e) => e.phase == SimulationPhase.preRun), isTrue);
    expect(events.skip(3).every((e) => e.phase == SimulationPhase.reporting), isTrue);
    expect(events[2].completedDays, 3);
    expect(events[2].totalDays, 3);
    expect(events.last.completedDays, 4);
    expect(events.last.totalDays, 4);
  });

  test('cyclic convergence reports iteration index on each event', () {
    final cfg = SimulationConfig(
      arrays: const [
        PvArray(id: 'a', label: 'A', peakKw: 5, azimuthDeg: 180, tiltDeg: 35, inverterId: 'inv'),
      ],
      inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 5)],
      batteries: const [
        BatteryConfig(id: 'b', capacityKwh: 8, maxChargeKw: 3, maxDischargeKw: 3),
      ],
      loadProfile: const LoadProfile(dailyKwh: 8),
      preRunMode: PreRunMode.cyclicConvergence,
      maxConvergenceIterations: 2,
      // Tighten tolerance so the loop is forced to a second iteration.
      convergenceToleranceFraction: 1e-12,
    );

    final events = <SimulationProgress>[];
    const PvSimulator().run(cfg, onProgress: events.add);

    final iterations = events.map((e) => e.iteration).toSet();
    expect(iterations, containsAll(<int>[1, 2]));
    expect(events.every((e) => e.phase == SimulationPhase.reporting), isTrue);
  });

  test('omitting onProgress preserves legacy behaviour (no callbacks)', () {
    // Sanity: the call site shouldn't break without a callback. We can't
    // observe "nothing fires" directly, but we can run a year and check
    // the result is unchanged from the parameterless invocation.
    final r1 = const PvSimulator().run(baseConfig(days: 30));
    final r2 = const PvSimulator().run(baseConfig(days: 30), onProgress: null);
    expect(r2.summary.pvAcKwh, closeTo(r1.summary.pvAcKwh, 1e-12));
  });
}
