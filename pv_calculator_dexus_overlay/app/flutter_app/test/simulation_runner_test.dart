import 'package:pv_calculator_app/services/simulation_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_engine/pv_engine.dart';

/// Phase 9 — C2: the [SimulationRunner] orchestrates the isolate
/// boundary. On test runners (which target native) it spawns a worker
/// isolate; on web it would run synchronously on the main isolate.
/// We exercise the runner end-to-end here; per-platform fallback is
/// covered implicitly because flutter_test runs in the VM, not on web.
void main() {
  SimulationConfig demoConfig({int days = 7}) => SimulationConfig(
        arrays: const [
          PvArray(id: 'a', label: 'A', peakKw: 5, azimuthDeg: 180, tiltDeg: 35, inverterId: 'inv'),
        ],
        inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 5)],
        loadProfile: const LoadProfile(dailyKwh: 8),
        days: days,
        startDayOfYear: 1,
      );

  test('runs to completion and returns a SimulationResult', () async {
    const runner = SimulationRunner();
    final result = await runner.run(demoConfig());
    expect(result.steps, hasLength(7 * 24));
    expect(result.summary.pvAcKwh, greaterThan(0));
  });

  test('emits progress events with monotonically increasing fraction', () async {
    const runner = SimulationRunner();
    final events = <SimulationProgress>[];
    await runner.run(demoConfig(days: 5), onProgress: events.add);

    expect(events, isNotEmpty);
    var lastFraction = -1.0;
    for (final e in events) {
      expect(e.fraction, greaterThanOrEqualTo(lastFraction));
      lastFraction = e.fraction;
    }
    expect(events.last.fraction, closeTo(1.0, 1e-9));
  });

  test('matches a synchronous engine run on the same config', () async {
    const runner = SimulationRunner();
    final cfg = demoConfig(days: 14);
    final isolateRun = await runner.run(cfg);
    final inProcessRun = const PvSimulator().run(cfg);

    expect(isolateRun.summary.pvAcKwh, closeTo(inProcessRun.summary.pvAcKwh, 1e-9));
    expect(isolateRun.summary.gridExportKwh, closeTo(inProcessRun.summary.gridExportKwh, 1e-9));
    expect(isolateRun.steps.length, inProcessRun.steps.length);
  });
}
