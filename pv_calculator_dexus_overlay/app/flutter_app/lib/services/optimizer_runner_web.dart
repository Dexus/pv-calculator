// Web-only stub. Flutter Web has no isolates, so the
// [OptimizerRunner.start] entry point always takes the in-process branch.
// This file exists only to satisfy the conditional import in
// `optimizer_runner.dart` — calling `startOptimizerOnIsolate` here is a
// programming error (the runner's web branch never dispatches to it).

import 'package:pv_engine/pv_engine.dart';

import 'optimizer_runner.dart';

OptimizerRunHandle startOptimizerOnIsolate(
  OptimizerSpec spec,
  void Function(OptimizerProgress)? onProgress,
) {
  throw UnsupportedError(
    'Isolate-based optimizer sweep is not supported on Flutter Web. '
    'OptimizerRunner should have taken the in-process branch.',
  );
}
