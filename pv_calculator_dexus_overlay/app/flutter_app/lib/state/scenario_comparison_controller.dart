import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pv_engine/pv_engine.dart';

import '../persistence/models.dart';
import '../persistence/scenario_repository.dart';
import '../persistence/simulation_run_repository.dart';
import '../services/simulation_runner.dart';
import 'config_draft.dart';

/// One entry in the compare view: the scenario plus a freshly-resolved
/// summary (cached if present, computed on demand otherwise).
class ScenarioCompareEntry {
  const ScenarioCompareEntry({
    required this.scenario,
    required this.summary,
    required this.fromCache,
  });

  final ScenarioRow scenario;
  final SimulationSummary summary;

  /// `true` if [summary] was reused from a stored `simulation_runs` row
  /// whose `input_hash` matches the current scenario hash. `false` if
  /// the simulator was re-invoked just now.
  final bool fromCache;
}

/// Drives the Scenario-Compare page. Holds an ordered list of selected
/// scenario ids and resolves them to `(scenario, summary)` pairs on demand.
///
/// The actual simulator call happens here so the UI stays free of engine
/// orchestration. Results are written back to [SimulationRunRepository]
/// so subsequent comparisons (or single-scenario opens) can short-circuit
/// when nothing has changed.
class ScenarioComparisonController extends ChangeNotifier {
  ScenarioComparisonController({
    required ScenarioRepository scenarios,
    required SimulationRunRepository runs,
    SimulationRunner? runner,
  })  : _scenarios = scenarios,
        _runs = runs,
        _runner = runner ?? const SimulationRunner();

  final ScenarioRepository _scenarios;
  final SimulationRunRepository _runs;
  final SimulationRunner _runner;

  final List<String> _selectedIds = [];
  List<ScenarioCompareEntry>? _entries;
  bool _running = false;
  String? _error;

  /// Generation token bumped on every selection change. Each `resolve()`
  /// captures the current value before iterating; if the token moves
  /// while an `await` is suspended (because the user adjusted the
  /// selection on the projects tab) the in-flight resolve drops its
  /// partial results instead of publishing entries for a stale ID list.
  int _resolveGeneration = 0;

  /// Number of `resolve()` invocations currently in flight. The finally
  /// block clears `_running` only when this drops to 0, so a stale
  /// resolve superseded by a selection mutation (which doesn't itself
  /// kick off a new `resolve()`) still tears down its loading state.
  int _activeResolves = 0;

  List<String> get selectedIds => List.unmodifiable(_selectedIds);
  List<ScenarioCompareEntry>? get entries =>
      _entries == null ? null : List.unmodifiable(_entries!);
  bool get running => _running;
  String? get error => _error;

  void replaceSelection(Iterable<String> ids) {
    _selectedIds
      ..clear()
      ..addAll(ids);
    _entries = null;
    _error = null;
    _resolveGeneration++;
    notifyListeners();
  }

  void addToSelection(String scenarioId) {
    if (_selectedIds.contains(scenarioId)) return;
    _selectedIds.add(scenarioId);
    _entries = null;
    _resolveGeneration++;
    notifyListeners();
  }

  void removeFromSelection(String scenarioId) {
    if (!_selectedIds.remove(scenarioId)) return;
    _entries = null;
    _resolveGeneration++;
    notifyListeners();
  }

  void clear() {
    if (_selectedIds.isEmpty && _entries == null && _error == null) return;
    _selectedIds.clear();
    _entries = null;
    _error = null;
    _resolveGeneration++;
    notifyListeners();
  }

  /// Resolves every selected id: reads the scenario, reuses the most
  /// recent cached run when the hash still matches, otherwise runs the
  /// simulator and records the result. Sets [error] on the first failure
  /// and leaves [entries] null so the UI can show a placeholder.
  Future<void> resolve() async {
    if (_selectedIds.isEmpty) {
      _entries = const [];
      notifyListeners();
      return;
    }
    // Snapshot the selection so a `replaceSelection` (or similar)
    // landing while we are awaiting an isolate doesn't change the IDs
    // we are walking. The generation token lets us drop the result
    // entirely if the selection moved on by the time we are ready
    // to publish — recording per-scenario `simulation_runs` is fine
    // (the DB cache is keyed on `scenarioId`/`inputHash`), but the
    // *entries* must reflect the current `_selectedIds`.
    final generation = ++_resolveGeneration;
    _activeResolves++;
    final selectionSnapshot = List<String>.unmodifiable(_selectedIds);
    _running = true;
    _error = null;
    notifyListeners();
    try {
      final results = <ScenarioCompareEntry>[];
      for (final id in selectionSnapshot) {
        if (generation != _resolveGeneration) return;
        final scenario = _scenarios.findById(id);
        if (scenario == null) continue;
        // Build the to-be-executed config first so the cache key
        // reflects what the engine actually saw. Two reasons:
        //  - `applyProGates` clamps Pro-only knobs in a free build, so
        //    a Pro-authored scenario opened in Pro vs free executes
        //    different inputs; keying by `scenario.inputHash` (the
        //    persisted, un-gated hash) would let a free-build summary
        //    masquerade as the Pro answer (and vice versa).
        //  - `keepSteps: false` is enforced for batch runs; that
        //    already changes the input JSON, but `scenario.inputHash`
        //    is the saved-with-default value, so distinguishing on the
        //    actual run hash keeps the bookkeeping consistent.
        // JSON round-trip is enough because `weatherSource` is not
        // part of the persisted config — scenarios load with the
        // synthetic fallback either way.
        final batchConfig = applyProGates(SimulationConfig.fromJson({
          ...scenario.config.toJson(),
          'keepSteps': false,
        }));
        final runHash = batchConfig.inputHash;
        final cached = _runs.latestMatching(scenario.id, runHash);
        if (cached != null) {
          final summary = summaryFromJson(
            jsonDecode(cached.summaryJson) as Map<String, dynamic>,
          );
          results.add(ScenarioCompareEntry(
            scenario: scenario,
            summary: summary,
            fromCache: true,
          ));
          continue;
        }
        batchConfig.validate();
        final start = DateTime.now().toUtc();
        final outcome = await _runner.run(batchConfig);
        final end = DateTime.now().toUtc();
        // Record the run regardless — the DB cache is keyed on
        // (scenarioId, runHash) and benefits other consumers — but
        // only publish entries when our selection is still current.
        _runs.recordRun(
          scenarioId: scenario.id,
          startedAt: start,
          finishedAt: end,
          inputHash: runHash,
          summary: outcome.summary,
        );
        if (generation != _resolveGeneration) return;
        results.add(ScenarioCompareEntry(
          scenario: scenario,
          summary: outcome.summary,
          fromCache: false,
        ));
      }
      if (generation != _resolveGeneration) return;
      _entries = results;
    } catch (e) {
      if (generation != _resolveGeneration) return;
      _error = e.toString();
      _entries = null;
    } finally {
      _activeResolves--;
      // Clear the running flag once no other resolve() is in flight.
      // A superseded resolve still tears down here even if no fresher
      // resolve was kicked off (selection mutators only bump the
      // generation token), so the comparison spinner doesn't get stuck.
      if (_activeResolves == 0) {
        _running = false;
      }
      notifyListeners();
    }
  }
}
