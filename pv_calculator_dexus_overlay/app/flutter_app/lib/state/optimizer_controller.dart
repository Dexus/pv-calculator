import 'package:flutter/foundation.dart';
import 'package:pv_engine/pv_engine.dart';

import 'config_draft.dart';

/// Wraps the pure-Dart [Optimizer] for the Flutter app. Holds the most
/// recent spec / result and exposes a single [runFromDraft] entry point
/// that builds the baseline from the active [ConfigDraft] via
/// [ConfigDraft.buildForRun] (so Pro gates are applied identically to
/// a normal Run).
///
/// For Phase 10 MVP the sweep runs in-process on the calling isolate.
/// Each candidate uses `keepSteps: false` and `simulationYears: 1` so a
/// 100-candidate sweep finishes in the low-seconds range on hourly
/// steps. The UI shows an indeterminate progress indicator while the
/// synchronous loop runs — there is no mid-sweep repaint because
/// [Optimizer.run] is synchronous Dart code that blocks the event
/// loop. Moving the sweep to `dart:isolate` is captured as a deferred
/// item in the roadmap.
class OptimizerController extends ChangeNotifier {
  OptimizerSpec? _lastSpec;
  OptimizerResult? _lastResult;
  bool _running = false;
  String? _lastError;

  OptimizerSpec? get lastSpec => _lastSpec;
  OptimizerResult? get lastResult => _lastResult;
  bool get running => _running;
  String? get lastError => _lastError;

  /// Runs the optimizer using [draft] as the baseline (via
  /// [ConfigDraft.buildForRun] so Pro gating is honoured) and the
  /// sweep / pricing / objective from [spec]. The `baseline` field on
  /// [spec] is ignored — the draft is always the source of truth.
  Future<void> runFromDraft(ConfigDraft draft, OptimizerSpec spec) async {
    if (_running) return;
    _running = true;
    _lastError = null;
    notifyListeners();
    try {
      final baseline = draft.buildForRun();
      final effectiveSpec = OptimizerSpec(
        baseline: baseline,
        prices: spec.prices,
        objective: spec.objective,
        batterySweepKwh: spec.batterySweepKwh,
        inverterSweepKw: spec.inverterSweepKw,
        pvScaleSweep: spec.pvScaleSweep,
        optionalArrayIds: spec.optionalArrayIds,
        budgetEur: spec.budgetEur,
        horizonYears: spec.horizonYears,
        topN: spec.topN,
      );
      _lastSpec = effectiveSpec;
      // One yield before the synchronous sweep so the "running" state
      // paints. The sweep itself blocks the event loop — indeterminate
      // progress is honest about that.
      await Future<void>.delayed(Duration.zero);
      _lastResult = const Optimizer().run(effectiveSpec);
    } on ArgumentError catch (e) {
      _lastError = e.message?.toString() ?? e.toString();
      _lastResult = null;
    } catch (e) {
      _lastError = e.toString();
      _lastResult = null;
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  /// Clears the most recent run state without resetting the spec the
  /// user is editing.
  void clearResult() {
    if (_lastResult == null && _lastError == null) return;
    _lastResult = null;
    _lastError = null;
    notifyListeners();
  }
}
