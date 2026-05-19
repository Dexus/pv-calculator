import 'dart:convert';

import 'package:pv_engine/pv_engine.dart';

import 'database.dart';
import 'models.dart';
import 'uuid.dart';

/// Records simulation outcomes so the comparison view can render KPIs
/// without re-running the engine. The summary is stored as a compact
/// JSON blob; full per-step time series are deliberately not persisted
/// (Architektur §7 line 372 — large series can be reconstructed on demand).
class SimulationRunRepository {
  SimulationRunRepository(this._db);

  final AppDatabase _db;

  /// Persists a completed run. [startedAt] / [finishedAt] are taken in UTC.
  SimulationRunRow recordRun({
    required String scenarioId,
    required DateTime startedAt,
    required DateTime finishedAt,
    required String inputHash,
    required SimulationSummary summary,
  }) {
    final id = newUuidV4();
    final duration = finishedAt.difference(startedAt).inMilliseconds;
    final summaryJson = jsonEncode(summaryToJson(summary));
    _db.db.execute(
      'INSERT INTO simulation_runs('
      'id, scenario_id, started_at, finished_at, input_hash, engine_version, '
      'summary_json, duration_ms) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        scenarioId,
        startedAt.toUtc().millisecondsSinceEpoch,
        finishedAt.toUtc().millisecondsSinceEpoch,
        inputHash,
        kEngineVersion,
        summaryJson,
        duration,
      ],
    );
    return _findById(id)!;
  }

  /// Most recent run whose `input_hash` matches [inputHash] **and** was
  /// produced by the current [kEngineVersion]. The engine-version guard
  /// matters: bumping the engine after a dispatch/inverter/SOC change
  /// invalidates yesterday's cached summary even when the user hasn't
  /// touched the scenario, so re-using a row with a stale engine version
  /// would silently show the old numbers next to a freshly-edited
  /// scenario. Callers use this to short-circuit re-runs only when both
  /// inputs and engine still match.
  SimulationRunRow? latestMatching(String scenarioId, String inputHash) {
    final rows = _db.db.select(
      'SELECT id, scenario_id, started_at, finished_at, input_hash, '
      'engine_version, summary_json, duration_ms '
      'FROM simulation_runs '
      'WHERE scenario_id = ? AND input_hash = ? AND engine_version = ? '
      'ORDER BY finished_at DESC LIMIT 1',
      [scenarioId, inputHash, kEngineVersion],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// Most recent run for [scenarioId] regardless of hash. Useful for
  /// showing the last-known KPIs in lists, with the caveat that the
  /// config may have changed since the run was recorded — UI should
  /// surface that staleness when `inputHash != scenario.inputHash`.
  SimulationRunRow? latestFor(String scenarioId) {
    final rows = _db.db.select(
      'SELECT id, scenario_id, started_at, finished_at, input_hash, '
      'engine_version, summary_json, duration_ms '
      'FROM simulation_runs WHERE scenario_id = ? '
      'ORDER BY finished_at DESC LIMIT 1',
      [scenarioId],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  void deleteForScenario(String scenarioId) {
    _db.db.execute('DELETE FROM simulation_runs WHERE scenario_id = ?', [scenarioId]);
  }

  SimulationRunRow? _findById(String id) {
    final rows = _db.db.select(
      'SELECT id, scenario_id, started_at, finished_at, input_hash, '
      'engine_version, summary_json, duration_ms '
      'FROM simulation_runs WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  SimulationRunRow _fromRow(Map row) => SimulationRunRow(
        id: row['id'] as String,
        scenarioId: row['scenario_id'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int, isUtc: true),
        finishedAt: DateTime.fromMillisecondsSinceEpoch(row['finished_at'] as int, isUtc: true),
        inputHash: row['input_hash'] as String,
        engineVersion: row['engine_version'] as String,
        summaryJson: row['summary_json'] as String,
        durationMs: row['duration_ms'] as int,
      );
}

/// Compact JSON form of [SimulationSummary] for cache storage. Reverse via
/// [summaryFromJson]. Keeps only the KPI surface the comparison view
/// needs — full per-step series live in memory while the run is active.
Map<String, dynamic> summaryToJson(SimulationSummary s) {
  final json = <String, dynamic>{
    'pvDcKwh': s.pvDcKwh,
    'pvAcKwh': s.pvAcKwh,
    'loadKwh': s.loadKwh,
    'selfConsumptionKwh': s.selfConsumptionKwh,
    'batteryChargeKwh': s.batteryChargeKwh,
    'batteryDischargeKwh': s.batteryDischargeKwh,
    'gridImportKwh': s.gridImportKwh,
    'gridExportKwh': s.gridExportKwh,
    'curtailedDcKwh': s.curtailedDcKwh,
    'curtailedAcKwh': s.curtailedAcKwh,
    'curtailedExportKwh': s.curtailedExportKwh,
    'finalBatterySocKwh': s.finalBatterySocKwh,
    'finalBatterySocsKwh': s.finalBatterySocsKwh,
    'microInverterDeliveredKwh': s.microInverterDeliveredKwh,
    'microInverterShortfallKwh': s.microInverterShortfallKwh,
    'unservedLoadKwh': s.unservedLoadKwh,
    'preRunMode': s.preRunMode.name,
    'preRunActive': s.preRunActive,
    'startSocsUsedKwh': s.startSocsUsedKwh,
    'convergenceIterations': s.convergenceIterations,
    'converged': s.converged,
  };
  if (s.perYearSummaries.length >= 2) {
    json['perYearSummaries'] =
        s.perYearSummaries.map(summaryToJson).toList(growable: false);
    // Phase-10 per-year monthly buckets — same gate as
    // `perYearSummaries`. Mirrors the engine-side JSON shape so a row
    // written by the engine's own `SimulationSummary.toJson` (e.g. a
    // future export envelope) would still load cleanly through
    // `summaryFromJson`.
    if (s.perYearMonthly.isNotEmpty) {
      json['perYearMonthly'] = s.perYearMonthly
          .map((year) => year.map((b) => b.toJson()).toList(growable: false))
          .toList(growable: false);
    }
  }
  // Phase-10 cashflow KPIs — present only when a tariff was configured
  // on the run. Stored as plain doubles so the comparison cache and
  // any reloaded scenario keeps its EUR-KPIs after a restart.
  if (s.importCostEur != null) json['importCostEur'] = s.importCostEur;
  if (s.exportRevenueEur != null) json['exportRevenueEur'] = s.exportRevenueEur;
  if (s.netCostEur != null) json['netCostEur'] = s.netCostEur;
  // Phase-4b DC-coupling KPIs. Persist only when non-zero so legacy
  // cached runs round-trip byte-identically through this codec.
  if (s.dcDirectChargeKwh != 0.0) json['dcDirectChargeKwh'] = s.dcDirectChargeKwh;
  if (s.dcCurtailedKwh != 0.0) json['dcCurtailedKwh'] = s.dcCurtailedKwh;
  return json;
}

SimulationSummary summaryFromJson(Map<String, dynamic> json) {
  PreRunMode parseMode(String? name) {
    if (name == null) return PreRunMode.singleWarmUp;
    for (final m in PreRunMode.values) {
      if (m.name == name) return m;
    }
    return PreRunMode.singleWarmUp;
  }

  double toD(Object? v) => (v as num).toDouble();
  final rawPerYear = json['perYearSummaries'];
  final perYear = rawPerYear is List
      ? rawPerYear
          .map((e) => summaryFromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false)
      : const <SimulationSummary>[];
  final rawPerYearMonthly = json['perYearMonthly'];
  final perYearMonthly = rawPerYearMonthly is List
      ? rawPerYearMonthly
          .map((year) => (year as List)
              .map((b) =>
                  MonthlyBucket.fromJson((b as Map).cast<String, dynamic>()))
              .toList(growable: false))
          .toList(growable: false)
      : const <List<MonthlyBucket>>[];
  return SimulationSummary(
    pvDcKwh: toD(json['pvDcKwh']),
    pvAcKwh: toD(json['pvAcKwh']),
    loadKwh: toD(json['loadKwh']),
    selfConsumptionKwh: toD(json['selfConsumptionKwh']),
    batteryChargeKwh: toD(json['batteryChargeKwh']),
    batteryDischargeKwh: toD(json['batteryDischargeKwh']),
    gridImportKwh: toD(json['gridImportKwh']),
    gridExportKwh: toD(json['gridExportKwh']),
    curtailedDcKwh: toD(json['curtailedDcKwh']),
    curtailedAcKwh: toD(json['curtailedAcKwh']),
    curtailedExportKwh: toD(json['curtailedExportKwh']),
    finalBatterySocKwh: toD(json['finalBatterySocKwh']),
    finalBatterySocsKwh:
        (json['finalBatterySocsKwh'] as List).map((e) => toD(e)).toList(growable: false),
    microInverterDeliveredKwh: toD(json['microInverterDeliveredKwh']),
    microInverterShortfallKwh: toD(json['microInverterShortfallKwh']),
    unservedLoadKwh: toD(json['unservedLoadKwh']),
    preRunMode: parseMode(json['preRunMode'] as String?),
    preRunActive: json['preRunActive'] as bool? ?? false,
    startSocsUsedKwh:
        (json['startSocsUsedKwh'] as List?)?.map((e) => toD(e)).toList(growable: false) ?? const [],
    convergenceIterations: (json['convergenceIterations'] as num?)?.toInt() ?? 0,
    converged: json['converged'] as bool? ?? true,
    perYearSummaries: perYear,
    perYearMonthly: perYearMonthly,
    importCostEur: json['importCostEur'] == null ? null : toD(json['importCostEur']),
    exportRevenueEur:
        json['exportRevenueEur'] == null ? null : toD(json['exportRevenueEur']),
    netCostEur: json['netCostEur'] == null ? null : toD(json['netCostEur']),
    dcDirectChargeKwh: (json['dcDirectChargeKwh'] as num?)?.toDouble() ?? 0.0,
    dcCurtailedKwh: (json['dcCurtailedKwh'] as num?)?.toDouble() ?? 0.0,
  );
}
