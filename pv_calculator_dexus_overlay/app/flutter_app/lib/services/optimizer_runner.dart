import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pv_engine/pv_engine.dart';

// Platform-specific isolate implementation, selected by conditional
// import. Same shape as `simulation_runner.dart`: on native (any Dart
// runtime with `dart:io`) we pull in the real isolate runner; on
// Flutter Web we pull in a stub that is never invoked because the
// `kIsWeb` branch in [OptimizerRunner.start] always takes the
// in-process path. This split keeps `dart:isolate` out of the web
// bundle, where it would otherwise be unavailable.
import 'optimizer_runner_web.dart'
    if (dart.library.io) 'optimizer_runner_io.dart' as platform;

/// Per-candidate progress event emitted by `Optimizer.run` and surfaced
/// to the UI by [OptimizerRunner].
///
/// `done == total` when the sweep finishes. `total >= 1` always — the
/// engine falls every empty sweep dimension back to a single baseline
/// value, so the Cartesian product can't collapse to zero candidates.
/// The `fraction` getter still guards `total <= 0` defensively so a
/// future engine change can't divide by zero.
@immutable
class OptimizerProgress {
  const OptimizerProgress({required this.done, required this.total});

  final int done;
  final int total;

  double get fraction {
    if (total <= 0) return 0;
    final f = done / total;
    if (f < 0) return 0;
    if (f > 1) return 1;
    return f;
  }
}

/// Thrown by the [OptimizerRunHandle.result] future when the caller
/// cancels the sweep via [OptimizerRunHandle.cancel]. Distinct from
/// engine `ArgumentError`s so the controller can surface a "Abbrechen"
/// state instead of an "Error: …" string.
class OptimizerCancelledException implements Exception {
  const OptimizerCancelledException();
  @override
  String toString() => 'OptimizerCancelledException';
}

/// Handle returned by [OptimizerRunner.start]. Holds the pending
/// [result] future plus a [cancel] hook for native sweeps.
class OptimizerRunHandle {
  OptimizerRunHandle({
    required this.result,
    required void Function() onCancel,
    required this.canCancel,
  }) : _onCancel = onCancel;

  final Future<OptimizerResult> result;
  final void Function() _onCancel;

  /// `true` when [cancel] will actually interrupt the sweep (native
  /// isolate path). `false` on web / in-process — there is no
  /// preemption point inside `Optimizer.run`.
  final bool canCancel;

  void cancel() => _onCancel();
}

/// Runs an [OptimizerSpec] sweep off the UI thread when possible.
///
/// On native platforms a worker `Isolate` hosts the sweep so the main
/// isolate stays free to render. Progress events arrive on the main
/// isolate via a `ReceivePort` and are surfaced through `onProgress`.
/// On Flutter Web — where isolates are not available — the sweep runs
/// on the main isolate; progress events still fire (the engine's
/// `onProgress(done, total)` callback drives them synchronously between
/// candidates), but cancellation is not possible because Dart can't
/// interrupt a synchronous loop on the same isolate.
///
/// The engine itself (`package:pv_engine`) stays Flutter- and
/// isolate-free — this class is the *only* place the boundary is drawn.
class OptimizerRunner {
  const OptimizerRunner({this.runInProcess = false});

  /// When `true`, the sweep always runs on the calling isolate. Tests
  /// that exercise the controller against `flutter_test`'s fake-time
  /// clock set this `true` to avoid racing real-time isolate
  /// spawn/teardown. Production code leaves it `false`.
  final bool runInProcess;

  /// `true` when this runner uses a worker isolate (native, not
  /// `runInProcess`). The UI uses this to decide whether to render a
  /// working Cancel button.
  bool get canCancel => !kIsWeb && !runInProcess;

  OptimizerRunHandle start(
    OptimizerSpec spec, {
    void Function(OptimizerProgress)? onProgress,
  }) {
    if (kIsWeb || runInProcess) {
      return _startInProcess(spec, onProgress);
    }
    return platform.startOptimizerOnIsolate(spec, onProgress);
  }

  OptimizerRunHandle _startInProcess(
    OptimizerSpec spec,
    void Function(OptimizerProgress)? onProgress,
  ) {
    // Wrap the synchronous sweep in `Future.sync` so the caller gets a
    // future they can await; the engine's onProgress callback fires
    // between candidates and we forward it as `OptimizerProgress`.
    //
    // Deliberately NO `Future.delayed(Duration.zero)` here, even though
    // the pre-runner controller had one: the same trade-off as
    // `SimulationRunner._runInProcess` applies. Yielding a microtask
    // before the sweep would deadlock `flutter_test`'s fake-time clock
    // (the timer never fires until `pumpAndSettle`, which the call
    // pattern only invokes after `await controller.runFromDraft`). The
    // pre-sweep "running" repaint is a Web-only nicety; on native the
    // isolate path applies. Mid-sweep progress paints are unreachable
    // on Web regardless of yielding (the synchronous loop blocks the
    // event loop). The lost paint is the same single "Optimierung läuft …"
    // frame the pre-runner code rendered before its sweep started.
    final future = Future<OptimizerResult>.sync(
      () => const Optimizer().run(
        spec,
        onProgress: onProgress == null
            ? null
            : (done, total) =>
                onProgress(OptimizerProgress(done: done, total: total)),
      ),
    );
    return OptimizerRunHandle(
      result: future,
      onCancel: () {},
      canCancel: false,
    );
  }
}
