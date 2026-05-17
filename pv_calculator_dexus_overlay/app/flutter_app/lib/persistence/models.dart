// Row-shaped DTOs returned by the repositories. Kept as plain data
// classes — the engine types (`SimulationConfig` etc.) flow through
// `Scenario.config` so consumers stay decoupled from raw SQL.
import 'package:pv_engine/pv_engine.dart';

class ProjectRow {
  const ProjectRow({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
  });

  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
}

class SiteRow {
  const SiteRow({
    required this.id,
    required this.projectId,
    required this.name,
    required this.latitudeDeg,
    required this.longitudeDeg,
    required this.timezone,
    required this.countryCode,
  });

  final String id;
  final String projectId;
  final String name;
  final double latitudeDeg;
  final double longitudeDeg;
  final String? timezone;
  final String? countryCode;
}

class ScenarioRow {
  const ScenarioRow({
    required this.id,
    required this.projectId,
    required this.siteId,
    required this.name,
    required this.description,
    required this.config,
    required this.engineVersion,
    required this.inputHash,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String? siteId;
  final String name;
  final String? description;
  final SimulationConfig config;
  final String engineVersion;
  final String inputHash;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class SimulationRunRow {
  const SimulationRunRow({
    required this.id,
    required this.scenarioId,
    required this.startedAt,
    required this.finishedAt,
    required this.inputHash,
    required this.engineVersion,
    required this.summaryJson,
    required this.durationMs,
  });

  final String id;
  final String scenarioId;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String inputHash;
  final String engineVersion;
  final String summaryJson;
  final int durationMs;
}
