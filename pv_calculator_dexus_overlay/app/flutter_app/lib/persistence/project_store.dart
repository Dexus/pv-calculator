import 'dart:convert';

import 'package:pv_engine/pv_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists named projects via [SharedPreferences].
///
/// Storage scheme:
///   - `pv_project_index`: JSON list of project names (the canonical list).
///   - `pv_project:<name>`: the JSON-encoded [SimulationConfig] for that name.
///
/// On the web, shared_preferences is backed by `localStorage` which is bounded
/// to ~5 MB total. A typical config is well under 5 KB so a project archive of
/// hundreds of entries fits comfortably; document this if it ever changes.
class ProjectStore {
  ProjectStore({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const String indexKey = 'pv_project_index';
  static const String entryPrefix = 'pv_project:';

  final SharedPreferences? _prefsOverride;

  Future<SharedPreferences> _prefs() async => _prefsOverride ?? await SharedPreferences.getInstance();

  Future<List<String>> listProjects() async {
    final prefs = await _prefs();
    final raw = prefs.getString(indexKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } on FormatException {
      // Corrupt index — return empty rather than throwing.
    }
    return const [];
  }

  Future<SimulationConfig?> loadConfig(String name) async {
    final prefs = await _prefs();
    final raw = prefs.getString('$entryPrefix$name');
    if (raw == null) return null;
    return SimulationConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveConfig(String name, SimulationConfig config) async {
    if (name.trim().isEmpty) throw ArgumentError('Project name must not be empty.');
    final prefs = await _prefs();
    await prefs.setString('$entryPrefix$name', jsonEncode(config.toJson()));
    final names = (await listProjects()).toSet()..add(name);
    await prefs.setString(indexKey, jsonEncode(names.toList()..sort()));
  }

  Future<void> deleteProject(String name) async {
    final prefs = await _prefs();
    await prefs.remove('$entryPrefix$name');
    final names = (await listProjects()).toList()..remove(name);
    await prefs.setString(indexKey, jsonEncode(names));
  }
}
