import 'package:pv_engine/pv_engine.dart';

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
  unknown,
}

/// A classified engine-validation failure. Routed to a section so the
/// user sees the message next to the field they need to fix.
class ValidationIssue {
  const ValidationIssue({required this.section, required this.message});
  final ConfigSection section;
  final String message;
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
  if (m.contains('topology') ||
      m.contains('dcbus') ||
      m.contains('acbus') ||
      m.contains('mppt')) {
    return ConfigSection.topology;
  }
  if (m.contains('load ') ||
      m.contains('dailykwh') ||
      m.contains('hourlyshape')) {
    return ConfigSection.load;
  }
  if (m.contains('latitudedeg') ||
      m.contains('longitudedeg') ||
      m.contains('startdayofyear') ||
      m.contains('preRunDays'.toLowerCase()) ||
      m.contains('gridexportlimit') ||
      m.contains('days must')) {
    return ConfigSection.project;
  }
  return ConfigSection.unknown;
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
    this.gridExportLimitKw,
    this.latitudeDeg = 50.0,
    this.longitudeDeg = 10.0,
    SiteIrradianceDraft? siteIrradiance,
    List<PvArrayDraft>? arrays,
    List<InverterDraft>? inverters,
    List<BatteryDraft>? batteries,
    List<MicroInverterBankDraft>? microInverterBanks,
    DispatchPolicyDraft? dispatchPolicy,
    LoadProfileDraft? loadProfile,
  })  : siteIrradiance = siteIrradiance ?? SiteIrradianceDraft(),
        arrays = arrays ?? <PvArrayDraft>[],
        inverters = inverters ?? <InverterDraft>[],
        batteries = batteries ?? <BatteryDraft>[],
        microInverterBanks = microInverterBanks ?? <MicroInverterBankDraft>[],
        dispatchPolicy = dispatchPolicy ?? DispatchPolicyDraft.selfConsumption(),
        loadProfile = loadProfile ?? LoadProfileDraft();

  int startDayOfYear;
  int days;
  TimeStep timeStep;
  int preRunDays;
  double? gridExportLimitKw;
  double latitudeDeg;
  double longitudeDeg;

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
      loadProfile: loadProfile.build(),
      startDayOfYear: startDayOfYear,
      days: days,
      timeStep: timeStep,
      preRunDays: preRunDays,
      gridExportLimitKw: gridExportLimitKw,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      weatherSource: buildWeatherSource(),
    );
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
        gridExportLimitKw: config.gridExportLimitKw,
        latitudeDeg: config.latitudeDeg,
        longitudeDeg: config.longitudeDeg,
        arrays: config.arrays.map(PvArrayDraft.fromArray).toList(),
        inverters: config.inverters.map(InverterDraft.fromInverter).toList(),
        batteries: config.batteries.map(BatteryDraft.fromBattery).toList(),
        microInverterBanks: config.microInverterBanks.map(MicroInverterBankDraft.fromBank).toList(),
        dispatchPolicy: DispatchPolicyDraft.fromPolicy(config.dispatchPolicy),
        loadProfile: LoadProfileDraft.fromProfile(config.loadProfile),
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

/// Mutable working copy of a [MicroInverterBank]. The UI only edits
/// always-on and time-window schedules. Other engine schedule kinds
/// (e.g. [HourlySchedule]) are preserved verbatim in [preservedSchedule]
/// so opening and saving a project does not silently rewrite them.
class MicroInverterBankDraft {
  MicroInverterBankDraft({
    required this.id,
    this.label = '',
    this.batteryId = '',
    this.count = 1,
    this.unitRatedPowerW = 800.0,
    this.minSocShutdown = 0.0,
    this.inverterEfficiency = 0.95,
    List<TimeWindowDraft>? windows,
    this.preservedSchedule,
  }) : windows = windows ?? <TimeWindowDraft>[];

  String id;
  String label;
  String batteryId;
  int count;
  double unitRatedPowerW;
  double minSocShutdown;
  double inverterEfficiency;

  /// Empty list = fall back to [preservedSchedule] or
  /// [AlwaysOnSchedule]. Non-empty = [TimeWindowSchedule].
  final List<TimeWindowDraft> windows;

  /// Engine schedule the draft was loaded from when it is not one of
  /// the kinds the UI can edit directly (currently: [HourlySchedule]).
  /// Survives round-trip until the user explicitly adds a window, at
  /// which point [buildSchedule] returns the new [TimeWindowSchedule].
  BankSchedule? preservedSchedule;

  BankSchedule buildSchedule() {
    if (windows.isNotEmpty) {
      return TimeWindowSchedule(
        windows
            .map((w) => TimeWindow(startHour: w.startHour, endHour: w.endHour, factor: w.factor))
            .toList(growable: false),
      );
    }
    return preservedSchedule ?? const AlwaysOnSchedule();
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
      draft.windows.addAll(sched.windows.map((w) => TimeWindowDraft(
            startHour: w.startHour,
            endHour: w.endHour,
            factor: w.factor,
          )));
    } else if (sched is! AlwaysOnSchedule) {
      draft.preservedSchedule = sched;
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
