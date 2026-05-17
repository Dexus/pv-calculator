import 'package:flutter/foundation.dart';
import 'package:pv_engine/pv_engine.dart';

import '../services/pvgis_api.dart';
import 'config_draft.dart';

/// Holds the editor's working draft plus the latest simulation result.
///
/// Kept UI-side only: dispatch logic remains in `pv_engine`.
class ProjectController extends ChangeNotifier {
  ProjectController({
    String? projectName,
    ConfigDraft? draft,
    PvgisApiService? pvgisApi,
  })  : _projectName = projectName ?? 'Neues Projekt',
        _draft = draft ?? ConfigDraft.demo(),
        _ownsPvgisApi = pvgisApi == null,
        _pvgisApi = pvgisApi ?? PvgisApiService();

  String _projectName;
  ConfigDraft _draft;
  SimulationResult? _result;
  String? _lastError;
  bool _running = false;
  bool _loadingIrradiance = false;
  String? _lastIrradianceError;

  /// Index of the PV array the azimuth-compass overlay currently writes to.
  /// `null` = no active selection (compass overlay is hidden).
  int? _selectedArrayIndex;

  final PvgisApiService _pvgisApi;
  final bool _ownsPvgisApi;

  String get projectName => _projectName;
  ConfigDraft get draft => _draft;
  SimulationResult? get result => _result;
  String? get lastError => _lastError;
  bool get running => _running;
  bool get loadingIrradiance => _loadingIrradiance;
  String? get lastIrradianceError => _lastIrradianceError;
  int? get selectedArrayIndex => _selectedArrayIndex;

  set projectName(String value) {
    if (_projectName == value) return;
    _projectName = value;
    notifyListeners();
  }

  /// Notify listeners — call from form widgets after mutating draft fields.
  ///
  /// Also clears the last simulation error and any stale result, since a
  /// draft edit could be the user's response to that error and stale KPIs
  /// next to a changed form would be misleading.
  void touch() {
    _lastError = null;
    _result = null;
    notifyListeners();
  }

  /// Clears [lastIrradianceError] without modifying the draft. Call
  /// whenever the site location or year changes so a previous load failure
  /// is not shown next to a freshly selected location.
  void clearIrradianceError() {
    if (_lastIrradianceError == null) return;
    _lastIrradianceError = null;
    notifyListeners();
  }

  void loadDraft(String name, ConfigDraft draft) {
    _projectName = name;
    _draft = draft;
    _result = null;
    _lastError = null;
    _lastIrradianceError = null;
    _selectedArrayIndex = null;
    notifyListeners();
  }

  void newProject({
    String name = 'New project',
    String? defaultArrayLabel,
    String? defaultInverterLabel,
    String? defaultBatteryLabel,
  }) {
    _projectName = name;
    _draft = ConfigDraft.demo();
    // The demo draft ships German labels by default — when the UI
    // provides localized fallbacks, swap them in so a freshly created
    // project reads coherently in the user's language.
    if (defaultArrayLabel != null && _draft.arrays.isNotEmpty) {
      _draft.arrays.first.label = defaultArrayLabel;
    }
    if (defaultInverterLabel != null && _draft.inverters.isNotEmpty) {
      _draft.inverters.first.label = defaultInverterLabel;
    }
    if (defaultBatteryLabel != null && _draft.batteries.isNotEmpty) {
      _draft.batteries.first.label = defaultBatteryLabel;
    }
    _result = null;
    _lastError = null;
    _lastIrradianceError = null;
    _selectedArrayIndex = null;
    notifyListeners();
  }

  /// Called by the arrays tab after it removes the array at [removedIndex].
  /// Decrements [selectedArrayIndex] when the removed array is before the
  /// currently selected one so the selection continues to point at the same
  /// physical array.
  void adjustCompassIndexAfterRemoval(int removedIndex) {
    final cur = _selectedArrayIndex;
    if (cur == null || cur <= removedIndex) return;
    _selectedArrayIndex = cur - 1;
    notifyListeners();
  }

  /// Selects [index] as the array the Einstrahlung tab's compass writes
  /// to. Pass `null` to clear the selection. Triggers a notify so the
  /// overlay can show/hide itself and the arrays list can highlight the
  /// active row.
  void selectArrayForCompass(int? index) {
    if (_selectedArrayIndex == index) return;
    if (index != null && (index < 0 || index >= _draft.arrays.length)) return;
    _selectedArrayIndex = index;
    notifyListeners();
  }

  /// Writes [azimuthDeg] to the currently-selected array (if any). Used
  /// by the [AzimuthCompass] overlay on the Einstrahlung tab. No-op when
  /// no array is selected — the caller is expected to gate the UI on
  /// [selectedArrayIndex].
  void setSelectedArrayAzimuth(double azimuthDeg) {
    final i = _selectedArrayIndex;
    if (i == null) return;
    if (i < 0 || i >= _draft.arrays.length) return;
    _draft.arrays[i].azimuthDeg = azimuthDeg;
    _lastError = null;
    notifyListeners();
  }

  /// Fetches a year of horizontal global + diffuse irradiance from PVGIS
  /// (via the optional proxy) and caches the parsed series on the draft.
  /// Subsequent arrays consume that cache via [HorizontalToPoaSource] —
  /// no per-array network call.
  ///
  /// Errors surface via [lastIrradianceError]; the UI reads that to show
  /// the inline banner on the Einstrahlung tab.
  Future<void> loadSiteIrradiance() async {
    if (_loadingIrradiance) return;
    _loadingIrradiance = true;
    _lastIrradianceError = null;
    notifyListeners();
    try {
      final result = await _pvgisApi.fetchHorizontalSeries(
        latitudeDeg: _draft.latitudeDeg,
        longitudeDeg: _draft.longitudeDeg,
        year: _draft.siteIrradiance.year,
        radDatabase: _draft.siteIrradiance.radDatabase,
      );
      _draft.siteIrradiance.samples = result.series;
      _draft.siteIrradiance.loadedFromCache = result.fromCache;
      // Invalidate any previous simulation: the site weather just
      // changed under it.
      _result = null;
    } on PvgisApiException catch (e) {
      _lastIrradianceError = e.message;
    } catch (e) {
      _lastIrradianceError = e.toString();
    } finally {
      _loadingIrradiance = false;
      notifyListeners();
    }
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

  @override
  void dispose() {
    if (_ownsPvgisApi) _pvgisApi.dispose();
    super.dispose();
  }
}
