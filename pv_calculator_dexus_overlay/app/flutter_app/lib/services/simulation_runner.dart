import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pv_engine/pv_engine.dart';

// The isolate-based implementation lives in a platform-specific file
// selected by conditional import. On native (any Dart runtime with
// `dart:io`) we import the real isolate runner; on Flutter Web we
// import a stub that is never invoked because the `kIsWeb` branch in
// [SimulationRunner.run] always takes the in-process path. This split
// keeps `dart:isolate` out of the web build, where it is unavailable.
import 'simulation_runner_web.dart'
    if (dart.library.io) 'simulation_runner_io.dart' as platform;

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
    return platform.runSimulationOnIsolate(config, onProgress);
  }

  Future<SimulationResult> _runInProcess(
    SimulationConfig config,
    void Function(SimulationProgress)? onProgress,
  ) {
    // Run synchronously and wrap the result in a Future via `Future.sync`.
    // We previously hopped a microtask via `Future.delayed(Duration.zero)`
    // to give the UI one frame to render the "running" state before the
    // loop blocked. That microtask sits in flutter_test's fake-time
    // queue and never fires until `pumpAndSettle` runs — which the
    // test pattern only calls *after* `await controller.run()`, causing
    // a deadlock. The pre-render frame is a Web-only nicety; on native
    // we are on the isolate path anyway, and on Web the UI already
    // updated before this future was awaited via the `_running = true`
    // notification fired from the caller.
    return Future<SimulationResult>.sync(
      () => const PvSimulator().run(config, onProgress: onProgress),
    );
  }
}
