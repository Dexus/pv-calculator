import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pv_engine/pv_engine.dart';

import '../persistence/models.dart';
import '../persistence/scenario_repository.dart';
import '../persistence/simulation_run_repository.dart';

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
    PvSimulator? simulator,
  })  : _scenarios = scenarios,
        _runs = runs,
        _simulator = simulator ?? const PvSimulator();

  final ScenarioRepository _scenarios;
  final SimulationRunRepository _runs;
  final PvSimulator _simulator;

  final List<String> _selectedIds = [];
  List<ScenarioCompareEntry>? _entries;
  bool _running = false;
  String? _error;

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
    notifyListeners();
  }

  void addToSelection(String scenarioId) {
    if (_selectedIds.contains(scenarioId)) return;
    _selectedIds.add(scenarioId);
    _entries = null;
    notifyListeners();
  }

  void removeFromSelection(String scenarioId) {
    if (!_selectedIds.remove(scenarioId)) return;
    _entries = null;
    notifyListeners();
  }

  void clear() {
    if (_selectedIds.isEmpty && _entries == null && _error == null) return;
    _selectedIds.clear();
    _entries = null;
    _error = null;
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
    _running = true;
    _error = null;
    notifyListeners();
    try {
      final results = <ScenarioCompareEntry>[];
      for (final id in _selectedIds) {
        final scenario = _scenarios.findById(id);
        if (scenario == null) continue;
        final cached = _runs.latestMatching(scenario.id, scenario.inputHash);
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
        scenario.config.validate();
        final start = DateTime.now().toUtc();
        final outcome = _simulator.run(scenario.config);
        final end = DateTime.now().toUtc();
        _runs.recordRun(
          scenarioId: scenario.id,
          startedAt: start,
          finishedAt: end,
          inputHash: scenario.inputHash,
          summary: outcome.summary,
        );
        results.add(ScenarioCompareEntry(
          scenario: scenario,
          summary: outcome.summary,
          fromCache: false,
        ));
      }
      _entries = results;
    } catch (e) {
      _error = e.toString();
      _entries = null;
    } finally {
      _running = false;
      notifyListeners();
    }
  }
}
