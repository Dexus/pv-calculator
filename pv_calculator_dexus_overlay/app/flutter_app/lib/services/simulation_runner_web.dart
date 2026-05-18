// Web-only stub. Flutter Web has no isolates, so the
// [SimulationRunner.run] entry point always takes the in-process branch.
// This file exists only to satisfy the conditional import in
// `simulation_runner.dart` — calling `runSimulationOnIsolate` here is a
// programming error (the runner's web branch never dispatches to it).

import 'package:pv_engine/pv_engine.dart';

Future<SimulationResult> runSimulationOnIsolate(
  SimulationConfig config,
  void Function(SimulationProgress)? onProgress,
) {
  throw UnsupportedError(
    'Isolate-based simulation is not supported on Flutter Web. '
    'SimulationRunner should have taken the in-process branch.',
  );
}
