// Native (Dart Native) implementation of the isolate-based run path.
// Selected by the conditional import in `simulation_runner.dart` when
// `dart.library.io` is available. Web builds get the stub in
// `simulation_runner_web.dart` instead, so `dart:isolate` is never
// imported into a tree-shaken web bundle.

import 'dart:async';
import 'dart:isolate';

import 'package:pv_engine/pv_engine.dart';

Future<SimulationResult> runSimulationOnIsolate(
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
