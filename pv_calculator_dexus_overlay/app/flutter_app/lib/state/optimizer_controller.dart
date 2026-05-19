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
///
/// Listener notifications are throttled to integer-percent transitions
/// (≤ 101 per run) so a maximal sweep (~27 k candidates on the documented
/// dimension caps) doesn't queue thousands of back-to-back Provider
/// rebuilds. The pattern mirrors `ProjectController._lastNotifiedPct`.
///
/// A monotonic generation counter (`_runGeneration`) guards stale
/// commits. With the native isolate path a sweep can keep running while
/// the user navigates away and edits the draft — we drop the result
/// instead of clobbering newer state.
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

  /// Bumped at each [runFromDraft] entry and used to discard the result
  /// of any in-flight run whose generation has since moved on.
  int _runGeneration = 0;

  /// Last whole-percent fraction we notified listeners about during the
  /// current run. Reset on every fresh run start. Throttles per-candidate
  /// progress notifications so a maximal sweep yields ~100 Provider
  /// rebuilds instead of `total` ones.
  int _lastNotifiedPct = -1;

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
    _lastNotifiedPct = -1;
    final generation = ++_runGeneration;
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
        discountRatePct: spec.discountRatePct,
        priceEscalationPctPerYear: spec.priceEscalationPctPerYear,
        topN: spec.topN,
      );
      _lastSpec = effectiveSpec;
      final handle = _runner.start(
        effectiveSpec,
        onProgress: (p) {
          // Drop progress events from a superseded run so the UI
          // doesn't see a half-finished bar from an aborted sweep.
          if (generation != _runGeneration) return;
          _progress = p;
          // Throttle notify cadence to whole-percent transitions. A
          // maximal sweep (12 × 12 × 12 × 16 = 27 648 candidates) would
          // otherwise drive 27 k Provider rebuilds per run; with the
          // throttle the maximum is `total // (total/100) + 1` ≈ 101.
          final pct = p.total <= 0
              ? 100
              : (p.done * 100) ~/ p.total;
          if (pct != _lastNotifiedPct || p.done == p.total) {
            _lastNotifiedPct = pct;
            notifyListeners();
          }
        },
      );
      _currentHandle = handle;
      // Surface the now-active handle so the Cancel button enables
      // immediately rather than waiting for the first progress event.
      notifyListeners();
      final result = await handle.result;
      // The user may have started a fresher run (or, with the native
      // isolate, edited the draft and navigated back to the page)
      // while this one was awaiting the isolate. Drop the stale
      // result instead of clobbering newer state.
      if (generation != _runGeneration) return;
      _lastResult = result;
    } on OptimizerCancelledException {
      if (generation != _runGeneration) return;
      _cancelled = true;
      _lastResult = null;
    } on ArgumentError catch (e) {
      if (generation != _runGeneration) return;
      _lastError = e.message?.toString() ?? e.toString();
      _lastResult = null;
    } catch (e) {
      if (generation != _runGeneration) return;
      _lastError = e.toString();
      _lastResult = null;
    } finally {
      // Only tear down UI state for the latest generation — a
      // superseded run shouldn't clobber the fresher run's `_running`
      // flag or progress bar.
      if (generation == _runGeneration) {
        _running = false;
        _progress = null;
        _currentHandle = null;
        notifyListeners();
      }
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

  /// Bumps the run generation so any in-flight sweep is silently
  /// discarded when it lands, then asks the runner to cancel so the
  /// worker isolate stops chewing CPU. Called by [OptimizerPage] from
  /// `dispose` so a sweep kicked off on an older draft can't clobber
  /// the controller's state after the user navigates away. Web /
  /// in-process runs are already synchronous, so `cancel()` is a no-op
  /// — but they also can't be in flight at dispose time, so this only
  /// matters on native.
  void supersede() {
    if (!_running) return;
    _runGeneration++;
    final handle = _currentHandle;
    _running = false;
    _progress = null;
    _currentHandle = null;
    // Cancel after clearing local state so the OptimizerCancelledException
    // that bubbles up from `handle.result` lands in a higher-generation
    // bucket and is dropped by the generation guards in `runFromDraft`.
    if (handle != null && handle.canCancel) handle.cancel();
    notifyListeners();
  }
}
