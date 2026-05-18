import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:pv_engine/pv_engine.dart';

/// Runs the simulation off the UI thread when possible.
///
/// On native platforms (Android/iOS/desktop) the simulator is hosted by a
/// worker `Isolate` so the main isolate stays free to render. Progress
/// events arrive on the main isolate via a `ReceivePort` and are surfaced
/// through [onProgress]. On Flutter Web — where isolates are not
/// available — the simulator runs on the main isolate; the progress
/// callback still fires for UI symmetry, but the loop blocks the JS
/// event queue while running.
///
/// The engine itself (`package:pv_engine`) stays Flutter- and isolate-free
/// — this class is the *only* place the boundary is drawn.
class SimulationRunner {
  const SimulationRunner({this.runInProcess = false});

  /// When `true`, the simulator always runs on the calling isolate.
  /// Tests set this to keep `pumpAndSettle`'s fake-time loop from racing
  /// the real-time isolate spawn/teardown. Production code leaves it
  /// `false` so the runner picks the isolate path on native and the
  /// in-process path on web automatically.
  final bool runInProcess;

  Future<SimulationResult> run(
    SimulationConfig config, {
    void Function(SimulationProgress)? onProgress,
  }) {
    if (kIsWeb || runInProcess) {
      return _runInProcess(config, onProgress);
    }
    return _runOnIsolate(config, onProgress);
  }

  Future<SimulationResult> _runInProcess(
    SimulationConfig config,
    void Function(SimulationProgress)? onProgress,
  ) async {
    // Hop one microtask so the caller can render the "running" state
    // before the synchronous loop kicks off.
    await Future<void>.delayed(Duration.zero);
    return const PvSimulator().run(config, onProgress: onProgress);
  }

  Future<SimulationResult> _runOnIsolate(
    SimulationConfig config,
    void Function(SimulationProgress)? onProgress,
  ) async {
    final receivePort = ReceivePort();
    final completer = Completer<SimulationResult>();
    Isolate? isolate;

    final sub = receivePort.listen((message) {
      if (message is SimulationProgress) {
        onProgress?.call(message);
        return;
      }
      if (message is SimulationResult) {
        if (!completer.isCompleted) completer.complete(message);
        return;
      }
      if (message is _IsolateError) {
        if (!completer.isCompleted) {
          completer.completeError(message.toException(), message.stackTrace);
        }
        return;
      }
      // `onError: receivePort.sendPort` delivers uncaught isolate errors
      // as a 2-element list `[String error, String stackTrace]`. If one
      // reaches us before the in-isolate catch in `_runEntry` had a
      // chance to wrap it, fail the future instead of dropping it.
      if (message is List && message.length == 2) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(message[0]?.toString() ?? 'Isolate error'),
            StackTrace.fromString(message[1]?.toString() ?? ''),
          );
        }
        return;
      }
      // `onExit: receivePort.sendPort` delivers `null` when the isolate
      // exits — including normal exits, where the result has already
      // been sent and the completer is done. We only need to act if the
      // isolate exited without delivering a result or an error.
      if (message == null) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('Simulation isolate exited without a result.'),
          );
        }
        return;
      }
    });

    try {
      isolate = await Isolate.spawn<_IsolateArgs>(
        _runEntry,
        _IsolateArgs(receivePort.sendPort, config),
        errorsAreFatal: true,
        onError: receivePort.sendPort,
        onExit: receivePort.sendPort,
      );
      return await completer.future;
    } finally {
      await sub.cancel();
      receivePort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }
}

class _IsolateArgs {
  const _IsolateArgs(this.sendPort, this.config);
  final SendPort sendPort;
  final SimulationConfig config;
}

class _IsolateError {
  const _IsolateError(this.message, this.stackTrace);
  final String message;
  final StackTrace stackTrace;

  Exception toException() => Exception(message);
}

void _runEntry(_IsolateArgs args) {
  try {
    final result = const PvSimulator().run(
      args.config,
      onProgress: args.sendPort.send,
    );
    args.sendPort.send(result);
  } catch (e, st) {
    args.sendPort.send(_IsolateError(e.toString(), st));
  }
}
