import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/services/optimizer_runner.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/optimizer_controller.dart';
import 'package:pv_engine/pv_engine.dart';

/// Controller-level checks for the bits of the runner contract that
/// flutter_test can't observe through the page (the "running" frame
/// is gone before pump renders): progress propagation, cancellation
/// state, and that the `canCancel` flag mirrors the injected runner.
void main() {
  ConfigDraft tinyDraft() => ConfigDraft(
        arrays: [
          PvArrayDraft(
            id: 'a',
            label: 'A',
            peakKw: 5.0,
            azimuthDeg: 180,
            tiltDeg: 30,
            inverterId: 'inv',
          ),
        ],
        inverters: [
          InverterDraft(id: 'inv', label: 'Inv', maxAcKw: 5.0),
        ],
        batteries: [
          BatteryDraft(
            id: 'b',
            label: 'B',
            capacityKwh: 5.0,
            maxChargeKw: 2.5,
            maxDischargeKw: 2.5,
          ),
        ],
        loadProfile: LoadProfileDraft(dailyKwh: 8.0),
        days: 1,
      );

  OptimizerSpec dummySpec(SimulationConfig baseline) => OptimizerSpec(
        baseline: baseline,
        prices: const OptimizerPrices(
          eurPerKwpPv: 1000,
          eurPerKwAcInverter: 300,
          eurPerKwhBattery: 600,
        ),
        objective: OptimizerObjective.maxAutarky,
        batterySweepKwh: const [5, 10],
        inverterSweepKw: const [4, 5],
        pvScaleSweep: const [1.0],
      );

  test('runFromDraft surfaces progress events and clears them on completion',
      () async {
    final controller = OptimizerController(
      optimizerRunner: const OptimizerRunner(runInProcess: true),
    );
    final progresses = <OptimizerProgress>[];
    controller.addListener(() {
      final p = controller.progress;
      if (p != null) progresses.add(p);
    });

    final draft = tinyDraft();
    await controller.runFromDraft(draft, dummySpec(draft.buildForRun()));

    expect(progresses, isNotEmpty);
    // Every observed event must have valid bounds; last one is the
    // "done == total" tick the engine emits at the end of the loop.
    for (final p in progresses) {
      expect(p.done, greaterThanOrEqualTo(0));
      expect(p.done, lessThanOrEqualTo(p.total));
    }
    expect(progresses.last.done, equals(progresses.last.total));

    // After completion the controller resets progress.
    expect(controller.progress, isNull);
    expect(controller.running, isFalse);
    expect(controller.lastResult, isNotNull);
    expect(controller.cancelled, isFalse);
  });

  test('cancel() on an in-process runner is a no-op (canCancel == false)',
      () async {
    final controller = OptimizerController(
      optimizerRunner: const OptimizerRunner(runInProcess: true),
    );
    final draft = tinyDraft();
    final future = controller.runFromDraft(draft, dummySpec(draft.buildForRun()));
    // Calling cancel on an in-process runner must not throw and must
    // not flip the cancelled state — it's a documented no-op.
    controller.cancel();
    await future;
    expect(controller.cancelled, isFalse);
    expect(controller.lastResult, isNotNull);
  });

  test('cancel() surfaces OptimizerCancelledException as cancelled state',
      () async {
    final controller = OptimizerController(
      optimizerRunner: _FakeCancellingRunner(),
    );
    final draft = tinyDraft();
    final future = controller.runFromDraft(draft, dummySpec(draft.buildForRun()));
    // canCancel transitions true → cancel works → controller settles
    // in the cancelled state without a result or an error string.
    expect(controller.canCancel, isTrue);
    controller.cancel();
    await future;
    expect(controller.cancelled, isTrue);
    expect(controller.lastResult, isNull);
    expect(controller.lastError, isNull);
    expect(controller.running, isFalse);
    expect(controller.canCancel, isFalse);
  });

  test('clearResult resets the cancelled flag too', () async {
    final controller = OptimizerController(
      optimizerRunner: _FakeCancellingRunner(),
    );
    final draft = tinyDraft();
    final future = controller.runFromDraft(draft, dummySpec(draft.buildForRun()));
    controller.cancel();
    await future;
    expect(controller.cancelled, isTrue);
    controller.clearResult();
    expect(controller.cancelled, isFalse);
  });

  test('runFromDraft forwards discountRatePct and priceEscalationPctPerYear',
      () async {
    final runner = _RecordingRunner();
    final controller = OptimizerController(optimizerRunner: runner);
    final draft = tinyDraft();
    final spec = OptimizerSpec(
      baseline: draft.buildForRun(),
      prices: const OptimizerPrices(),
      objective: OptimizerObjective.maxAutarky,
      batterySweepKwh: const [5.0],
      inverterSweepKw: const [5.0],
      pvScaleSweep: const [1.0],
      discountRatePct: 4.0,
      priceEscalationPctPerYear: 2.5,
    );
    await controller.runFromDraft(draft, spec);
    expect(runner.lastSpec, isNotNull);
    expect(runner.lastSpec!.discountRatePct, equals(4.0));
    expect(runner.lastSpec!.priceEscalationPctPerYear, equals(2.5));
  });

  test('supersede drops a late-arriving result from an older generation',
      () async {
    final runner = _ManualRunner();
    final controller = OptimizerController(optimizerRunner: runner);
    final draft = tinyDraft();
    final future = controller.runFromDraft(draft, dummySpec(draft.buildForRun()));
    expect(controller.running, isTrue);

    // User navigates away mid-sweep — page dispose calls supersede.
    controller.supersede();
    expect(controller.running, isFalse);
    // The fake runner saw the cancel and reports cancellation.
    expect(runner.cancelCalls, equals(1));

    // Now the (formerly cancelled) handle reports a result. Because
    // the generation has advanced, the result must NOT land on the
    // controller — it would clobber the cleared state otherwise.
    runner.deliverResult();
    await future;
    expect(controller.lastResult, isNull);
    expect(controller.cancelled, isFalse);
    expect(controller.running, isFalse);
  });
}

/// Test double — gives the test direct control over when the run
/// completes. The handle never resolves on its own; the test calls
/// `deliverResult()` (success) or `deliverCancel()` (cancellation).
class _ManualRunner implements OptimizerRunner {
  Completer<OptimizerResult>? _completer;
  int cancelCalls = 0;

  @override
  bool get canCancel => true;

  @override
  bool get runInProcess => false;

  @override
  OptimizerRunHandle start(
    OptimizerSpec spec, {
    void Function(OptimizerProgress)? onProgress,
  }) {
    final c = Completer<OptimizerResult>();
    _completer = c;
    return OptimizerRunHandle(
      result: c.future,
      onCancel: () {
        cancelCalls++;
        if (!c.isCompleted) {
          c.completeError(const OptimizerCancelledException());
        }
      },
      canCancel: true,
    );
  }

  void deliverResult() {
    final c = _completer;
    if (c == null || c.isCompleted) return;
    c.complete(const OptimizerResult(
      candidates: [],
      evaluated: 0,
      skippedOverBudget: 0,
      failedValidation: 0,
    ));
  }
}

/// Test double — captures the effective [OptimizerSpec] the controller
/// hands to the runner and returns an empty result so the run settles
/// synchronously. Lets the test assert on the spec without running the
/// engine.
class _RecordingRunner implements OptimizerRunner {
  OptimizerSpec? lastSpec;

  @override
  bool get canCancel => false;

  @override
  bool get runInProcess => true;

  @override
  OptimizerRunHandle start(
    OptimizerSpec spec, {
    void Function(OptimizerProgress)? onProgress,
  }) {
    lastSpec = spec;
    return OptimizerRunHandle(
      result: Future.value(const OptimizerResult(
        candidates: [],
        evaluated: 0,
        skippedOverBudget: 0,
        failedValidation: 0,
      )),
      onCancel: () {},
      canCancel: false,
    );
  }
}

/// Test double — pretends to be a cancellable native runner. On
/// `start()` it returns a handle whose future never completes on its
/// own; `cancel()` errors the future with [OptimizerCancelledException].
class _FakeCancellingRunner implements OptimizerRunner {
  @override
  bool get canCancel => true;

  @override
  bool get runInProcess => false;

  @override
  OptimizerRunHandle start(
    OptimizerSpec spec, {
    void Function(OptimizerProgress)? onProgress,
  }) {
    final completer = Completer<OptimizerResult>();
    return OptimizerRunHandle(
      result: completer.future,
      onCancel: () {
        if (!completer.isCompleted) {
          completer.completeError(const OptimizerCancelledException());
        }
      },
      canCancel: true,
    );
  }
}
