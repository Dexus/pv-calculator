import 'package:flutter/foundation.dart';
import 'package:pv_engine/pv_engine.dart';

import 'config_draft.dart';

/// Holds the editor's working draft plus the latest simulation result.
///
/// Kept UI-side only: dispatch logic remains in `pv_engine`.
class ProjectController extends ChangeNotifier {
  ProjectController({String? projectName, ConfigDraft? draft})
      : _projectName = projectName ?? 'Neues Projekt',
        _draft = draft ?? ConfigDraft.demo();

  String _projectName;
  ConfigDraft _draft;
  SimulationResult? _result;
  String? _lastError;
  bool _running = false;

  String get projectName => _projectName;
  ConfigDraft get draft => _draft;
  SimulationResult? get result => _result;
  String? get lastError => _lastError;
  bool get running => _running;

  set projectName(String value) {
    if (_projectName == value) return;
    _projectName = value;
    notifyListeners();
  }

  /// Notify listeners — call from form widgets after mutating draft fields.
  void touch() => notifyListeners();

  void loadDraft(String name, ConfigDraft draft) {
    _projectName = name;
    _draft = draft;
    _result = null;
    _lastError = null;
    notifyListeners();
  }

  void newProject() {
    _projectName = 'Neues Projekt';
    _draft = ConfigDraft.demo();
    _result = null;
    _lastError = null;
    notifyListeners();
  }

  /// Validates and runs the simulation. Returns `true` on success.
  bool run() {
    _running = true;
    notifyListeners();
    try {
      final config = _draft.build();
      config.validate();
      _result = const PvSimulator().run(config);
      _lastError = null;
      return true;
    } on ArgumentError catch (e) {
      _result = null;
      _lastError = e.message?.toString() ?? e.toString();
      return false;
    } finally {
      _running = false;
      notifyListeners();
    }
  }
}
