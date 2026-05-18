import 'package:pv_engine/pv_engine.dart';

import '../config.dart';

/// Which form section a [ValidationIssue] belongs to. The Auswertung
/// tab and friends use this to render the engine's free-form error
/// message inside the matching section card instead of in a single
/// top-of-page banner.
enum ConfigSection {
  project,
  arrays,
  inverters,
  batteries,
  banks,
  policy,
  topology,
  load,
  tariff,
  unknown,
}

/// A classified engine-validation failure. Routed to a section so the
/// user sees the message next to the field they need to fix.
class ValidationIssue {
  const ValidationIssue({required this.section, required this.message});
  final ConfigSection section;
  final String message;
}

/// Severity of a non-blocking [ValidationWarning]. `warning` means the
/// configuration runs but produces likely-undesired results (chronic
/// curtailment, chronic shortfall); `hint` is informational only.
enum WarningSeverity { warning, hint }

/// A non-blocking validation finding computed by the UI against the
/// current [ConfigDraft]. Distinct from [ValidationIssue] (which mirrors
/// an engine throw) — warnings let the simulation run but flag a
/// design smell. [code] is a stable identifier so widget tests can
/// target individual warnings without matching on translated copy; the
/// renderer maps each code to a localized string and substitutes the
/// per-warning [args] into the ICU placeholders.
class ValidationWarning {
  const ValidationWarning({
    required this.code,
    required this.severity,
    required this.section,
    this.args = const {},
  });

  /// Stable warning identifier (e.g. `inverter-oversized`). Used as a
  /// Widget key and as the lookup key in the renderer's switch.
  final String code;
  final WarningSeverity severity;
  final ConfigSection section;
  final Map<String, String> args;
}

/// Maps an engine [ArgumentError.message] string to the form section
/// that owns the field that triggered it. Keyword-based so the engine
/// stays in plain text without needing structured error types.
ConfigSection classifyValidationMessage(String message) {
  final m = message.toLowerCase();
  // Order matters: more specific keywords come first.
  if (m.contains('pv array') ||
      m.contains('shading') ||
      m.contains('losses') ||
      m.contains('lossfactor') ||
      m.contains('tiltdeg') ||
      m.contains('peakkw') ||
      m.contains('temperaturecoefficient') ||
      m.contains('nominaloperatingcelltemp') ||
      m.contains('references missing inverter')) {
    return ConfigSection.arrays;
  }
  if (m.contains('micro-inverter bank') ||
      m.contains('microinverterbank') ||
      m.contains('mininvertereff') ||
      m.contains('unitratedpower') ||
      m.contains('minsocshutdown')) {
    return ConfigSection.banks;
  }
  if (m.contains('inverter') ||
      m.contains('maxackw') ||
      m.contains('maxdcinputkw') ||
      m.contains('efficiency') && !m.contains('roundtrip')) {
    return ConfigSection.inverters;
  }
  // Topology messages mention 'battery' too (e.g. "Topology coupling for
  // battery X..."), so route them before the battery section.
  if (m.contains('topology') ||
      m.contains('dcbus') ||
      m.contains('acbus') ||
      m.contains('mppt') ||
      m.contains('coupling') ||
      m.contains('edge')) {
    return ConfigSection.topology;
  }
  if (m.contains('battery') ||
      m.contains('socKwh'.toLowerCase()) ||
      m.contains('capacitykwh') ||
      m.contains('maxchargekw') ||
      m.contains('maxdischargekw') ||
      m.contains('roundtripefficiency')) {
    return ConfigSection.batteries;
  }
  if (m.contains('dispatchpolicy') ||
      m.contains('reserveSocFraction'.toLowerCase()) ||
      m.contains('reserve soc fraction')) {
    return ConfigSection.policy;
  }
  if (m.contains('load ') ||
      m.contains('dailykwh') ||
      m.contains('hourlyshape')) {
    return ConfigSection.load;
  }
  // Engine TariffConfig.validate prefixes its ArgumentError messages
  // with "Tariff ..." so a single keyword routes every tariff field
  // to the new section card.
  if (m.contains('tariff') ||
      m.contains('hourlyimportprices') ||
      m.contains('hourlyexportprices') ||
      m.contains('importpriceperkwh') ||
      m.contains('exportpriceperkwh')) {
    return ConfigSection.tariff;
  }
  if (m.contains('latitudedeg') ||
      m.contains('longitudedeg') ||
      m.contains('startdayofyear') ||
      m.contains('preRunDays'.toLowerCase()) ||
      m.contains('gridexportlimit') ||
      m.contains('days must') ||
      m.contains('simulationyears')) {
    return ConfigSection.project;
  }
  return ConfigSection.unknown;
}

/// Strips Pro-only knobs from a [SimulationConfig] before the engine
/// actually runs it, when the build does not have the Pro flag enabled.
/// Used both by [ConfigDraft.buildForRun] (the Auswertung-tab Run
/// button) and by [ScenarioComparisonController] (the compare-scenarios
/// path), so opening a Pro-authored saved scenario in a free build
/// never silently executes the gated features.
///
/// No-op in Pro builds — the returned config equals the input.
SimulationConfig applyProGates(SimulationConfig config) {
  if (kProFeatures) return config;
  final tariffConfig = config.tariff;
  final clampedTariff = tariffConfig == null
      ? null
      : TariffConfig(
          importPricePerKwh: tariffConfig.importPricePerKwh,
          exportPricePerKwh: tariffConfig.exportPricePerKwh,
          // null both sides → engine falls back to flat prices.
        );
  return SimulationConfig(
    arrays: config.arrays,
    inverters: config.inverters,
    batteries: config.batteries,
    microInverterBanks: config.microInverterBanks,
    dispatchPolicy: config.dispatchPolicy,
    topology: config.topology,
    loadProfile: config.loadProfile,
    startDayOfYear: config.startDayOfYear,
    days: config.days,
    timeStep: config.timeStep,
    preRunDays: config.preRunDays,
    preRunMode: config.preRunMode,
    convergenceToleranceFraction: config.convergenceToleranceFraction,
    maxConvergenceIterations: config.maxConvergenceIterations,
    gridExportLimitKw: config.gridExportLimitKw,
    latitudeDeg: config.latitudeDeg,
    longitudeDeg: config.longitudeDeg,
    weatherSource: config.weatherSource,
    temperatureModel: config.temperatureModel,
    keepSteps: config.keepSteps,
    simulationYears: 1,
    tariff: clampedTariff,
  );
}

/// PVGIS radiation databases the Einstrahlung tab offers in the dropdown.
/// `null` lets PVGIS pick its own default for the requested location,
/// which is the safe fallback when a specific database does not cover a
/// region. All four current PVGIS databases are exposed — SARAH2 lives
/// on the v5.2 endpoint while the others use v5.3; both the proxy and
/// the Dart URL builder route per database via
/// `pvgisSeriesCalcEndpointFor`. NSRDB is the Americas, SARAH3 is
/// Europe/Africa, ERA5 is global; PVGIS itself surfaces "outside
/// coverage" errors when a database doesn't cover the chosen location.
const List<String?> pvgisRadDatabaseOptions = [
  null,
  'PVGIS-SARAH3',
  'PVGIS-SARAH2',
  'PVGIS-ERA5',
  'PVGIS-NSRDB',
];

/// Year picker default. SARAH3 currently covers 2005-01-01 through
/// ~end-2023; we centre on 2022 so a fresh project has a known-good
/// year preselected without the user having to think.
const int defaultIrradianceYear = 2022;

/// Default radiation database. SARAH2 matches the annual totals reported
/// by the comparison/reference app this project is calibrated against —
/// SARAH3 runs ~3% higher on the same site/year, which made our numbers
/// look "off" against the example. SARAH2 lives on PVGIS v5.2; both the
/// Cloudflare proxy and the Dart URL builder route it there via
/// `pvgisSeriesCalcEndpointFor`. Users can still switch to any other
/// database in the dropdown (or to `null` / "PVGIS auto").
const String defaultRadDatabase = 'PVGIS-SARAH2';

/// Site-level horizontal-irradiance request + cached samples for the
/// Einstrahlung tab.
///
/// One per project. Samples are populated by [ProjectController.loadSiteIrradiance]
/// from the PVGIS `seriescalc&components=1` endpoint and re-used by every
/// PV array via [HorizontalToPoaSource] on the engine side.
///
/// Session-only by default — `samples` is not persisted with the project
/// JSON so the file stays small. The user reloads on open via Lade Daten.
class SiteIrradianceDraft {
  SiteIrradianceDraft({
    this.year = defaultIrradianceYear,
    this.radDatabase = defaultRadDatabase,
    this.samples,
    this.loadedFromCache,
  });

  int year;

  /// Optional PVGIS `raddatabase` (e.g. `PVGIS-SARAH3`). `null` lets
  /// PVGIS pick.
  String? radDatabase;

  /// 365×24 cached samples for `year`/[radDatabase] at the project's
  /// current lat/lon. `null` until Lade Daten has run successfully.
  HorizontalIrradianceSeries? samples;

  /// `true` when the most recent load came from the proxy's R2 cache
  /// (`X-Cache: HIT`), `false` when fetched fresh from PVGIS, `null`
  /// when no load has happened yet or the cache header was missing.
  /// Surfaced in the UI as a small badge so users can tell repeat
  /// queries are fast because of caching.
  bool? loadedFromCache;
}

/// Mutable working copy of [SimulationConfig] for UI editing.
///
/// Engine types are immutable; the editor needs fields the user can mutate
/// before re-building a fresh [SimulationConfig] for simulation/persistence.
/// No dispatch logic lives here.
class ConfigDraft {
  ConfigDraft({
    this.startDayOfYear = 1,
    this.days = 365,
    this.timeStep = TimeStep.hourly,
    this.preRunDays = 0,
    this.preRunMode = PreRunMode.singleWarmUp,
    this.convergenceToleranceFraction = 0.005,
    this.maxConvergenceIterations = 10,
    this.gridExportLimitKw,
    this.latitudeDeg = 50.0,
    this.longitudeDeg = 10.0,
    this.simulationYears = 1,
    SiteIrradianceDraft? siteIrradiance,
    List<PvArrayDraft>? arrays,
    List<InverterDraft>? inverters,
    List<BatteryDraft>? batteries,
    List<MicroInverterBankDraft>? microInverterBanks,
    DispatchPolicyDraft? dispatchPolicy,
    LoadProfileDraft? loadProfile,
    TopologyGraphDraft? topology,
    TariffDraft? tariff,
  })  : siteIrradiance = siteIrradiance ?? SiteIrradianceDraft(),
        tariff = tariff ?? TariffDraft(),
        arrays = arrays ?? <PvArrayDraft>[],
        inverters = inverters ?? <InverterDraft>[],
        batteries = batteries ?? <BatteryDraft>[],
        microInverterBanks = microInverterBanks ?? <MicroInverterBankDraft>[],
        dispatchPolicy = dispatchPolicy ?? DispatchPolicyDraft.selfConsumption(),
        loadProfile = loadProfile ?? LoadProfileDraft(),
        topology = topology ?? TopologyGraphDraft();

  int startDayOfYear;
  int days;
  TimeStep timeStep;
  int preRunDays;
  PreRunMode preRunMode;
  double convergenceToleranceFraction;
  int maxConvergenceIterations;
  double? gridExportLimitKw;
  double latitudeDeg;
  double longitudeDeg;

  /// Multi-year simulation length (Phase 10, Pro). `1` is the default
  /// single-year run; in non-Pro builds [build] forces this back to
  /// `1` so the engine never sees a Pro value smuggled in via an
  /// imported scenario.
  int simulationYears;

  /// Electricity tariff. When [TariffDraft.enabled] is `false`,
  /// [build] omits the tariff entirely and the engine skips the
  /// cashflow computation. The 24-slot TOU arrays are gated to
  /// Pro builds at [build] time.
  TariffDraft tariff;

  /// Site-level PVGIS settings + cached horizontal irradiance.
  SiteIrradianceDraft siteIrradiance;

  final List<PvArrayDraft> arrays;
  final List<InverterDraft> inverters;
  final List<BatteryDraft> batteries;

  /// Phase-4 micro-inverter banks (battery-coupled AC outputs).
  final List<MicroInverterBankDraft> microInverterBanks;

  /// Phase-4 dispatch policy. Defaults to SelfConsumptionFirst; the
  /// engine only persists this in JSON when it isn't the default.
  DispatchPolicyDraft dispatchPolicy;

  /// Phase-4 explicit topology. When [TopologyGraphDraft.enabled] is
  /// `false`, the engine falls back to `TopologyGraph.fromLegacy` which
  /// reproduces pre-Phase-4 behaviour.
  TopologyGraphDraft topology;

  LoadProfileDraft loadProfile;

  /// Builds the [IrradianceSource] used by the engine, or `null` to fall
  /// back to the synthetic default. Returns a [HorizontalToPoaSource] over
  /// the cached site samples — every array on the project derives its POA
  /// from the same horizontal series via on-the-fly transposition, so no
  /// per-array weather state is needed.
  IrradianceSource? buildWeatherSource() {
    final samples = siteIrradiance.samples;
    if (samples == null) return null;
    return HorizontalToPoaSource(samples);
  }

  /// `true` when this draft makes use of an editor section that is
  /// hidden in non-expert mode (topology, micro-inverter banks, or a
  /// non-default dispatch policy). Drives the auto-detect banner in the
  /// Auswertung tab so imported expert scenarios do not silently lose
  /// access to the controls that shape them.
  bool get usesAdvancedFeatures =>
      topology.enabled ||
      microInverterBanks.isNotEmpty ||
      dispatchPolicy.kind != DispatchPolicyKind.selfConsumption;

  /// Builds the canonical [SimulationConfig] for **persistence**: the
  /// returned config mirrors the draft exactly so a Pro-authored
  /// scenario opened in a free build round-trips to disk without
  /// silently losing its Pro fields (multi-year, TOU tariff). The
  /// simulator MUST be invoked through [buildForRun] instead, which
  /// applies the Pro gates so a free build never actually runs the
  /// gated features.
  SimulationConfig build() {
    final policy = dispatchPolicy.build();
    return SimulationConfig(
      arrays: arrays.map((a) => a.build()).toList(growable: false),
      inverters: inverters.map((i) => i.build()).toList(growable: false),
      batteries: batteries.map((b) => b.build()).toList(growable: false),
      microInverterBanks: microInverterBanks.map((b) => b.build()).toList(growable: false),
      // Only attach a non-default policy so v1-shaped projects keep
      // round-tripping through v1 JSON (the engine bumps to v2 only
      // when one of these new fields is set).
      dispatchPolicy: policy is SelfConsumptionFirstPolicy ? null : policy,
      topology: topology.enabled ? topology.build() : null,
      loadProfile: loadProfile.build(),
      startDayOfYear: startDayOfYear,
      days: days,
      timeStep: timeStep,
      preRunDays: preRunDays,
      preRunMode: preRunMode,
      convergenceToleranceFraction: convergenceToleranceFraction,
      maxConvergenceIterations: maxConvergenceIterations,
      gridExportLimitKw: gridExportLimitKw,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      weatherSource: buildWeatherSource(),
      simulationYears: simulationYears,
      tariff: tariff.build(includeTou: true),
    );
  }

  /// Variant of [build] that enforces Pro-only gates so a free build
  /// can't run features it isn't licensed for. Always invoked by the
  /// simulator entry point ([ProjectController.run]); persistence
  /// paths use [build] instead so opening + saving a Pro scenario in
  /// a free build never downgrades the stored config.
  SimulationConfig buildForRun() => applyProGates(build());

  /// Computes the non-blocking warnings that the UI should surface
  /// alongside the engine's blocking errors. Engine-owned design
  /// rules (inverter oversizing, bank-vs-battery, deep minSOC) live in
  /// `SimulationConfigWarnings.nonBlockingWarnings()`; this method maps
  /// each engine code to its owning [ConfigSection] and appends the one
  /// UI-only hint (synthetic-irradiance fallback) that depends on draft
  /// state the engine doesn't see.
  List<ValidationWarning> validationWarnings() {
    final out = <ValidationWarning>[];

    // Engine-owned design rules.
    final engineWarnings = build().nonBlockingWarnings();
    for (final w in engineWarnings) {
      out.add(ValidationWarning(
        code: w.code,
        severity: WarningSeverity.warning,
        section: _sectionForWarning(w.code),
        args: w.args,
      ));
    }

    // UI-only hint — depends on the draft's irradiance cache, which the
    // engine doesn't model. Nudges users toward the Einstrahlung tab.
    if (siteIrradiance.samples == null) {
      out.add(const ValidationWarning(
        code: 'irradiance-missing',
        severity: WarningSeverity.hint,
        section: ConfigSection.project,
      ));
    }

    return out;
  }

  static ConfigSection _sectionForWarning(String code) {
    switch (code) {
      case 'inverter-oversized':
        return ConfigSection.inverters;
      case 'bank-exceeds-discharge':
        return ConfigSection.banks;
      case 'battery-min-soc-high':
        return ConfigSection.batteries;
      default:
        return ConfigSection.unknown;
    }
  }

  /// Returns the first engine-validation failure as a [ValidationIssue]
  /// (classified to its owning [ConfigSection]) or `null` when the
  /// draft builds a valid [SimulationConfig]. Engine `validate()`
  /// throws on the first failure, so at most one issue can be returned.
  ValidationIssue? validationIssue() {
    try {
      build().validate();
      return null;
    } on ArgumentError catch (e) {
      final msg = e.message?.toString() ?? e.toString();
      return ValidationIssue(section: classifyValidationMessage(msg), message: msg);
    }
  }

  static ConfigDraft fromConfig(SimulationConfig config) => ConfigDraft(
        startDayOfYear: config.startDayOfYear,
        days: config.days,
        timeStep: config.timeStep,
        preRunDays: config.preRunDays,
        preRunMode: config.preRunMode,
        convergenceToleranceFraction: config.convergenceToleranceFraction,
        maxConvergenceIterations: config.maxConvergenceIterations,
        gridExportLimitKw: config.gridExportLimitKw,
        latitudeDeg: config.latitudeDeg,
        longitudeDeg: config.longitudeDeg,
        simulationYears: config.simulationYears,
        arrays: config.arrays.map(PvArrayDraft.fromArray).toList(),
        inverters: config.inverters.map(InverterDraft.fromInverter).toList(),
        batteries: config.batteries.map(BatteryDraft.fromBattery).toList(),
        microInverterBanks: config.microInverterBanks.map(MicroInverterBankDraft.fromBank).toList(),
        dispatchPolicy: DispatchPolicyDraft.fromPolicy(config.dispatchPolicy),
        loadProfile: LoadProfileDraft.fromProfile(config.loadProfile),
        topology: config.topology == null
            ? TopologyGraphDraft()
            : TopologyGraphDraft.fromGraph(config.topology!),
        tariff: TariffDraft.fromTariff(config.tariff),
      );

  static ConfigDraft demo() => ConfigDraft(
        arrays: [
          PvArrayDraft(id: 'south-roof', label: 'Süddach', peakKw: 4.8, azimuthDeg: 180, tiltDeg: 35, inverterId: 'main'),
        ],
        inverters: [
          InverterDraft(id: 'main', label: 'Hauptwechselrichter', maxAcKw: 5.0),
        ],
        batteries: [
          BatteryDraft(id: 'main', label: 'Hauptspeicher', capacityKwh: 7.5, maxChargeKw: 3.0, maxDischargeKw: 3.0, minSocKwh: 0.5),
        ],
        loadProfile: LoadProfileDraft(dailyKwh: 10.5),
        days: 365,
        preRunDays: 365,
        gridExportLimitKw: 6.0,
        latitudeDeg: 50.1,
        longitudeDeg: 8.6,
      );
}

class PvArrayDraft {
  PvArrayDraft({
    required this.id,
    this.label = '',
    this.peakKw = 1.0,
    this.azimuthDeg = 180,
    this.tiltDeg = 35,
    this.inverterId = '',
    this.lossFactor = 0.14,
    this.shadingFactor = 0.0,
    this.temperatureCoefficientPctPerC = 0.0,
    this.nominalOperatingCellTempC = 45.0,
    this.degradationPctPerYear = 0.0,
  });

  String id;
  String label;
  double peakKw;
  double azimuthDeg;
  double tiltDeg;
  String inverterId;
  double lossFactor;
  double shadingFactor;
  double temperatureCoefficientPctPerC;
  double nominalOperatingCellTempC;
  double degradationPctPerYear;

  PvArray build() => PvArray(
        id: id,
        label: label,
        peakKw: peakKw,
        azimuthDeg: azimuthDeg,
        tiltDeg: tiltDeg,
        inverterId: inverterId,
        lossFactor: lossFactor,
        shadingFactor: shadingFactor,
        temperatureCoefficientPctPerC: temperatureCoefficientPctPerC,
        nominalOperatingCellTempC: nominalOperatingCellTempC,
        degradationPctPerYear: degradationPctPerYear,
      );

  static PvArrayDraft fromArray(PvArray a) => PvArrayDraft(
        id: a.id,
        label: a.label,
        peakKw: a.peakKw,
        azimuthDeg: a.azimuthDeg,
        tiltDeg: a.tiltDeg,
        inverterId: a.inverterId,
        lossFactor: a.lossFactor,
        shadingFactor: a.shadingFactor,
        temperatureCoefficientPctPerC: a.temperatureCoefficientPctPerC,
        nominalOperatingCellTempC: a.nominalOperatingCellTempC,
        degradationPctPerYear: a.degradationPctPerYear,
      );
}

class InverterDraft {
  InverterDraft({
    required this.id,
    this.label = '',
    this.maxAcKw = 5.0,
    this.role = InverterRole.grid,
    this.efficiency = 0.965,
    this.maxDcInputKw,
  });

  String id;
  String label;
  double maxAcKw;
  InverterRole role;
  double efficiency;
  double? maxDcInputKw;

  Inverter build() => Inverter(
        id: id, label: label, maxAcKw: maxAcKw, role: role, efficiency: efficiency,
        maxDcInputKw: maxDcInputKw,
      );

  static InverterDraft fromInverter(Inverter i) => InverterDraft(
        id: i.id, label: i.label, maxAcKw: i.maxAcKw, role: i.role, efficiency: i.efficiency,
        maxDcInputKw: i.maxDcInputKw,
      );
}

class BatteryDraft {
  BatteryDraft({
    required this.id,
    this.label = '',
    this.capacityKwh = 5.0,
    this.maxChargeKw = 2.5,
    this.maxDischargeKw = 2.5,
    this.roundTripEfficiency = 0.9,
    this.minSocKwh = 0.0,
    this.initialSocKwh,
  });

  String id;
  String label;
  double capacityKwh;
  double maxChargeKw;
  double maxDischargeKw;
  double roundTripEfficiency;
  double minSocKwh;
  double? initialSocKwh;

  BatteryConfig build() => BatteryConfig(
        id: id,
        label: label,
        capacityKwh: capacityKwh,
        maxChargeKw: maxChargeKw,
        maxDischargeKw: maxDischargeKw,
        roundTripEfficiency: roundTripEfficiency,
        minSocKwh: minSocKwh,
        initialSocKwh: initialSocKwh,
      );

  static BatteryDraft fromBattery(BatteryConfig b) => BatteryDraft(
        id: b.id,
        label: b.label,
        capacityKwh: b.capacityKwh,
        maxChargeKw: b.maxChargeKw,
        maxDischargeKw: b.maxDischargeKw,
        roundTripEfficiency: b.roundTripEfficiency,
        minSocKwh: b.minSocKwh,
        initialSocKwh: b.initialSocKwh,
      );
}

class LoadProfileDraft {
  LoadProfileDraft({this.dailyKwh = 10.0, List<double>? hourlyShape})
      : hourlyShape = hourlyShape ?? List<double>.from(const LoadProfile(dailyKwh: 0).hourlyShape);

  double dailyKwh;
  List<double> hourlyShape;

  LoadProfile build() => LoadProfile(dailyKwh: dailyKwh, hourlyShape: List.unmodifiable(hourlyShape));

  static LoadProfileDraft fromProfile(LoadProfile p) =>
      LoadProfileDraft(dailyKwh: p.dailyKwh, hourlyShape: List<double>.from(p.hourlyShape));
}

/// Mutable working copy of a [TariffConfig]. When [enabled] is `false`
/// [build] returns `null` and the engine skips the cashflow path —
/// matches the "no tariff" default for legacy projects. When [enabled]
/// is `true` the flat prices always apply; the 24-slot TOU arrays only
/// reach the engine in Pro builds (mirrors the cyclic-convergence
/// gating pattern).
///
/// Invariant: [hourlyImportPrices] and [hourlyExportPrices] are ALWAYS
/// length 24. Imported tariffs with shorter / longer arrays are
/// padded/truncated by [fromTariff] so the widget layer can index
/// `[0..23]` without bounds checks. A length-mismatched JSON would
/// also have failed engine validation, but normalising here keeps the
/// editor open so the user can fix the import.
class TariffDraft {
  TariffDraft({
    this.enabled = false,
    this.importPricePerKwh = 0.30,
    this.exportPricePerKwh = 0.08,
    this.touEnabled = false,
    List<double>? hourlyImportPrices,
    List<double>? hourlyExportPrices,
  })  : hourlyImportPrices = hourlyImportPrices ??
            List<double>.filled(24, 0.30),
        hourlyExportPrices = hourlyExportPrices ??
            List<double>.filled(24, 0.08);

  bool enabled;
  double importPricePerKwh;
  double exportPricePerKwh;

  /// When `true`, the 24-slot arrays are passed through to the engine
  /// (assuming Pro is on at build time). Always rendered editable in
  /// the form so the user can prepare values for an eventual Pro build.
  bool touEnabled;

  List<double> hourlyImportPrices;
  List<double> hourlyExportPrices;

  /// Builds the engine [TariffConfig].
  ///
  /// [includeTou] selects whether the 24-slot arrays are emitted: `true`
  /// for the persistence path (so Pro-authored TOU schedules survive a
  /// save/load round-trip in a free build) and `false` for the run
  /// path in a free build (so the engine actually sees only the flat
  /// prices). [ConfigDraft.build] / [ConfigDraft.buildForRun] route
  /// these for callers; direct callers can pass the flag explicitly.
  TariffConfig? build({bool includeTou = true}) {
    if (!enabled) return null;
    final useTou = touEnabled && includeTou;
    return TariffConfig(
      importPricePerKwh: importPricePerKwh,
      exportPricePerKwh: exportPricePerKwh,
      hourlyImportPrices: useTou ? List<double>.unmodifiable(hourlyImportPrices) : null,
      hourlyExportPrices: useTou ? List<double>.unmodifiable(hourlyExportPrices) : null,
    );
  }

  static TariffDraft fromTariff(TariffConfig? t) {
    if (t == null) return TariffDraft();
    // Engine TariffConfig allows hourlyImportPrices and hourlyExportPrices
    // to be set independently — a tariff can have TOU import + flat
    // export. The draft stores both arrays unconditionally (24 entries
    // each), so when only one side is set we fill the missing side
    // with the flat price replicated 24× so build() round-trips to the
    // same effective tariff (the engine treats a flat-replicated array
    // identically to a null array + flat price).
    return TariffDraft(
      enabled: true,
      importPricePerKwh: t.importPricePerKwh,
      exportPricePerKwh: t.exportPricePerKwh,
      touEnabled: t.hourlyImportPrices != null || t.hourlyExportPrices != null,
      hourlyImportPrices: _normalize24(t.hourlyImportPrices, t.importPricePerKwh),
      hourlyExportPrices: _normalize24(t.hourlyExportPrices, t.exportPricePerKwh),
    );
  }

  /// Normalises an incoming TOU array to exactly 24 entries by padding
  /// with [fill] or truncating. Defends both `_HourlyGrid` (which
  /// indexes 0..23 unconditionally) and the engine's `validate()`
  /// length check against malformed imports.
  static List<double> _normalize24(List<double>? src, double fill) {
    if (src == null) return List<double>.filled(24, fill);
    if (src.length == 24) return List<double>.from(src);
    if (src.length > 24) return List<double>.from(src.take(24));
    return <double>[
      ...src,
      ...List<double>.filled(24 - src.length, fill),
    ];
  }
}

/// Which schedule kind a [MicroInverterBankDraft] is currently editing.
/// Maps 1:1 to the engine's three [BankSchedule] implementations.
enum BankScheduleKind { alwaysOn, timeWindows, hourly }

/// Mutable working copy of a [MicroInverterBank]. [scheduleKind]
/// selects which of the three engine [BankSchedule] subtypes
/// [buildSchedule] returns; the per-kind editor state ([windows] for
/// time windows, [hourlyFactors] for hourly) is kept side-by-side so a
/// user who flips back and forth doesn't lose the values they typed.
class MicroInverterBankDraft {
  MicroInverterBankDraft({
    required this.id,
    this.label = '',
    this.batteryId = '',
    this.count = 1,
    this.unitRatedPowerW = 800.0,
    this.minSocShutdown = 0.0,
    this.inverterEfficiency = 0.95,
    this.scheduleKind = BankScheduleKind.alwaysOn,
    List<TimeWindowDraft>? windows,
    List<double>? hourlyFactors,
  })  : windows = windows ?? <TimeWindowDraft>[],
        hourlyFactors = hourlyFactors ?? List<double>.filled(24, 1.0);

  String id;
  String label;
  String batteryId;
  int count;
  double unitRatedPowerW;
  double minSocShutdown;
  double inverterEfficiency;

  /// Which engine schedule kind [buildSchedule] returns.
  BankScheduleKind scheduleKind;

  /// Editor state for [BankScheduleKind.timeWindows].
  final List<TimeWindowDraft> windows;

  /// Editor state for [BankScheduleKind.hourly]. Length is always 24;
  /// each entry is the factor (0..1) for the hour starting at that index.
  final List<double> hourlyFactors;

  BankSchedule buildSchedule() {
    switch (scheduleKind) {
      case BankScheduleKind.alwaysOn:
        return const AlwaysOnSchedule();
      case BankScheduleKind.timeWindows:
        return TimeWindowSchedule(
          windows
              .map((w) => TimeWindow(startHour: w.startHour, endHour: w.endHour, factor: w.factor))
              .toList(growable: false),
        );
      case BankScheduleKind.hourly:
        return HourlySchedule(List<double>.unmodifiable(hourlyFactors));
    }
  }

  MicroInverterBank build() => MicroInverterBank(
        id: id,
        label: label,
        batteryId: batteryId,
        count: count,
        unitRatedPowerW: unitRatedPowerW,
        minSocShutdown: minSocShutdown,
        inverterEfficiency: inverterEfficiency,
        schedule: buildSchedule(),
      );

  static MicroInverterBankDraft fromBank(MicroInverterBank b) {
    final draft = MicroInverterBankDraft(
      id: b.id,
      label: b.label,
      batteryId: b.batteryId,
      count: b.count,
      unitRatedPowerW: b.unitRatedPowerW,
      minSocShutdown: b.minSocShutdown,
      inverterEfficiency: b.inverterEfficiency,
    );
    final sched = b.schedule;
    if (sched is TimeWindowSchedule) {
      draft.scheduleKind = BankScheduleKind.timeWindows;
      draft.windows.addAll(sched.windows.map((w) => TimeWindowDraft(
            startHour: w.startHour,
            endHour: w.endHour,
            factor: w.factor,
          )));
    } else if (sched is HourlySchedule) {
      draft.scheduleKind = BankScheduleKind.hourly;
      for (var i = 0; i < 24 && i < sched.factors.length; i++) {
        draft.hourlyFactors[i] = sched.factors[i];
      }
    }
    return draft;
  }
}

class TimeWindowDraft {
  TimeWindowDraft({this.startHour = 18.0, this.endHour = 22.0, this.factor = 1.0});

  double startHour;
  double endHour;
  double factor;
}

/// Mutable working copy of a [DispatchPolicy]. The UI flips between
/// the five built-in policies via [DispatchPolicyKind]; per-policy
/// parameters live in dedicated fields so switching kinds doesn't
/// silently throw away the user's last input for the chosen policy.
enum DispatchPolicyKind {
  selfConsumption,
  batteryReserve,
  constantFeed24h,
  timeWindowFeed,
  gridAssist,
}

class DispatchPolicyDraft {
  DispatchPolicyDraft({
    this.kind = DispatchPolicyKind.selfConsumption,
    this.reserveSocFraction = 0.5,
    this.gridAssistAllowImport = false,
  });

  DispatchPolicyKind kind;

  /// Used by [DispatchPolicyKind.batteryReserve].
  double reserveSocFraction;

  /// Used by [DispatchPolicyKind.gridAssist].
  bool gridAssistAllowImport;

  factory DispatchPolicyDraft.selfConsumption() =>
      DispatchPolicyDraft(kind: DispatchPolicyKind.selfConsumption);

  DispatchPolicy build() {
    switch (kind) {
      case DispatchPolicyKind.selfConsumption:
        return const SelfConsumptionFirstPolicy();
      case DispatchPolicyKind.batteryReserve:
        return BatteryReservePolicy(reserveSocFraction: reserveSocFraction);
      case DispatchPolicyKind.constantFeed24h:
        return const ConstantFeed24hPolicy();
      case DispatchPolicyKind.timeWindowFeed:
        return const TimeWindowFeedPolicy();
      case DispatchPolicyKind.gridAssist:
        return GridAssistPolicy(allowGridImport: gridAssistAllowImport);
    }
  }

  static DispatchPolicyDraft fromPolicy(DispatchPolicy? policy) {
    if (policy == null || policy is SelfConsumptionFirstPolicy) {
      return DispatchPolicyDraft();
    }
    if (policy is BatteryReservePolicy) {
      return DispatchPolicyDraft(
        kind: DispatchPolicyKind.batteryReserve,
        reserveSocFraction: policy.reserveSocFraction,
      );
    }
    if (policy is TimeWindowFeedPolicy) {
      return DispatchPolicyDraft(kind: DispatchPolicyKind.timeWindowFeed);
    }
    if (policy is ConstantFeed24hPolicy) {
      return DispatchPolicyDraft(kind: DispatchPolicyKind.constantFeed24h);
    }
    if (policy is GridAssistPolicy) {
      return DispatchPolicyDraft(
        kind: DispatchPolicyKind.gridAssist,
        gridAssistAllowImport: policy.allowGridImport,
      );
    }
    return DispatchPolicyDraft();
  }
}

/// Mutable working copy of an engine [DcBus].
class DcBusDraft {
  DcBusDraft({required this.id, this.label = ''});
  String id;
  String label;

  DcBus build() => DcBus(id: id, label: label);
  static DcBusDraft fromBus(DcBus b) => DcBusDraft(id: b.id, label: b.label);
}

/// Mutable working copy of an engine [AcBus].
class AcBusDraft {
  AcBusDraft({required this.id, this.label = ''});
  String id;
  String label;

  AcBus build() => AcBus(id: id, label: label);
  static AcBusDraft fromBus(AcBus b) => AcBusDraft(id: b.id, label: b.label);
}

/// Mutable working copy of an engine [MpptNode]. The editor renders MPPTs
/// as read-only; they are auto-synced from the project's inverter list
/// when [TopologyGraphDraft.seedFromConfig] is called.
class MpptNodeDraft {
  MpptNodeDraft({required this.id, required this.inverterId, this.label = ''});
  String id;
  String inverterId;
  String label;

  MpptNode build() => MpptNode(id: id, inverterId: inverterId, label: label);
  static MpptNodeDraft fromNode(MpptNode m) =>
      MpptNodeDraft(id: m.id, inverterId: m.inverterId, label: m.label);
}

/// Mutable working copy of an engine [BusEdge]. Edges declare directed
/// flows with optional efficiency, max power and standby load, per
/// Architektur §4.
class BusEdgeDraft {
  BusEdgeDraft({
    required this.fromId,
    required this.toId,
    this.efficiency = 1.0,
    this.maxPowerKw,
    this.standbyW = 0.0,
  });

  String fromId;
  String toId;
  double efficiency;
  double? maxPowerKw;
  double standbyW;

  BusEdge build() => BusEdge(
        fromId: fromId,
        toId: toId,
        efficiency: efficiency,
        maxPowerKw: maxPowerKw,
        standbyW: standbyW,
      );
  static BusEdgeDraft fromEdge(BusEdge e) => BusEdgeDraft(
        fromId: e.fromId,
        toId: e.toId,
        efficiency: e.efficiency,
        maxPowerKw: e.maxPowerKw,
        standbyW: e.standbyW,
      );
}

/// Mutable working copy of an engine [BatteryCouplingSpec]. The `acCoupled`
/// flag mirrors the engine enum (true = AC, false = DC); `dcBusId` is
/// required when DC-coupled, `inverterId` is only meaningful for AC.
class BatteryCouplingDraft {
  BatteryCouplingDraft({
    required this.batteryId,
    this.acCoupled = true,
    this.dcBusId,
    this.inverterId,
  });

  String batteryId;
  bool acCoupled;
  String? dcBusId;
  String? inverterId;

  BatteryCouplingSpec build() => BatteryCouplingSpec(
        batteryId: batteryId,
        coupling: acCoupled ? BatteryCoupling.ac : BatteryCoupling.dc,
        dcBusId: dcBusId,
        inverterId: inverterId,
      );

  static BatteryCouplingDraft fromSpec(BatteryCouplingSpec spec) =>
      BatteryCouplingDraft(
        batteryId: spec.batteryId,
        acCoupled: spec.coupling == BatteryCoupling.ac,
        dcBusId: spec.dcBusId,
        inverterId: spec.inverterId,
      );
}

/// Mutable working copy of a [TopologyGraph]. While [enabled] is `false`
/// the engine falls back to `TopologyGraph.fromLegacy` and the draft is
/// not persisted. Toggling `enabled` to `true` typically triggers
/// [seedFromConfig] so the user starts from a working baseline they can
/// edit, rather than an empty graph that would fail validation.
class TopologyGraphDraft {
  TopologyGraphDraft({
    this.enabled = false,
    List<DcBusDraft>? dcBuses,
    List<AcBusDraft>? acBuses,
    List<MpptNodeDraft>? mppts,
    List<BusEdgeDraft>? edges,
    List<BatteryCouplingDraft>? couplings,
  })  : dcBuses = dcBuses ?? <DcBusDraft>[],
        acBuses = acBuses ?? <AcBusDraft>[],
        mppts = mppts ?? <MpptNodeDraft>[],
        edges = edges ?? <BusEdgeDraft>[],
        couplings = couplings ?? <BatteryCouplingDraft>[];

  bool enabled;
  final List<DcBusDraft> dcBuses;
  final List<AcBusDraft> acBuses;
  final List<MpptNodeDraft> mppts;
  final List<BusEdgeDraft> edges;
  final List<BatteryCouplingDraft> couplings;

  /// Replaces the draft contents with [TopologyGraph.fromLegacy] derived
  /// from the current flat lists in [ConfigDraft]. Used when the user
  /// flips the master switch on, or clicks "Seed from current setup"
  /// after adding/removing inverters or batteries.
  void seedFromConfig(ConfigDraft draft) {
    final legacy = TopologyGraph.fromLegacy(
      arrayIds: draft.arrays.map((a) => a.id),
      inverterIds: draft.inverters.map((i) => i.id),
      batteryIds: draft.batteries.map((b) => b.id),
      bankIds: draft.microInverterBanks.map((b) => b.id),
      arrayToInverter: draft.arrays.map((a) => MapEntry(a.id, a.inverterId)),
      inverterMaxAc: draft.inverters.map((i) {
        final cap = i.role == InverterRole.microInverter800W
            ? (i.maxAcKw < 0.8 ? i.maxAcKw : 0.8)
            : i.maxAcKw;
        return MapEntry(i.id, cap);
      }),
      inverterMaxDcInput: draft.inverters.map((i) => MapEntry(i.id, i.maxDcInputKw)),
      inverterEfficiency: draft.inverters.map((i) => MapEntry(i.id, i.efficiency)),
    );
    _replaceWith(legacy);
  }

  void _replaceWith(TopologyGraph graph) {
    dcBuses
      ..clear()
      ..addAll(graph.dcBuses.map(DcBusDraft.fromBus));
    acBuses
      ..clear()
      ..addAll(graph.acBuses.map(AcBusDraft.fromBus));
    mppts
      ..clear()
      ..addAll(graph.mppts.map(MpptNodeDraft.fromNode));
    edges
      ..clear()
      ..addAll(graph.edges.map(BusEdgeDraft.fromEdge));
    couplings
      ..clear()
      ..addAll(graph.batteryCouplings.map(BatteryCouplingDraft.fromSpec));
  }

  TopologyGraph build() => TopologyGraph(
        dcBuses: dcBuses.map((b) => b.build()).toList(growable: false),
        acBuses: acBuses.map((b) => b.build()).toList(growable: false),
        mppts: mppts.map((m) => m.build()).toList(growable: false),
        edges: edges.map((e) => e.build()).toList(growable: false),
        batteryCouplings: couplings.map((c) => c.build()).toList(growable: false),
      );

  static TopologyGraphDraft fromGraph(TopologyGraph graph) {
    final draft = TopologyGraphDraft(enabled: true);
    draft._replaceWith(graph);
    return draft;
  }
}
