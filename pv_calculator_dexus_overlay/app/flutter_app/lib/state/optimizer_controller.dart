import 'package:flutter/foundation.dart';
import 'package:pv_engine/pv_engine.dart';

import '../services/optimizer_runner.dart';
import 'config_draft.dart';

/// Wraps the pure-Dart [Optimizer] for the Flutter app. Holds the most
/// recent spec / result and exposes a single [runFromDraft] entry point
/// that builds the baseline from the active [ConfigDraft] via
/// [ConfigDraft.buildForRun] (so Pro gates are applied identically to
/// a normal Run).
///
/// The sweep is dispatched through an [OptimizerRunner], which spawns a
/// worker isolate on native and runs in-process on web. The controller
/// exposes per-candidate [progress] from the engine's
/// `onProgress(done, total)` callback so the UI can render a determinate
/// progress bar, plus [cancel] / [canCancel] hooks that work on native.
class OptimizerController extends ChangeNotifier {
  OptimizerController({OptimizerRunner? optimizerRunner})
      : _runner = optimizerRunner ?? const OptimizerRunner();

  final OptimizerRunner _runner;

  OptimizerSpec? _lastSpec;
  OptimizerResult? _lastResult;
  bool _running = false;
  String? _lastError;
  OptimizerProgress? _progress;
  OptimizerRunHandle? _currentHandle;
  bool _cancelled = false;

  OptimizerSpec? get lastSpec => _lastSpec;
  OptimizerResult? get lastResult => _lastResult;
  bool get running => _running;
  String? get lastError => _lastError;
  OptimizerProgress? get progress => _progress;
  bool get cancelled => _cancelled;

  /// `true` when the active runner supports preemption (native isolate)
  /// AND a sweep is currently running. The UI uses this to decide
  /// whether to enable the Cancel button.
  bool get canCancel => _running && (_currentHandle?.canCancel ?? false);

  /// Runs the optimizer using [draft] as the baseline (via
  /// [ConfigDraft.buildForRun] so Pro gating is honoured) and the
  /// sweep / pricing / objective from [spec]. The `baseline` field on
  /// [spec] is ignored — the draft is always the source of truth.
  Future<void> runFromDraft(ConfigDraft draft, OptimizerSpec spec) async {
    if (_running) return;
    _running = true;
    _lastError = null;
    _cancelled = false;
    _progress = const OptimizerProgress(done: 0, total: 0);
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
      final handle = _runner.start(
        effectiveSpec,
        onProgress: (p) {
          _progress = p;
          notifyListeners();
        },
      );
      _currentHandle = handle;
      _lastResult = await handle.result;
    } on OptimizerCancelledException {
      _cancelled = true;
      _lastResult = null;
    } on ArgumentError catch (e) {
      _lastError = e.message?.toString() ?? e.toString();
      _lastResult = null;
    } catch (e) {
      _lastError = e.toString();
      _lastResult = null;
    } finally {
      _running = false;
      _progress = null;
      _currentHandle = null;
      notifyListeners();
    }
  }

  /// Aborts the active sweep when the runner supports it. No-op on web /
  /// in-process — see [canCancel].
  void cancel() {
    final handle = _currentHandle;
    if (!_running || handle == null || !handle.canCancel) return;
    handle.cancel();
  }

  /// Clears the most recent run state without resetting the spec the
  /// user is editing.
  void clearResult() {
    if (_lastResult == null && _lastError == null && !_cancelled) return;
    _lastResult = null;
    _lastError = null;
    _cancelled = false;
    notifyListeners();
  }
}
