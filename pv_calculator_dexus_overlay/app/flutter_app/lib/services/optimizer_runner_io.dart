// Native (Dart Native) implementation of the isolate-based Optimizer
// sweep. Selected by the conditional import in `optimizer_runner.dart`
// when `dart.library.io` is available. Web builds get the stub in
// `optimizer_runner_web.dart` instead, so `dart:isolate` is never
// imported into a tree-shaken web bundle.

import 'dart:async';
import 'dart:isolate';

import 'package:pv_engine/pv_engine.dart';

import 'optimizer_runner.dart';

OptimizerRunHandle startOptimizerOnIsolate(
  OptimizerSpec spec,
  void Function(OptimizerProgress)? onProgress,
) {
  final receivePort = ReceivePort();
  final completer = Completer<OptimizerResult>();
  Isolate? isolate;
  var cancelled = false;

  final sub = receivePort.listen((message) {
    if (message is OptimizerProgress) {
      // Drop progress events from a sweep we already cancelled — the
      // isolate is racing the kill signal.
      if (cancelled || completer.isCompleted) return;
      onProgress?.call(message);
      return;
    }
    if (message is OptimizerResult) {
      if (completer.isCompleted) return;
      // If cancel() was called while the isolate was still finishing
      // its last candidate, the result arrived AFTER the kill signal
      // was sent (or before it could land). Drop the late result and
      // surface the cancellation instead — the user explicitly asked
      // for the sweep to be aborted, so returning the now-stale top-N
      // would be surprising.
      if (cancelled) {
        completer.completeError(const OptimizerCancelledException());
      } else {
        completer.complete(message);
      }
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
    // exits. Three cases:
    //   1) Result already delivered — completer done, ignore.
    //   2) Cancelled — fail with [OptimizerCancelledException] so the
    //      controller can surface a dedicated "abgebrochen" state.
    //   3) Exit before result and not cancelled — programming bug,
    //      fail with StateError.
    if (message == null) {
      if (!completer.isCompleted) {
        completer.completeError(
          cancelled
              ? const OptimizerCancelledException()
              : StateError('Optimizer isolate exited without a result.'),
        );
      }
      return;
    }
  });

  final resultFuture = () async {
    try {
      isolate = await Isolate.spawn<_IsolateArgs>(
        _runEntry,
        _IsolateArgs(receivePort.sendPort, spec),
        errorsAreFatal: true,
        onError: receivePort.sendPort,
        onExit: receivePort.sendPort,
      );
      // Cancel may have fired between `start()` returning and the
      // spawn completing — `isolate` was null at that point so the
      // kill was a no-op. Now that we have the handle, honour the
      // pending cancellation before awaiting any messages.
      if (cancelled) {
        isolate?.kill(priority: Isolate.immediate);
        throw const OptimizerCancelledException();
      }
      return await completer.future;
    } finally {
      await sub.cancel();
      receivePort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }();

  return OptimizerRunHandle(
    result: resultFuture,
    onCancel: () {
      if (cancelled || completer.isCompleted) return;
      cancelled = true;
      // Best-effort kill. If the isolate has already spawned, the
      // resulting `onExit` → `null` message lets the listener
      // complete the future with [OptimizerCancelledException]. If
      // the spawn hasn't completed yet, the post-spawn check above
      // raises the same exception once `Isolate.spawn` returns.
      isolate?.kill(priority: Isolate.immediate);
    },
    canCancel: true,
  );
}

class _IsolateArgs {
  const _IsolateArgs(this.sendPort, this.spec);
  final SendPort sendPort;
  final OptimizerSpec spec;
}

class _IsolateError {
  const _IsolateError(this.message, this.stackTrace);
  final String message;
  final StackTrace stackTrace;

  Exception toException() => Exception(message);
}

void _runEntry(_IsolateArgs args) {
  try {
    final result = const Optimizer().run(
      args.spec,
      onProgress: (done, total) =>
          args.sendPort.send(OptimizerProgress(done: done, total: total)),
    );
    args.sendPort.send(result);
  } catch (e, st) {
    args.sendPort.send(_IsolateError(e.toString(), st));
  }
}
