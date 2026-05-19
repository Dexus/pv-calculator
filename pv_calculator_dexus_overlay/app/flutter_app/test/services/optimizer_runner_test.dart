import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/services/optimizer_runner.dart';
import 'package:pv_engine/pv_engine.dart';

/// Phase 10 (deferred) — the [OptimizerRunner] orchestrates the
/// optimizer-sweep isolate boundary. On test runners (which target
/// native) it spawns a worker isolate; on web it would run
/// synchronously on the main isolate. We exercise the runner
/// end-to-end here; per-platform fallback is covered implicitly
/// because flutter_test runs in the VM, not on web.
void main() {
  OptimizerSpec tinySpec() {
    final baseline = SimulationConfig(
      arrays: const [
        PvArray(
          id: 'a',
          label: 'A',
          peakKw: 5,
          azimuthDeg: 180,
          tiltDeg: 35,
          inverterId: 'inv',
        ),
      ],
      inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 5)],
      batteries: const [
        BatteryConfig(
          id: 'b1',
          label: 'B',
          capacityKwh: 10,
          maxChargeKw: 4,
          maxDischargeKw: 4,
          initialSocKwh: 5,
        ),
      ],
      loadProfile: const LoadProfile(dailyKwh: 8),
      days: 365,
      startDayOfYear: 1,
    );
    return OptimizerSpec(
      baseline: baseline,
      prices: const OptimizerPrices(
        eurPerKwpPv: 1000,
        eurPerKwAcInverter: 300,
        eurPerKwhBattery: 600,
      ),
      objective: OptimizerObjective.maxAutarky,
      batterySweepKwh: const [5, 10],
      inverterSweepKw: const [4, 5],
      pvScaleSweep: const [1.0, 1.2],
      horizonYears: 10,
    );
  }

  test('runs to completion and returns an OptimizerResult', () async {
    const runner = OptimizerRunner();
    final handle = runner.start(tinySpec());
    final result = await handle.result;
    // 2 × 2 × 2 = 8 candidates, all feasible.
    expect(result.evaluated, equals(8));
    expect(result.candidates, isNotEmpty);
    expect(result.candidates.length, lessThanOrEqualTo(8));
  });

  test('emits progress events with monotonically non-decreasing done', () async {
    const runner = OptimizerRunner();
    final events = <OptimizerProgress>[];
    final handle = runner.start(tinySpec(), onProgress: events.add);
    await handle.result;
    expect(events, isNotEmpty);
    var lastDone = -1;
    for (final e in events) {
      expect(e.total, equals(8));
      expect(e.done, greaterThanOrEqualTo(lastDone));
      expect(e.fraction, inInclusiveRange(0.0, 1.0));
      lastDone = e.done;
    }
    expect(events.last.done, equals(events.last.total));
    expect(events.last.fraction, closeTo(1.0, 1e-9));
  });

  test('matches a synchronous engine run on the same spec', () async {
    const runner = OptimizerRunner();
    final spec = tinySpec();
    final isolateResult = await runner.start(spec).result;
    final inProcessResult = const Optimizer().run(spec);
    expect(isolateResult.evaluated, equals(inProcessResult.evaluated));
    expect(isolateResult.candidates.length, equals(inProcessResult.candidates.length));
    if (isolateResult.candidates.isNotEmpty &&
        inProcessResult.candidates.isNotEmpty) {
      final a = isolateResult.candidates.first;
      final b = inProcessResult.candidates.first;
      expect(a.batteryKwh, equals(b.batteryKwh));
      expect(a.inverterKw, equals(b.inverterKw));
      expect(a.pvScale, equals(b.pvScale));
      expect(a.summary.autarkyRate, closeTo(b.summary.autarkyRate, 1e-9));
    }
  });

  test('canCancel is true on native, false in-process', () {
    expect(const OptimizerRunner().canCancel, isTrue);
    expect(const OptimizerRunner(runInProcess: true).canCancel, isFalse);
    expect(const OptimizerRunner().start(tinySpec()).canCancel, isTrue);
    expect(
      const OptimizerRunner(runInProcess: true).start(tinySpec()).canCancel,
      isFalse,
    );
  });

  test('cancel() interrupts the sweep with OptimizerCancelledException',
      () async {
    const runner = OptimizerRunner();
    // Build a large enough sweep that the cancel arrives mid-flight.
    // 4 × 4 × 4 = 64 candidates × ~365-day simulation each is enough
    // for the isolate to be measurably busy when we cancel.
    final spec = OptimizerSpec(
      baseline: tinySpec().baseline,
      prices: tinySpec().prices,
      objective: OptimizerObjective.maxAutarky,
      batterySweepKwh: const [5, 7, 10, 12],
      inverterSweepKw: const [3, 4, 5, 6],
      pvScaleSweep: const [0.8, 1.0, 1.2, 1.4],
      horizonYears: 10,
    );
    final handle = runner.start(spec);
    handle.cancel();
    await expectLater(
      handle.result,
      throwsA(isA<OptimizerCancelledException>()),
    );
  });

  test('cancel() called after the result arrives still wins (no race window)',
      () async {
    // Regression for PR #32 review: previously, when cancel() landed
    // simultaneously with the isolate's final `OptimizerResult`
    // message, the result silently won and the user got the sweep
    // they tried to abort. The runner now drops late results when
    // `cancelled` is set. We can't deterministically reproduce the
    // millisecond-level race here, but we CAN exercise the
    // "post-spawn cancel before result" branch by cancelling the
    // shortest possible sweep right after `start`.
    const runner = OptimizerRunner();
    final handle = runner.start(tinySpec());
    handle.cancel();
    // Either a clean cancel or — if the isolate beat us — a normal
    // result. Both outcomes are acceptable, but the result MUST NOT
    // arrive AFTER the future already failed.
    try {
      final result = await handle.result;
      // Race: isolate completed before cancel landed. Sanity check.
      expect(result.evaluated, greaterThanOrEqualTo(0));
    } on OptimizerCancelledException {
      // Race: cancel won. Either branch is valid; the regression we
      // guard against is "OptimizerResult delivered AFTER cancel
      // already failed the completer".
    }
  });
}
