import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pv_engine/pv_engine.dart';

import '../persistence/irradiance_cache_repository.dart';
import '../services/pvgis_api.dart';
import '../services/simulation_runner.dart';
import 'config_draft.dart';
import 'settings_controller.dart';

/// Holds the editor's working draft plus the latest simulation result.
///
/// Kept UI-side only: dispatch logic remains in `pv_engine`.
class ProjectController extends ChangeNotifier {
  ProjectController({
    String? projectName,
    ConfigDraft? draft,
    PvgisApiService? pvgisApi,
    SimulationRunner? simulationRunner,
    IrradianceCacheRepository? irradianceCache,
    SettingsController? settings,
  })  : _projectName = projectName ?? 'Neues Projekt',
        _draft = draft ?? ConfigDraft.demo(),
        _ownsPvgisApi = pvgisApi == null,
        _pvgisApi = pvgisApi ?? PvgisApiService(),
        _runner = simulationRunner ?? const SimulationRunner(),
        _irradianceCache = irradianceCache,
        _settings = settings;

  String _projectName;
  ConfigDraft _draft;
  SimulationResult? _result;
  String? _lastError;
  bool _running = false;
  SimulationProgress? _progress;
  bool _loadingIrradiance = false;
  String? _lastIrradianceError;

  /// Identifies the scenario row this controller is editing. `null` means
  /// the draft is unsaved — Save acts as Save-As and creates a new row.
  /// Mirrored on the project side because the projects tab uses both ids
  /// when persisting changes.
  String? _scenarioId;
  String? _projectId;

  /// Index of the PV array the azimuth-compass overlay currently writes to.
  /// `null` = no active selection (compass overlay is hidden).
  int? _selectedArrayIndex;

  final PvgisApiService _pvgisApi;
  final bool _ownsPvgisApi;
  final SimulationRunner _runner;

  /// Optional reference to the settings controller. When provided,
  /// [loadDraft] flips `expertMode` on if the loaded scenario uses
  /// advanced features that would otherwise be hidden. Tests and the
  /// `_FakeRunner`-based controllers that don't need this wiring leave
  /// it null.
  final SettingsController? _settings;

  /// Persistent cache for PVGIS horizontal-series fetches. When set,
  /// [loadSiteIrradiance] consults it before reaching for the network
  /// and writes successful API responses back to it. `null` keeps the
  /// pre-cache behaviour and is used by the existing widget-test setups
  /// that don't bring up a real database.
  final IrradianceCacheRepository? _irradianceCache;

  /// Last few simulation results, keyed on `(inputHash, engineVersion)`.
  /// Small bound — full-year `SimulationResult` keeps the steps list
  /// while `keepSteps` defaults to true, so we don't want to retain many.
  final Map<String, SimulationResult> _resultCache = {};
  static const int _cacheSize = 3;

  /// Monotonic counter bumped on every action that should make any
  /// in-flight `run()` discard its result: a newer `run()`, draft
  /// mutation (`touch`), replacement (`loadDraft` / `newProject`),
  /// or a weather reload. Each `run()` captures the counter at the
  /// start and only commits the result if the value hasn't changed
  /// when its `await` returns — guards against the user editing the
  /// draft while a long isolate simulation is still in flight.
  int _runGeneration = 0;

  /// Number of `run()` invocations currently in flight. The finally
  /// block clears `_running`/`_progress` only when this drops to 0
  /// — that way an older, superseded run leaves the running flag set
  /// while a fresher run is still active, but if no fresher run was
  /// started (e.g. the supersedure came from `touch()` rather than a
  /// second `run()`), the awaited isolate still tears the UI state
  /// down so the Run button reactivates.
  int _activeRuns = 0;

  /// Last whole-percent fraction we notified listeners about during the
  /// current run; reset on every fresh `run()` start. Used to throttle
  /// progress-event notifications to ≤ 101 per phase.
  int _lastNotifiedPct = -1;

  void _rememberResult(String key, SimulationResult result) {
    if (_resultCache.containsKey(key)) {
      _resultCache.remove(key);
    } else if (_resultCache.length >= _cacheSize) {
      _resultCache.remove(_resultCache.keys.first);
    }
    _resultCache[key] = result;
  }

  String get projectName => _projectName;
  ConfigDraft get draft => _draft;
  SimulationResult? get result => _result;
  String? get lastError => _lastError;
  bool get running => _running;

  /// Most recent progress event from the running simulation, or `null` if
  /// no simulation is in flight. Reset on every [run] invocation.
  SimulationProgress? get progress => _progress;
  bool get loadingIrradiance => _loadingIrradiance;
  String? get lastIrradianceError => _lastIrradianceError;
  int? get selectedArrayIndex => _selectedArrayIndex;
  String? get scenarioId => _scenarioId;
  String? get projectId => _projectId;

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
    _runGeneration++;
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

  void loadDraft(
    String name,
    ConfigDraft draft, {
    String? scenarioId,
    String? projectId,
  }) {
    _projectName = name;
    _draft = draft;
    _scenarioId = scenarioId;
    _projectId = projectId;
    // If the loaded scenario uses sections that are gated behind expert
    // mode (topology, micro-inverter banks, non-default dispatch policy,
    // charge controllers), flip the flag on so those panels become
    // visible instead of leaving the user to chase a banner. The
    // existing `_ExpertOffHint` self-hides once `expertMode == true`.
    final settings = _settings;
    if (settings != null &&
        !settings.expertMode &&
        draft.usesAdvancedFeatures) {
      unawaited(settings.setExpertMode(true));
    }
    _result = null;
    // A different draft may bring a different (non-serialised) weather
    // source even when the electrical inputs hash the same. Clear the
    // cache so we don't return the previous draft's result for this
    // draft's `inputHash`.
    _resultCache.clear();
    _runGeneration++;
    _lastError = null;
    _lastIrradianceError = null;
    _selectedArrayIndex = null;
    notifyListeners();
    // `SimulationConfig` does not serialise irradiance samples — every
    // freshly loaded draft therefore has `samples == null`. Kick off
    // a background restore: cache-hit returns instantly without a
    // network call; cache-miss falls through to the regular PVGIS
    // fetch so the user does not have to press "Lade Daten" again on
    // every project open.
    if (draft.siteIrradiance.samples == null) {
      unawaited(loadSiteIrradiance());
    }
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
    _scenarioId = null;
    _projectId = null;
    _result = null;
    _resultCache.clear();
    _runGeneration++;
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
    // Compass edits are draft mutations — they must supersede any in-
    // flight `run()` the same way `touch()` does, so a long native
    // isolate simulation can't commit KPIs for the old orientation
    // back into `_result` after the user has already rotated the
    // panel. (`touch()` is the canonical "draft changed" entry point;
    // we inline its effects rather than call it to avoid wiping
    // `_result`, which the compass overlay isn't trying to invalidate
    // — only superseding a still-running compute.)
    _runGeneration++;
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
    // Capture the request key *before* any await so a draft swap or a
    // lat/lon/year/db edit mid-request can't pin the response to the
    // wrong location. `loadDraft` and the irradiance form both bump
    // `_runGeneration`, so comparing it after the await tells us
    // whether the draft we're still meant to write to is the same one
    // we started for. The draft instance is captured too because
    // `_draft` itself may have been replaced.
    final draftAtStart = _draft;
    final generationAtStart = _runGeneration;
    final reqLat = draftAtStart.latitudeDeg;
    final reqLon = draftAtStart.longitudeDeg;
    final reqYear = draftAtStart.siteIrradiance.year;
    final reqDb = draftAtStart.siteIrradiance.radDatabase;
    bool stillCurrent() =>
        identical(_draft, draftAtStart) &&
        _runGeneration == generationAtStart &&
        _draft.latitudeDeg == reqLat &&
        _draft.longitudeDeg == reqLon &&
        _draft.siteIrradiance.year == reqYear &&
        _draft.siteIrradiance.radDatabase == reqDb;
    try {
      // 1) Local DB cache — instant, no network. Shared across every
      // project that uses the same (lat, lon, year, radDatabase), so a
      // second project at the same location never refetches.
      final cache = _irradianceCache;
      if (cache != null) {
        final cached = cache.lookup(
          latitudeDeg: reqLat,
          longitudeDeg: reqLon,
          year: reqYear,
          radDatabase: reqDb,
        );
        if (cached != null) {
          if (stillCurrent()) {
            _draft.siteIrradiance.samples = cached;
            _draft.siteIrradiance.loadedFromCache = true;
            _result = null;
            _resultCache.clear();
            _runGeneration++;
          }
          return;
        }
      }
      // 2) PVGIS — write through to the local cache on success.
      final result = await _pvgisApi.fetchHorizontalSeries(
        latitudeDeg: reqLat,
        longitudeDeg: reqLon,
        year: reqYear,
        radDatabase: reqDb,
      );
      // Cache write is unconditional: the response is genuinely valid
      // for the (reqLat, reqLon, reqYear, reqDb) tuple even if the
      // user has since switched to a different draft, so future
      // requests at the same location still benefit.
      cache?.store(
        latitudeDeg: reqLat,
        longitudeDeg: reqLon,
        year: reqYear,
        radDatabase: reqDb,
        series: result.series,
      );
      if (!stillCurrent()) {
        // Draft/site changed mid-flight — don't pin the old location's
        // data onto the new draft. The new draft has its own auto-load
        // (or will), so we're not silently dropping work.
        return;
      }
      _draft.siteIrradiance.samples = result.series;
      _draft.siteIrradiance.loadedFromCache = result.fromCache;
      // Invalidate any previous simulation: the site weather just
      // changed under it. The hash-keyed result cache also has to go,
      // because `SimulationConfig.toJson()` does not serialise the
      // weather source — so two runs with identical electrical inputs
      // but different irradiance would otherwise collide on the same
      // `inputHash` and return a stale cached result. See PR #26
      // review threads from Codex.
      _result = null;
      _resultCache.clear();
      // Bump the run generation: a `run()` started before this reload
      // must not commit its (stale-weather) result over the new state.
      _runGeneration++;
    } on PvgisApiException catch (e) {
      if (stillCurrent()) _lastIrradianceError = e.message;
    } catch (e) {
      if (stillCurrent()) _lastIrradianceError = e.toString();
    } finally {
      _loadingIrradiance = false;
      notifyListeners();
    }
  }

  /// Validates and runs the simulation on a worker isolate (native) or
  /// the main isolate (web). Returns `true` on success. Progress events
  /// from the engine flow through [progress] while the run is in flight.
  ///
  /// Caches up to [_cacheSize] recent results keyed on
  /// `(inputHash, kEngineVersion)`; a repeated Run on an unchanged draft
  /// returns instantly. The cache is bounded so it never holds more than
  /// a small number of full-year step lists in memory at once.
  Future<bool> run() async {
    final generation = ++_runGeneration;
    _activeRuns++;
    _running = true;
    _progress = null;
    _lastNotifiedPct = -1;
    notifyListeners();
    try {
      // Run-path uses buildForRun() so Pro-only knobs are clamped in
      // a free build. Save paths still use build() to preserve the
      // draft as-authored on disk.
      final config = _draft.buildForRun();
      config.validate();
      final cacheKey = '${config.inputHash}@$kEngineVersion';
      final cached = _resultCache[cacheKey];
      if (cached != null) {
        if (generation != _runGeneration) return false;
        _result = cached;
        _lastError = null;
        return true;
      }
      final outcome = await _runner.run(config, onProgress: (p) {
        // Drop progress events from a superseded run so the UI doesn't
        // see a half-finished bar from an old config.
        if (generation != _runGeneration) return;
        _progress = p;
        // Throttle UI rebuilds. The engine emits one event per simulated
        // day (365 × N for cyclic mode). On the in-process / web path
        // these fire synchronously inside `PvSimulator.run`, so a
        // `notifyListeners()` per event would queue ~1 000+ back-to-back
        // Provider rebuilds and starve any later `pumpAndSettle` in
        // tests. Notify only when the integer-percent fraction advances
        // (≤ 101 notifies per phase) or on the final tick.
        final lastPct = _lastNotifiedPct;
        final pct = p.totalDays == 0
            ? 100
            : (p.completedDays * 100) ~/ p.totalDays;
        if (pct != lastPct || p.completedDays == p.totalDays) {
          _lastNotifiedPct = pct;
          notifyListeners();
        }
      });
      // The user may have touched the draft, loaded another project, or
      // reloaded irradiance while we were awaiting the isolate. In any
      // of those cases `_runGeneration` has moved on and committing
      // this result would overwrite their fresher state.
      if (generation != _runGeneration) return false;
      _result = outcome;
      _rememberResult(cacheKey, outcome);
      _lastError = null;
      return true;
    } on ArgumentError catch (e) {
      if (generation != _runGeneration) return false;
      _result = null;
      _lastError = e.message?.toString() ?? e.toString();
      return false;
    } catch (e) {
      if (generation != _runGeneration) return false;
      _result = null;
      _lastError = e.toString();
      return false;
    } finally {
      _activeRuns--;
      // Clear the running flag whenever no other `run()` is in flight,
      // regardless of whether we were superseded. If `touch()` or
      // `loadSiteIrradiance()` bumped `_runGeneration` while we were
      // awaiting and no replacement `run()` was triggered, the UI was
      // otherwise stuck with `_running = true` forever.
      if (_activeRuns == 0) {
        _running = false;
        _progress = null;
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_ownsPvgisApi) _pvgisApi.dispose();
    super.dispose();
  }
}
