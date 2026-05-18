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
