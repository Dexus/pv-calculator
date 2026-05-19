import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'src/dispatch_policies.dart';
import 'src/dispatch_policy.dart';
import 'src/energy_router.dart';
import 'src/hash.dart';
import 'src/micro_inverter_bank.dart';
import 'src/tariff.dart';
import 'src/temperature_model.dart';
import 'src/topology.dart';
import 'src/weather.dart';

export 'src/csv_export.dart';
export 'src/dispatch_policies.dart';
export 'src/load_profile_csv.dart';
export 'src/dispatch_policy.dart';
export 'src/energy_router.dart';
export 'src/hash.dart';
export 'src/micro_inverter_bank.dart';
export 'src/pvgis.dart';
export 'src/pvgis_client.dart';
export 'src/tariff.dart';
export 'src/temperature_model.dart';
export 'src/topology.dart';
export 'src/transposition.dart';
export 'src/weather.dart';

// summary_aggregator lives as a `part of` file so it can read the
// engine-private `_StepBuffer` columns directly without exposing them.
part 'src/summary_aggregator.dart';

// optimizer is `part of` so it can reach the engine's public types
// (SimulationConfig, SimulationSummary, PvSimulator) without an
// import cycle. No engine-private state is touched.
part 'src/optimizer.dart';

/// Version of the simulation engine — must track
/// `packages/pv_engine/pubspec.yaml` `version:` and is bumped on every
/// change that can shift simulation results. Persisted alongside scenarios
/// and simulation runs for reproducibility (PRD NFR-05).
const String kEngineVersion = '0.15.0';

/// Reproducibility helpers on [SimulationConfig]. Kept as an extension so
/// the core class stays pure data — adding `inputHash` here makes it clear
/// the value is derived from `toJson()` and does not participate in
/// equality or persistence directly.
extension SimulationConfigReproducibility on SimulationConfig {
  /// Canonical, deterministic hex fingerprint of the config's JSON form.
  /// Two configs with the same `toJson()` content (regardless of map
  /// insertion order) yield the same hash.
  String get inputHash => fnv1a64Hex(canonicalJsonEncode(toJson()));
}

/// Stable, non-blocking design check emitted by
/// [SimulationConfigWarnings.nonBlockingWarnings]. [code] is a stable
/// identifier; callers map it to a localized message and substitute the
/// per-warning [args] into the placeholders.
class SimulationWarning {
  const SimulationWarning({required this.code, this.args = const {}});

  final String code;
  final Map<String, String> args;
}

extension SimulationConfigWarnings on SimulationConfig {
  /// Non-blocking design checks. Never throws. Independent of
  /// [SimulationConfig.validate]: a configuration may simultaneously
  /// produce validation errors and warnings, and warnings may fire on a
  /// partially-edited draft. Returns stable codes plus the numeric data
  /// the caller needs to compose a message — no text, no localization.
  List<SimulationWarning> nonBlockingWarnings() {
    final out = <SimulationWarning>[];

    // 1) Inverter oversizing — DC peak summed across attached arrays
    //    exceeding 1.3× the inverter's AC cap chronically clips daytime
    //    output. Strict `>` so the threshold itself stays silent.
    for (final inv in inverters) {
      if (inv.maxAcKw <= 0) continue;
      final dcPeak = arrays
          .where((a) => a.inverterId == inv.id)
          .fold<double>(0, (s, a) => s + a.peakKw);
      final ratio = dcPeak / inv.maxAcKw;
      if (ratio > 1.3) {
        out.add(SimulationWarning(
          code: 'inverter-oversized',
          args: {
            'inverter': inv.label.isEmpty ? inv.id : inv.label,
            'ratio': ratio.toStringAsFixed(2),
          },
        ));
      }
    }

    // 2) Bank target exceeds battery discharge — the rated AC output of
    //    a bank above the coupled battery's `maxDischargeKw` produces a
    //    chronic shortfall. `1e-9` epsilon so floats at the cap stay
    //    silent.
    for (final bank in microInverterBanks) {
      BatteryConfig? battery;
      for (final b in batteries) {
        if (b.id == bank.batteryId) {
          battery = b;
          break;
        }
      }
      if (battery == null) continue;
      final bankAcKw = bank.count * bank.unitRatedPowerW / 1000.0;
      if (bankAcKw > battery.maxDischargeKw + 1e-9) {
        out.add(SimulationWarning(
          code: 'bank-exceeds-discharge',
          args: {
            'bank': bank.label.isEmpty ? bank.id : bank.label,
            'bankKw': bankAcKw.toStringAsFixed(2),
            'dischargeKw': battery.maxDischargeKw.toStringAsFixed(2),
          },
        ));
      }
    }

    // 3) Deep min-SOC — locking away more than half of nominal capacity
    //    is almost always a misclick.
    for (final battery in batteries) {
      if (battery.capacityKwh <= 0) continue;
      final fraction = battery.minSocKwh / battery.capacityKwh;
      if (fraction > 0.5) {
        out.add(SimulationWarning(
          code: 'battery-min-soc-high',
          args: {
            'battery': battery.label.isEmpty ? battery.id : battery.label,
            'pct': (fraction * 100).toStringAsFixed(0),
          },
        ));
      }
    }

    return out;
  }
}

enum InverterRole { grid, microInverter800W, batteryCoupled }

enum TimeStep {
  hourly(60),
  quarterHourly(15);

  const TimeStep(this.minutes);
  final int minutes;
  double get hours => minutes / 60.0;
  int get stepsPerDay => (24 * 60 / minutes).round();
}

/// Strategy for initialising the battery state of charge before the
/// reported simulation year begins.
///
/// Per `docs/PRD_PV_Calculator_Flutter_App.md` §6.2 and
/// `docs/Architekturkonzept_PV_Calculator_Flutter_App.md` §6: a Jahres-
/// simulation that starts with an arbitrary 0 %, 50 % or 100 % SOC
/// distorts the January values. Three strategies are supported here;
/// "Previous-Year Weather" (Architektur §6) is deferred to Phase 10
/// because it depends on multi-year weather data.
enum PreRunMode {
  /// User-supplied start SOC (`BatteryConfig.initialSocKwh`, or the
  /// 50 %-of-capacity default when null) is used as-is. No warm-up.
  manual,

  /// Simulates `SimulationConfig.preRunDays` once before the reported
  /// year; the warm-up's end SOC becomes the reported year's start SOC.
  /// Matches the pre-Phase-5 behaviour and is the default for legacy
  /// JSON.
  singleWarmUp,

  /// Repeats the full 365-day year until the per-battery start↔end SOC
  /// delta falls below `convergenceToleranceFraction × usableCapacity`
  /// (usable = capacity − minSoc) for every battery, or
  /// `maxConvergenceIterations` is reached. The engine accepts this
  /// value unconditionally; any Pro/Free restriction is enforced by the
  /// calling UI (see Flutter `kProFeatures`), not here.
  cyclicConvergence,
}

class PvArray {
  const PvArray({
    required this.id,
    required this.label,
    required this.peakKw,
    required this.azimuthDeg,
    required this.tiltDeg,
    required this.inverterId,
    this.lossFactor = 0.14,
    this.shadingFactor = 0.0,
    this.temperatureCoefficientPctPerC = 0.0,
    this.nominalOperatingCellTempC = 45.0,
    this.degradationPctPerYear = 0.0,
  });

  final String id;
  final String label;
  final double peakKw;
  final double azimuthDeg;
  final double tiltDeg;
  final String inverterId;
  final double lossFactor;
  final double shadingFactor;

  /// Module power temperature coefficient in %/°C. Typical crystalline
  /// silicon is around -0.4. Default 0.0 keeps the legacy synthetic
  /// model untouched — set a negative value to enable temperature
  /// derating.
  final double temperatureCoefficientPctPerC;

  /// Nominal Operating Cell Temperature (NOCT) of the module in °C.
  /// Used by [NoctTemperatureModel] to translate ambient + irradiance
  /// into operating cell temperature. Typical 45–48 °C.
  final double nominalOperatingCellTempC;

  /// Annual module degradation in percent per year. Typical crystalline
  /// silicon: 0.4–0.7. Only used when `SimulationConfig.simulationYears
  /// > 1`; for single-year runs the array's nominal `peakKw` is used
  /// directly. Default 0.0 means no degradation (pre-Phase-10 behaviour).
  final double degradationPctPerYear;

  /// Returns a copy with `peakKw` derated for `year` years of operation.
  /// `peakKw_eff = peakKw × (1 − degradationPctPerYear/100)^year`.
  PvArray deratedForYear(int year) {
    if (year <= 0 || degradationPctPerYear <= 0) return this;
    final factor = math.pow(1 - degradationPctPerYear / 100.0, year).toDouble();
    return PvArray(
      id: id,
      label: label,
      peakKw: peakKw * factor,
      azimuthDeg: azimuthDeg,
      tiltDeg: tiltDeg,
      inverterId: inverterId,
      lossFactor: lossFactor,
      shadingFactor: shadingFactor,
      temperatureCoefficientPctPerC: temperatureCoefficientPctPerC,
      nominalOperatingCellTempC: nominalOperatingCellTempC,
      degradationPctPerYear: degradationPctPerYear,
    );
  }

  void validate() {
    _require(id.trim().isNotEmpty, 'PV array id must not be empty.');
    _require(peakKw > 0, 'PV array $id peakKw must be positive.');
    _require(tiltDeg >= 0 && tiltDeg <= 90, 'PV array $id tiltDeg must be between 0 and 90.');
    _require(lossFactor >= 0 && lossFactor < 1, 'PV array $id lossFactor must be in [0, 1).');
    _require(shadingFactor >= 0 && shadingFactor < 1, 'PV array $id shadingFactor must be in [0, 1).');
    _require(temperatureCoefficientPctPerC >= -2.0 && temperatureCoefficientPctPerC <= 0.0,
        'PV array $id temperatureCoefficientPctPerC must be in [-2, 0] %/°C.');
    _require(nominalOperatingCellTempC >= 20 && nominalOperatingCellTempC <= 70,
        'PV array $id nominalOperatingCellTempC must be in [20, 70] °C.');
    _require(degradationPctPerYear >= 0 && degradationPctPerYear < 10,
        'PV array $id degradationPctPerYear must be in [0, 10) %/year.');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'peakKw': peakKw,
        'azimuthDeg': azimuthDeg,
        'tiltDeg': tiltDeg,
        'inverterId': inverterId,
        'lossFactor': lossFactor,
        'shadingFactor': shadingFactor,
        'temperatureCoefficientPctPerC': temperatureCoefficientPctPerC,
        'nominalOperatingCellTempC': nominalOperatingCellTempC,
        // Omit the degradation key from JSON when it's at the default so
        // legacy projects round-trip byte-identically (input-hash stable).
        if (degradationPctPerYear != 0.0)
          'degradationPctPerYear': degradationPctPerYear,
      };

  static PvArray fromJson(Map<String, dynamic> json) => PvArray(
        id: (json['id'] as String).trim(),
        label: json['label'] as String,
        peakKw: _toDouble(json['peakKw']),
        azimuthDeg: _toDouble(json['azimuthDeg']),
        tiltDeg: _toDouble(json['tiltDeg']),
        inverterId: (json['inverterId'] as String).trim(),
        lossFactor: _toDouble(json['lossFactor'] ?? 0.14),
        shadingFactor: _toDouble(json['shadingFactor'] ?? 0.0),
        temperatureCoefficientPctPerC: _toDouble(json['temperatureCoefficientPctPerC'] ?? 0.0),
        nominalOperatingCellTempC: _toDouble(json['nominalOperatingCellTempC'] ?? 45.0),
        degradationPctPerYear: _toDouble(json['degradationPctPerYear'] ?? 0.0),
      );
}

class Inverter {
  const Inverter({
    required this.id,
    required this.label,
    required this.maxAcKw,
    this.role = InverterRole.grid,
    this.efficiency = 0.965,
    this.maxDcInputKw,
  });

  final String id;
  final String label;
  final double maxAcKw;
  final InverterRole role;
  final double efficiency;

  /// Optional DC input cap in kW. Models string/MPPT clipping when a
  /// PV array is oversized relative to the inverter (DC/AC ratio > 1):
  /// DC power exceeding this value is curtailed before AC conversion.
  /// `null` means no DC cap and the inverter is assumed to be sized
  /// for its arrays.
  final double? maxDcInputKw;

  double get effectiveMaxAcKw => role == InverterRole.microInverter800W ? math.min(maxAcKw, 0.8) : maxAcKw;

  void validate() {
    _require(id.trim().isNotEmpty, 'Inverter id must not be empty.');
    _require(maxAcKw > 0, 'Inverter $id maxAcKw must be positive.');
    _require(efficiency > 0 && efficiency <= 1, 'Inverter $id efficiency must be in (0, 1].');
    final dcLimit = maxDcInputKw;
    if (dcLimit != null) {
      _require(dcLimit > 0, 'Inverter $id maxDcInputKw must be positive.');
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'maxAcKw': maxAcKw,
        'role': role.name,
        'efficiency': efficiency,
        'maxDcInputKw': maxDcInputKw,
      };

  static Inverter fromJson(Map<String, dynamic> json) => Inverter(
        id: (json['id'] as String).trim(),
        label: json['label'] as String,
        maxAcKw: _toDouble(json['maxAcKw']),
        role: _inverterRoleFromName(json['role'] as String? ?? 'grid'),
        efficiency: _toDouble(json['efficiency'] ?? 0.965),
        maxDcInputKw: json['maxDcInputKw'] == null ? null : _toDouble(json['maxDcInputKw']),
      );
}

class BatteryConfig {
  const BatteryConfig({
    required this.id,
    required this.capacityKwh,
    required this.maxChargeKw,
    required this.maxDischargeKw,
    this.label = '',
    this.roundTripEfficiency = 0.9,
    this.minSocKwh = 0,
    this.initialSocKwh,
  });

  final String id;
  final String label;
  final double capacityKwh;
  final double maxChargeKw;
  final double maxDischargeKw;
  final double roundTripEfficiency;
  final double minSocKwh;
  final double? initialSocKwh;

  double get effectiveInitialSocKwh => (initialSocKwh ?? capacityKwh * 0.5).clamp(minSocKwh, capacityKwh).toDouble();
  double get chargeEfficiency => math.sqrt(roundTripEfficiency);
  double get dischargeEfficiency => math.sqrt(roundTripEfficiency);

  void validate() {
    _require(id.trim().isNotEmpty, 'Battery id must not be empty.');
    _require(capacityKwh >= 0, 'Battery $id capacityKwh must not be negative.');
    _require(maxChargeKw >= 0, 'Battery $id maxChargeKw must not be negative.');
    _require(maxDischargeKw >= 0, 'Battery $id maxDischargeKw must not be negative.');
    _require(roundTripEfficiency > 0 && roundTripEfficiency <= 1, 'Battery $id roundTripEfficiency must be in (0, 1].');
    _require(minSocKwh >= 0 && minSocKwh <= capacityKwh, 'Battery $id minSocKwh must be between 0 and capacityKwh.');
    final initial = initialSocKwh;
    if (initial != null) {
      _require(
        initial >= minSocKwh && initial <= capacityKwh,
        'Battery $id initialSocKwh must be between minSocKwh and capacityKwh.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'capacityKwh': capacityKwh,
        'maxChargeKw': maxChargeKw,
        'maxDischargeKw': maxDischargeKw,
        'roundTripEfficiency': roundTripEfficiency,
        'minSocKwh': minSocKwh,
        'initialSocKwh': initialSocKwh,
      };

  static BatteryConfig fromJson(Map<String, dynamic> json, {String fallbackId = 'battery-1'}) {
    final trimmedId = (json['id'] as String?)?.trim() ?? '';
    return BatteryConfig(
      id: trimmedId.isNotEmpty ? trimmedId : fallbackId,
      label: json['label'] as String? ?? '',
      capacityKwh: _toDouble(json['capacityKwh']),
      maxChargeKw: _toDouble(json['maxChargeKw']),
      maxDischargeKw: _toDouble(json['maxDischargeKw']),
      roundTripEfficiency: _toDouble(json['roundTripEfficiency'] ?? 0.9),
      minSocKwh: _toDouble(json['minSocKwh'] ?? 0),
      initialSocKwh: json['initialSocKwh'] == null ? null : _toDouble(json['initialSocKwh']),
    );
  }
}

class LoadProfile {
  const LoadProfile({
    required this.dailyKwh,
    this.hourlyShape = const [
      0.50, 0.45, 0.42, 0.40, 0.42, 0.55,
      0.85, 1.10, 0.95, 0.80, 0.75, 0.78,
      0.82, 0.78, 0.76, 0.85, 1.05, 1.45,
      1.70, 1.55, 1.30, 1.05, 0.78, 0.60,
    ],
  });

  final double dailyKwh;
  final List<double> hourlyShape;

  /// Energy demand for one simulation step.
  ///
  /// `hourlyShape` is a 24-bucket distribution, so at `TimeStep.quarterHourly`
  /// every quarter inside the same hour returns the same kWh share — the
  /// shape stays hourly-quantised regardless of step width. Total daily
  /// energy is conserved (sum over `stepsPerDay` equals `dailyKwh`).
  /// A 96-slot quarter-hourly shape is deferred to Phase 10.
  double energyKwhForStep({required double hourOfDay, required TimeStep timeStep}) {
    final hourIndex = hourOfDay.floor().clamp(0, 23).toInt();
    final shapeSum = hourlyShape.fold<double>(0.0, (sum, value) => sum + value);
    final hourlyEnergy = dailyKwh * hourlyShape[hourIndex] / shapeSum;
    return hourlyEnergy * timeStep.hours;
  }

  void validate() {
    _require(dailyKwh >= 0, 'Load dailyKwh must not be negative.');
    _require(hourlyShape.length == 24, 'Load hourlyShape must have 24 values.');
    _require(hourlyShape.every((value) => value >= 0), 'Load hourlyShape must not contain negative values.');
    _require(hourlyShape.fold<double>(0.0, (sum, value) => sum + value) > 0, 'Load hourlyShape sum must be positive.');
  }

  Map<String, dynamic> toJson() => {
        'dailyKwh': dailyKwh,
        'hourlyShape': hourlyShape,
      };

  static LoadProfile fromJson(Map<String, dynamic> json) {
    final shape = json['hourlyShape'];
    return LoadProfile(
      dailyKwh: _toDouble(json['dailyKwh']),
      hourlyShape: shape == null
          ? const LoadProfile(dailyKwh: 0).hourlyShape
          : (shape as List).map((e) => _toDouble(e)).toList(growable: false),
    );
  }
}

class SimulationConfig {
  const SimulationConfig({
    required this.arrays,
    required this.inverters,
    required this.loadProfile,
    this.batteries = const [],
    this.microInverterBanks = const [],
    this.topology,
    this.dispatchPolicy,
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
    this.weatherSource,
    this.temperatureModel = const NoctTemperatureModel(),
    this.keepSteps = true,
    this.simulationYears = 1,
    this.tariff,
    this.chargeControllers = const [],
  });

  final List<PvArray> arrays;
  final List<Inverter> inverters;
  final List<BatteryConfig> batteries;

  /// MPPT charge controllers (Laderegler) for DC-coupled topologies.
  /// Each controller feeds one [DcBus] (`cc.dcBusId`). When [topology]
  /// is `null` the simulator passes this list into
  /// [TopologyGraph.fromLegacy] so the auto-built graph still carries
  /// them; when [topology] is set explicitly this list must be empty
  /// (single source of truth — enforced by [validate]).
  final List<ChargeController> chargeControllers;

  /// Optional explicit topology. When `null` the simulator derives a
  /// default graph from `arrays`/`inverters`/`batteries`/`microInverterBanks`
  /// via [TopologyGraph.fromLegacy], preserving pre-Phase-4 behaviour.
  final TopologyGraph? topology;

  /// Pluggable dispatch strategy. Defaults to
  /// [SelfConsumptionFirstPolicy] when `null`, which reproduces the
  /// pre-Phase-4 dispatch order.
  final DispatchPolicy? dispatchPolicy;

  /// Battery-coupled AC outputs (e.g. 800-W class). Empty by default.
  final List<MicroInverterBank> microInverterBanks;

  final LoadProfile loadProfile;
  final int startDayOfYear;
  final int days;
  final TimeStep timeStep;
  final int preRunDays;

  /// Strategy used to settle the battery SOC before reporting begins.
  /// See [PreRunMode].
  final PreRunMode preRunMode;

  /// For [PreRunMode.cyclicConvergence]: the per-battery convergence
  /// threshold expressed as a fraction of usable capacity
  /// (`capacity − minSoc`). PRD §6.2 line 259 suggests 0.5 %.
  final double convergenceToleranceFraction;

  /// Upper bound on cyclic iterations. Convergence usually settles in
  /// 2–5 iterations; this is the safety stop for pathological configs.
  final int maxConvergenceIterations;

  final double? gridExportLimitKw;
  final double latitudeDeg;

  /// Longitude in degrees, positive east. Not used by the synthetic
  /// model but persisted so PVGIS fetchers / geocoders can address the
  /// site. JSON-loaded projects without this field default to 10° E
  /// (central Germany), matching the latitude default.
  final double longitudeDeg;

  /// Source for plane-of-array irradiance + ambient conditions per
  /// (array, time). `null` means the engine falls back to the
  /// [SyntheticIrradianceSource] demo model. Plug an
  /// [HourlyWeatherSeries] built from PVGIS data here to drive the
  /// simulation from real measurements.
  final IrradianceSource? weatherSource;

  /// Strategy that maps weather + module NOCT into cell temperature
  /// for the array-level temperature derating.
  final TemperatureModel temperatureModel;

  /// When `false`, [SimulationResult.steps] is empty and the simulator
  /// avoids retaining per-step records — only the [SimulationSummary]
  /// is built. Annual KPIs are unchanged in either mode. Use this to
  /// trim memory for batch comparisons or scenario sweeps where the
  /// per-step series isn't needed; CSV export and the time-series
  /// charts require `keepSteps: true`.
  final bool keepSteps;

  /// Number of consecutive 365-day years to simulate. `1` (default) is
  /// the legacy behaviour. For `simulationYears > 1` each year `y`
  /// (0-indexed) derates every array's `peakKw` by
  /// `(1 − degradationPctPerYear/100)^y`. SOC carries between years and
  /// `preRunMode == singleWarmUp` runs the warm-up once before year 0
  /// only. `cyclicConvergence` is incompatible with multi-year and
  /// rejected at `validate()`.
  ///
  /// When `keepSteps: true && simulationYears > 1`,
  /// [SimulationResult.steps] retains only the **final** year's per-step
  /// data — concatenating all years would break aggregators that key on
  /// `dayOfYear` (`SummaryAggregator.monthly`). Per-year scalar KPIs are
  /// always available via [SimulationSummary.perYearSummaries].
  final int simulationYears;

  /// Optional electricity tariff. When non-null the engine computes
  /// per-step import cost / export revenue and surfaces them as
  /// `SimulationSummary.importCostEur` / `exportRevenueEur` /
  /// `netCostEur`. When null no economics are computed and those
  /// summary fields remain null. UI-side Pro gating for time-of-use
  /// arrays lives outside the engine.
  final TariffConfig? tariff;

  IrradianceSource get effectiveWeatherSource => weatherSource ?? const SyntheticIrradianceSource();

  /// Topology used by the simulator: explicit if given, otherwise an
  /// auto-built one derived from the flat fields.
  TopologyGraph get effectiveTopology => topology ?? TopologyGraph.fromLegacy(
        arrayIds: arrays.map((a) => a.id),
        inverterIds: inverters.map((i) => i.id),
        batteryIds: batteries.map((b) => b.id),
        bankIds: microInverterBanks.map((b) => b.id),
        arrayToInverter: arrays.map((a) => MapEntry(a.id, a.inverterId)),
        inverterMaxAc: inverters.map((i) => MapEntry(i.id, i.effectiveMaxAcKw)),
        inverterMaxDcInput: inverters.map((i) => MapEntry(i.id, i.maxDcInputKw)),
        inverterEfficiency: inverters.map((i) => MapEntry(i.id, i.efficiency)),
        chargeControllers: chargeControllers.isEmpty ? null : chargeControllers,
      );

  /// Dispatch policy used by the simulator: explicit if given,
  /// otherwise [SelfConsumptionFirstPolicy].
  DispatchPolicy get effectiveDispatchPolicy =>
      dispatchPolicy ?? const SelfConsumptionFirstPolicy();

  void validate() {
    _require(arrays.isNotEmpty, 'At least one PV array is required.');
    _require(inverters.isNotEmpty, 'At least one inverter is required.');
    // Days/preRunDays are bounded to one year: the engine's _wrapDay folds
    // dayOfYear into [1, 365] regardless, and a 365-day run already produces
    // the full annual summary. Higher values waste CPU/memory with no extra
    // information and would be a DoS surface for malicious imports.
    _require(days >= 1 && days <= 365, 'days must be in [1, 365].');
    _require(preRunDays >= 0 && preRunDays <= 365, 'preRunDays must be in [0, 365].');
    _require(startDayOfYear >= 1 && startDayOfYear <= 365, 'startDayOfYear must be in [1, 365].');
    _require(
      convergenceToleranceFraction > 0 && convergenceToleranceFraction <= 1,
      'convergenceToleranceFraction must be in (0, 1].',
    );
    _require(
      maxConvergenceIterations >= 1,
      'maxConvergenceIterations must be >= 1.',
    );
    if (preRunMode == PreRunMode.cyclicConvergence) {
      // Cyclic convergence repeats the *full year*; partial-year runs or
      // an extra warm-up window would conflate two different settling
      // mechanisms and make the reported iteration count meaningless.
      _require(days == 365, 'cyclicConvergence requires days == 365.');
      _require(preRunDays == 0, 'cyclicConvergence cannot be combined with preRunDays > 0.');
    }
    _require(simulationYears >= 1 && simulationYears <= 30,
        'simulationYears must be in [1, 30].');
    tariff?.validate();
    if (simulationYears > 1) {
      // Multi-year is a full-year construct; partial years would corrupt
      // the per-year summary semantics. And combining with cyclic
      // settling is undefined — cyclic itself is a multi-iteration warm-
      // up that targets a different invariant.
      _require(days == 365, 'simulationYears > 1 requires days == 365.');
      _require(preRunMode != PreRunMode.cyclicConvergence,
          'simulationYears > 1 is incompatible with preRunMode.cyclicConvergence.');
    }
    _require(latitudeDeg >= -90 && latitudeDeg <= 90, 'latitudeDeg must be in [-90, 90].');
    _require(longitudeDeg >= -180 && longitudeDeg <= 180, 'longitudeDeg must be in [-180, 180].');
    _require(gridExportLimitKw == null || gridExportLimitKw! >= 0, 'gridExportLimitKw must not be negative.');
    final inverterIds = <String>{};
    for (final inverter in inverters) {
      inverter.validate();
      _require(inverterIds.add(inverter.id), 'Duplicate inverter id: ${inverter.id}.');
    }
    // Duplicate array ids would silently share PVGIS weather imports
    // (which are keyed by array id) and confuse per-array curtailment
    // reporting. Reject them at validation time.
    final arrayIds = <String>{};
    for (final array in arrays) {
      array.validate();
      _require(arrayIds.add(array.id), 'Duplicate PV array id: ${array.id}.');
      _require(inverterIds.contains(array.inverterId), 'PV array ${array.id} references missing inverter ${array.inverterId}.');
    }
    final batteryIds = <String>{};
    for (final battery in batteries) {
      battery.validate();
      _require(batteryIds.add(battery.id), 'Duplicate battery id: ${battery.id}.');
    }
    final bankIds = <String>{};
    for (final bank in microInverterBanks) {
      bank.validate();
      _require(bankIds.add(bank.id), 'Duplicate micro-inverter bank id: ${bank.id}.');
      _require(batteryIds.contains(bank.batteryId),
          'Micro-inverter bank ${bank.id} references missing battery ${bank.batteryId}.');
    }
    final explicitTopology = topology;
    if (explicitTopology != null && chargeControllers.isNotEmpty) {
      throw ArgumentError(
          'SimulationConfig.chargeControllers must be empty when topology is set explicitly '
          '(single source of truth — declare chargeControllers inside the topology instead).');
    }
    if (explicitTopology != null || chargeControllers.isNotEmpty) {
      effectiveTopology.validate(
        arrayIds: arrayIds,
        inverterIds: inverterIds,
        batteryIds: batteryIds,
        bankIds: bankIds,
      );
    }
    loadProfile.validate();
  }

  Map<String, dynamic> toJson() {
    // Bump to schema v2 only when one of the new Phase-4 fields is
    // actually set, v3 only when a Phase-5 field differs from its
    // default, v4 only when a Phase-10 multi-year/degradation knob is
    // non-default, v5 when a tariff is configured, and v6 when one of
    // the Phase-4b DC-coupling fields is non-default. Legacy projects
    // continue to round-trip as v1.
    final hasPhase4 = topology != null ||
        dispatchPolicy != null ||
        microInverterBanks.isNotEmpty;
    final hasPhase5 = preRunMode != PreRunMode.singleWarmUp ||
        convergenceToleranceFraction != 0.005 ||
        maxConvergenceIterations != 10;
    final hasPhase10 = simulationYears != 1 ||
        arrays.any((a) => a.degradationPctPerYear != 0.0);
    final hasTariff = tariff != null;
    // Trigger v6 only on the truly new fields. `BatteryCoupling.dc` was
    // representable inside `topology` since v2 — bumping legacy v2
    // projects with a DC coupling already in their topology JSON would
    // break their byte-stable round-trip.
    final hasDcCoupling = chargeControllers.isNotEmpty ||
        (topology?.chargeControllers.isNotEmpty ?? false) ||
        (topology?.dcBuses.any((b) => b.mode != BusMode.hybrid) ?? false);
    final version = hasDcCoupling
        ? 6
        : hasTariff
            ? 5
            : hasPhase10
                ? 4
                : hasPhase5
                    ? 3
                    : (hasPhase4 ? 2 : 1);
    final json = <String, dynamic>{
      'schemaVersion': version,
      'arrays': arrays.map((a) => a.toJson()).toList(),
      'inverters': inverters.map((i) => i.toJson()).toList(),
      'batteries': batteries.map((b) => b.toJson()).toList(),
      'loadProfile': loadProfile.toJson(),
      'startDayOfYear': startDayOfYear,
      'days': days,
      'timeStep': timeStep.name,
      'preRunDays': preRunDays,
      'gridExportLimitKw': gridExportLimitKw,
      'latitudeDeg': latitudeDeg,
      'longitudeDeg': longitudeDeg,
      // Only emit `keepSteps` when it deviates from the default so v1/v2
      // round-trips stay byte-identical for hashing and tests.
      if (!keepSteps) 'keepSteps': false,
    };
    if (hasPhase4 || hasPhase5) {
      if (microInverterBanks.isNotEmpty) {
        json['microInverterBanks'] = microInverterBanks.map((b) => b.toJson()).toList();
      }
      if (topology != null) {
        json['topology'] = topology!.toJson();
      }
      if (dispatchPolicy != null) {
        json['dispatchPolicy'] = dispatchPolicy!.toJson();
      }
    }
    if (hasPhase5) {
      json['preRunMode'] = preRunMode.name;
      json['convergenceToleranceFraction'] = convergenceToleranceFraction;
      json['maxConvergenceIterations'] = maxConvergenceIterations;
    }
    if (hasPhase10) {
      json['simulationYears'] = simulationYears;
    }
    if (hasTariff) {
      json['tariff'] = tariff!.toJson();
    }
    if (chargeControllers.isNotEmpty) {
      json['chargeControllers'] =
          chargeControllers.map((c) => c.toJson()).toList();
    }
    return json;
  }

  static SimulationConfig fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as int? ?? 1;
    if (version < 1 || version > 6) {
      throw ArgumentError('Unknown SimulationConfig schemaVersion: $version');
    }
    final batteries = <BatteryConfig>[];
    final rawBatteries = json['batteries'];
    if (rawBatteries is List) {
      for (var i = 0; i < rawBatteries.length; i++) {
        batteries.add(BatteryConfig.fromJson(
          (rawBatteries[i] as Map).cast<String, dynamic>(),
          fallbackId: 'battery-${i + 1}',
        ));
      }
    } else if (json['battery'] is Map) {
      // Legacy single-battery shape.
      batteries.add(BatteryConfig.fromJson(
        (json['battery'] as Map).cast<String, dynamic>(),
        fallbackId: 'battery-1',
      ));
    }

    final banks = <MicroInverterBank>[];
    final rawBanks = json['microInverterBanks'];
    if (rawBanks is List) {
      for (final e in rawBanks) {
        banks.add(MicroInverterBank.fromJson((e as Map).cast<String, dynamic>()));
      }
    }

    TopologyGraph? topo;
    final rawTopo = json['topology'];
    if (rawTopo is Map) {
      topo = TopologyGraph.fromJson(rawTopo.cast<String, dynamic>());
    }

    DispatchPolicy? policy;
    final rawPolicy = json['dispatchPolicy'];
    if (rawPolicy is Map) {
      policy = dispatchPolicyFromJson(rawPolicy.cast<String, dynamic>());
    }

    return SimulationConfig(
      arrays: (json['arrays'] as List)
          .map((e) => PvArray.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
      inverters: (json['inverters'] as List)
          .map((e) => Inverter.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
      batteries: batteries,
      microInverterBanks: banks,
      topology: topo,
      dispatchPolicy: policy,
      loadProfile: LoadProfile.fromJson((json['loadProfile'] as Map).cast<String, dynamic>()),
      startDayOfYear: (json['startDayOfYear'] as num?)?.toInt() ?? 1,
      days: (json['days'] as num?)?.toInt() ?? 365,
      timeStep: _timeStepFromName(json['timeStep'] as String? ?? 'hourly'),
      preRunDays: (json['preRunDays'] as num?)?.toInt() ?? 0,
      preRunMode: _preRunModeFromName(json['preRunMode'] as String?),
      convergenceToleranceFraction:
          _toDouble(json['convergenceToleranceFraction'] ?? 0.005),
      maxConvergenceIterations:
          (json['maxConvergenceIterations'] as num?)?.toInt() ?? 10,
      gridExportLimitKw: json['gridExportLimitKw'] == null ? null : _toDouble(json['gridExportLimitKw']),
      latitudeDeg: _toDouble(json['latitudeDeg'] ?? 50.0),
      longitudeDeg: _toDouble(json['longitudeDeg'] ?? 10.0),
      keepSteps: (json['keepSteps'] as bool?) ?? true,
      simulationYears: (json['simulationYears'] as num?)?.toInt() ?? 1,
      tariff: json['tariff'] is Map
          ? TariffConfig.fromJson((json['tariff'] as Map).cast<String, dynamic>())
          : null,
      chargeControllers: () {
        final raw = json['chargeControllers'];
        if (raw is! List) return const <ChargeController>[];
        return raw
            .map((e) => ChargeController.fromJson((e as Map).cast<String, dynamic>()))
            .toList(growable: false);
      }(),
    );
  }
}

PreRunMode _preRunModeFromName(String? name) {
  // Legacy projects (v1/v2) have no `preRunMode` field; default to
  // singleWarmUp so their existing `preRunDays` semantics are preserved.
  if (name == null) return PreRunMode.singleWarmUp;
  for (final mode in PreRunMode.values) {
    if (mode.name == name) return mode;
  }
  throw ArgumentError('Unknown PreRunMode: $name');
}

class SimulationStep {
  const SimulationStep({
    required this.dayIndex,
    required this.dayOfYear,
    required this.stepOfDay,
    required this.hourOfDay,
    required this.pvDcKwh,
    required this.pvAcKwh,
    required this.loadKwh,
    required this.selfConsumptionKwh,
    required this.batteryChargeKwh,
    required this.batteryDischargeKwh,
    required this.batterySocKwh,
    required this.batteryChargesKwh,
    required this.batteryDischargesKwh,
    required this.batterySocsKwh,
    required this.gridImportKwh,
    required this.gridExportKwh,
    required this.curtailedDcKwh,
    required this.curtailedAcKwh,
    required this.curtailedExportKwh,
    this.microInverterDeliveredKwh = 0.0,
    this.microInverterShortfallKwh = 0.0,
    this.microInverterDeliveriesKwh = const [],
    this.microInverterShortfallsKwh = const [],
    this.unservedLoadKwh = 0.0,
    this.dcKwhByArray = const [],
    this.acKwhByArray = const [],
    this.importCostEur = 0.0,
    this.exportRevenueEur = 0.0,
    this.dcDirectChargeKwh = 0.0,
    this.dcCurtailedKwh = 0.0,
  });

  final int dayIndex;
  final int dayOfYear;
  final int stepOfDay;
  final double hourOfDay;
  final double pvDcKwh;
  final double pvAcKwh;
  final double loadKwh;
  final double selfConsumptionKwh;
  final double batteryChargeKwh;
  final double batteryDischargeKwh;
  final double batterySocKwh;
  final List<double> batteryChargesKwh;
  final List<double> batteryDischargesKwh;
  final List<double> batterySocsKwh;
  final double gridImportKwh;
  final double gridExportKwh;

  /// DC-side energy lost at the inverter's MPPT/DC input cap, in
  /// **DC kWh**. Modules generated this energy but the inverter could
  /// not ingest it.
  final double curtailedDcKwh;

  /// AC-side energy lost at the inverter's AC output cap, in
  /// **AC kWh**. The inverter could have produced this but the AC
  /// rating (or 800 W micro-inverter cap) refused it.
  final double curtailedAcKwh;

  /// AC-side energy refused by the configured grid export limit, in
  /// **AC kWh**. Energy was successfully converted to AC but exceeded
  /// the export ceiling.
  final double curtailedExportKwh;

  /// AC energy delivered by all micro-inverter banks combined, in
  /// **AC kWh**. Already included in [selfConsumptionKwh] (when it
  /// covers load) and [gridExportKwh] (when it spills).
  final double microInverterDeliveredKwh;

  /// AC energy the banks tried but failed to deliver this step (SOC
  /// shutdown, rate cap, empty battery), in **AC kWh**.
  final double microInverterShortfallKwh;

  /// Per-bank breakdown of [microInverterDeliveredKwh]. Same order as
  /// `SimulationConfig.microInverterBanks`. Empty when no banks are
  /// configured.
  final List<double> microInverterDeliveriesKwh;

  /// Per-bank breakdown of [microInverterShortfallKwh].
  final List<double> microInverterShortfallsKwh;

  /// Load that remained uncovered after PV, batteries and banks when
  /// the dispatch policy disabled grid import (e.g. islanded
  /// [GridAssistPolicy] with `allowGridImport: false`). `0` for grid-
  /// connected scenarios.
  final double unservedLoadKwh;

  /// Per-array breakdown of [pvDcKwh] before inverter losses, ordered
  /// the same as `SimulationConfig.arrays`. Sums to [pvDcKwh] within
  /// floating-point tolerance. Empty when the engine was instantiated
  /// outside the simulator (e.g. test fixtures).
  final List<double> dcKwhByArray;

  /// Per-array breakdown of [pvAcKwh] *after* inverter efficiency and
  /// AC clipping. Each array's AC share is its DC share weighted by
  /// the inverter-level (rawAc → limitedAc) outcome, so the sum equals
  /// [pvAcKwh] within floating-point tolerance.
  final List<double> acKwhByArray;

  /// Grid-import cost for this step in €. `0.0` whenever
  /// `SimulationConfig.tariff` is null; consumers should consult
  /// `SimulationSummary.importCostEur` (nullable) for the
  /// is-a-tariff-configured signal.
  final double importCostEur;

  /// Grid-export revenue for this step in €. Same zero-when-no-tariff
  /// convention as [importCostEur].
  final double exportRevenueEur;

  /// Energy delivered directly from PV to a DC-coupled battery via a
  /// charge controller (Laderegler), in **DC kWh** measured on the DC
  /// bus side. Already counted inside [batteryChargeKwh] / per-battery
  /// `batteryChargesKwh`; surfaced separately so reports can split the
  /// DC-side path from the AC-side path. `0.0` for AC-coupled
  /// topologies.
  final double dcDirectChargeKwh;

  /// PV energy that arrived on a DC bus in `batteryFed` mode but could
  /// not be absorbed by its battery (battery full or rate-limited), in
  /// **DC kWh**. Has no AC bypass path so it is lost. `0.0` for hybrid
  /// or AC-coupled topologies (where excess PV-DC reaches AC via the
  /// inverter and falls under [curtailedAcKwh] / [curtailedExportKwh]
  /// instead).
  final double dcCurtailedKwh;
}

class SimulationSummary {
  const SimulationSummary({
    required this.pvDcKwh,
    required this.pvAcKwh,
    required this.loadKwh,
    required this.selfConsumptionKwh,
    required this.batteryChargeKwh,
    required this.batteryDischargeKwh,
    required this.gridImportKwh,
    required this.gridExportKwh,
    required this.curtailedDcKwh,
    required this.curtailedAcKwh,
    required this.curtailedExportKwh,
    required this.finalBatterySocKwh,
    required this.finalBatterySocsKwh,
    this.microInverterDeliveredKwh = 0.0,
    this.microInverterShortfallKwh = 0.0,
    this.unservedLoadKwh = 0.0,
    this.preRunMode = PreRunMode.singleWarmUp,
    this.preRunActive = false,
    this.startSocsUsedKwh = const [],
    this.convergenceIterations = 0,
    this.converged = true,
    this.perYearSummaries = const [],
    this.importCostEur,
    this.exportRevenueEur,
    this.netCostEur,
    this.dcDirectChargeKwh = 0.0,
    this.dcCurtailedKwh = 0.0,
  });

  final double pvDcKwh;
  final double pvAcKwh;
  final double loadKwh;
  final double selfConsumptionKwh;
  final double batteryChargeKwh;
  final double batteryDischargeKwh;
  final double gridImportKwh;
  final double gridExportKwh;

  /// Aggregate energy delivered to DC-coupled batteries via charge
  /// controllers over the reporting horizon, in **DC kWh**. Already
  /// included in [batteryChargeKwh]. `0.0` for AC-coupled-only
  /// scenarios.
  final double dcDirectChargeKwh;

  /// PV energy that could not be absorbed on a `batteryFed` DC bus
  /// (battery full / rate-limited and no AC bypass path), in **DC
  /// kWh**. `0.0` for hybrid or AC-coupled scenarios.
  final double dcCurtailedKwh;

  /// DC-side curtailment from MPPT clipping, in **DC kWh**.
  final double curtailedDcKwh;

  /// AC-side curtailment from the inverter AC cap, in **AC kWh**.
  final double curtailedAcKwh;

  /// AC-side curtailment from the grid export limit, in **AC kWh**.
  final double curtailedExportKwh;

  final double finalBatterySocKwh;
  final List<double> finalBatterySocsKwh;

  /// Sum of AC energy delivered by all micro-inverter banks over the
  /// reporting horizon.
  final double microInverterDeliveredKwh;

  /// Sum of AC energy the banks could not deliver.
  final double microInverterShortfallKwh;

  /// Load left uncovered when grid import was disabled by the policy.
  final double unservedLoadKwh;

  /// Pre-run strategy actually used by the simulator. Echoed from the
  /// config for traceability — see PRD §6.2 line 260.
  final PreRunMode preRunMode;

  /// `true` when a SOC-settling run was actually executed — i.e. at
  /// least one battery was configured **and** the chosen mode performed
  /// pre-run work (`singleWarmUp` with `preRunDays > 0`, or any cyclic
  /// iteration). `false` for manual mode, for `singleWarmUp` with
  /// `preRunDays == 0`, and whenever `batteries` is empty (no SOC to
  /// settle, so no pre-run is meaningful regardless of mode).
  final bool preRunActive;

  /// Per-battery SOC at the first reported step (i.e. after the pre-run
  /// has settled). Same ordering as `SimulationConfig.batteries`. Empty
  /// when no batteries are configured.
  final List<double> startSocsUsedKwh;

  /// Number of pre-run iterations executed. `0` for manual mode and for
  /// `singleWarmUp` without an effective warm-up (`preRunDays == 0` or
  /// no batteries). `1` for `singleWarmUp` with `preRunDays > 0` and at
  /// least one battery. `N ∈ [1, maxConvergenceIterations]` for cyclic
  /// mode — always ≥ 1 because the convergence check sits at the end of
  /// the loop body (with no batteries the empty check is trivially
  /// satisfied after one cycle). The always-executed reported year is
  /// **not** counted here.
  final int convergenceIterations;

  /// `true` unless cyclic convergence hit `maxConvergenceIterations`
  /// without satisfying the per-battery tolerance. Always `true` for
  /// the non-cyclic modes.
  final bool converged;

  /// Per-year scalar summaries for multi-year runs
  /// (`SimulationConfig.simulationYears > 1`). Each entry is the full
  /// summary of one 365-day year with the array `peakKw` derated for
  /// that year. Empty for single-year runs — the top-level summary IS
  /// the year's summary. Per-year summaries themselves carry
  /// `perYearSummaries = const []` (no nesting).
  final List<SimulationSummary> perYearSummaries;

  /// Total cost paid for grid imports over the reporting horizon, in
  /// €. `null` when `SimulationConfig.tariff` is null (no economics
  /// computed). Sign-positive (always a cost).
  final double? importCostEur;

  /// Total revenue earned from grid exports over the reporting
  /// horizon, in €. `null` when no tariff is configured.
  /// Sign-positive (always a credit).
  final double? exportRevenueEur;

  /// Net electricity cost = [importCostEur] − [exportRevenueEur]. A
  /// negative value means the export revenue exceeds import cost. `null`
  /// when no tariff is configured.
  final double? netCostEur;

  double get selfConsumptionRate => pvAcKwh <= 0 ? 0 : selfConsumptionKwh / pvAcKwh;
  double get autarkyRate => loadKwh <= 0 ? 0 : selfConsumptionKwh / loadKwh;

  /// Canonical JSON encoding. Persisted by the Flutter app's
  /// `simulation_runs.summary_json` and round-trips through
  /// [SimulationSummary.fromJson]. All scalar / list fields are always
  /// emitted so a downstream reader can rely on key presence without
  /// guessing defaults; only the genuinely-optional fields
  /// ([perYearSummaries] for single-year runs and the three tariff
  /// cost fields when no tariff was configured) are dropped.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'pvDcKwh': pvDcKwh,
      'pvAcKwh': pvAcKwh,
      'loadKwh': loadKwh,
      'selfConsumptionKwh': selfConsumptionKwh,
      'batteryChargeKwh': batteryChargeKwh,
      'batteryDischargeKwh': batteryDischargeKwh,
      'gridImportKwh': gridImportKwh,
      'gridExportKwh': gridExportKwh,
      'curtailedDcKwh': curtailedDcKwh,
      'curtailedAcKwh': curtailedAcKwh,
      'curtailedExportKwh': curtailedExportKwh,
      'finalBatterySocKwh': finalBatterySocKwh,
      'finalBatterySocsKwh': finalBatterySocsKwh,
      'microInverterDeliveredKwh': microInverterDeliveredKwh,
      'microInverterShortfallKwh': microInverterShortfallKwh,
      'unservedLoadKwh': unservedLoadKwh,
      'preRunMode': preRunMode.name,
      'preRunActive': preRunActive,
      'startSocsUsedKwh': startSocsUsedKwh,
      'convergenceIterations': convergenceIterations,
      'converged': converged,
    };
    if (perYearSummaries.length >= 2) {
      json['perYearSummaries'] =
          perYearSummaries.map((s) => s.toJson()).toList(growable: false);
    }
    if (importCostEur != null) json['importCostEur'] = importCostEur;
    if (exportRevenueEur != null) json['exportRevenueEur'] = exportRevenueEur;
    if (netCostEur != null) json['netCostEur'] = netCostEur;
    // Emit the DC-coupling fields only when non-default so summaries
    // from AC-only runs round-trip byte-identically to pre-Phase-4b.
    if (dcDirectChargeKwh != 0.0) json['dcDirectChargeKwh'] = dcDirectChargeKwh;
    if (dcCurtailedKwh != 0.0) json['dcCurtailedKwh'] = dcCurtailedKwh;
    return json;
  }

  static SimulationSummary fromJson(Map<String, dynamic> json) {
    final rawPerYear = json['perYearSummaries'];
    final perYear = rawPerYear is List
        ? rawPerYear
            .map((e) => SimulationSummary.fromJson((e as Map).cast<String, dynamic>()))
            .toList(growable: false)
        : const <SimulationSummary>[];
    return SimulationSummary(
      pvDcKwh: _toDouble(json['pvDcKwh']),
      pvAcKwh: _toDouble(json['pvAcKwh']),
      loadKwh: _toDouble(json['loadKwh']),
      selfConsumptionKwh: _toDouble(json['selfConsumptionKwh']),
      batteryChargeKwh: _toDouble(json['batteryChargeKwh']),
      batteryDischargeKwh: _toDouble(json['batteryDischargeKwh']),
      gridImportKwh: _toDouble(json['gridImportKwh']),
      gridExportKwh: _toDouble(json['gridExportKwh']),
      curtailedDcKwh: _toDouble(json['curtailedDcKwh']),
      curtailedAcKwh: _toDouble(json['curtailedAcKwh']),
      curtailedExportKwh: _toDouble(json['curtailedExportKwh']),
      finalBatterySocKwh: _toDouble(json['finalBatterySocKwh']),
      finalBatterySocsKwh: (json['finalBatterySocsKwh'] as List?)
              ?.map((e) => _toDouble(e))
              .toList(growable: false) ??
          const <double>[],
      microInverterDeliveredKwh: _toDouble(json['microInverterDeliveredKwh'] ?? 0.0),
      microInverterShortfallKwh: _toDouble(json['microInverterShortfallKwh'] ?? 0.0),
      unservedLoadKwh: _toDouble(json['unservedLoadKwh'] ?? 0.0),
      preRunMode: _preRunModeFromName(json['preRunMode'] as String?),
      preRunActive: (json['preRunActive'] as bool?) ?? false,
      startSocsUsedKwh: (json['startSocsUsedKwh'] as List?)
              ?.map((e) => _toDouble(e))
              .toList(growable: false) ??
          const <double>[],
      convergenceIterations: (json['convergenceIterations'] as num?)?.toInt() ?? 0,
      converged: (json['converged'] as bool?) ?? true,
      perYearSummaries: perYear,
      importCostEur: json['importCostEur'] == null
          ? null
          : _toDouble(json['importCostEur']),
      exportRevenueEur: json['exportRevenueEur'] == null
          ? null
          : _toDouble(json['exportRevenueEur']),
      netCostEur: json['netCostEur'] == null
          ? null
          : _toDouble(json['netCostEur']),
      dcDirectChargeKwh: _toDouble(json['dcDirectChargeKwh'] ?? 0.0),
      dcCurtailedKwh: _toDouble(json['dcCurtailedKwh'] ?? 0.0),
    );
  }
}

class SimulationResult {
  const SimulationResult({required this.steps, required this.summary});
  final List<SimulationStep> steps;
  final SimulationSummary summary;
}

/// Progress event emitted by [PvSimulator.run] when an `onProgress`
/// callback is supplied. Pure data — no `dart:async`, no Flutter.
class SimulationProgress {
  const SimulationProgress({
    required this.phase,
    required this.completedDays,
    required this.totalDays,
    this.iteration = 1,
    this.year = 1,
    this.totalYears = 1,
  });

  final SimulationPhase phase;

  /// Days completed in the current phase (1-based at the end of a day).
  final int completedDays;

  /// Total days the current phase will iterate over.
  final int totalDays;

  /// For [PreRunMode.cyclicConvergence] this is the 1-based iteration
  /// index; `1` for every other mode. Multi-year runs use [year] /
  /// [totalYears] instead — `iteration` stays at `1` so consumers can
  /// distinguish cyclic settling from multi-year stepping.
  final int iteration;

  /// 1-based index of the currently-reporting year for multi-year
  /// runs (`SimulationConfig.simulationYears > 1`). `1` for single-
  /// year runs.
  final int year;

  /// Total number of years the multi-year driver will iterate over.
  /// `1` for single-year runs.
  final int totalYears;

  double get fraction => totalDays == 0 ? 1.0 : completedDays / totalDays;
}

enum SimulationPhase { preRun, reporting }

typedef ProgressCallback = void Function(SimulationProgress);

/// Running totals threaded through the per-step loop so the summary
/// builds in O(stepsPerYear) without re-iterating a kept-steps list.
/// Private — the engine's only consumer is [_summarize].
class _StepAccumulator {
  double pvDcKwh = 0;
  double pvAcKwh = 0;
  double loadKwh = 0;
  double selfConsumptionKwh = 0;
  double batteryChargeKwh = 0;
  double batteryDischargeKwh = 0;
  double gridImportKwh = 0;
  double gridExportKwh = 0;
  double curtailedDcKwh = 0;
  double curtailedAcKwh = 0;
  double curtailedExportKwh = 0;
  double microInverterDeliveredKwh = 0;
  double microInverterShortfallKwh = 0;
  double unservedLoadKwh = 0;
  double importCostEur = 0;
  double exportRevenueEur = 0;
  double dcDirectChargeKwh = 0;
  double dcCurtailedKwh = 0;

  /// Reads scalar columns of `buf` at index `idx` and accumulates.
  /// This is the hot-path entry: avoids materialising a `SimulationStep`
  /// view just to feed the summary.
  void addFromBuffer(_StepBuffer buf, int idx) {
    pvDcKwh += buf.pvDcKwh[idx];
    pvAcKwh += buf.pvAcKwh[idx];
    loadKwh += buf.loadKwh[idx];
    selfConsumptionKwh += buf.selfConsumptionKwh[idx];
    batteryChargeKwh += buf.batteryChargeKwh[idx];
    batteryDischargeKwh += buf.batteryDischargeKwh[idx];
    gridImportKwh += buf.gridImportKwh[idx];
    gridExportKwh += buf.gridExportKwh[idx];
    curtailedDcKwh += buf.curtailedDcKwh[idx];
    curtailedAcKwh += buf.curtailedAcKwh[idx];
    curtailedExportKwh += buf.curtailedExportKwh[idx];
    microInverterDeliveredKwh += buf.microInverterDeliveredKwh[idx];
    microInverterShortfallKwh += buf.microInverterShortfallKwh[idx];
    unservedLoadKwh += buf.unservedLoadKwh[idx];
    // Tariff columns are zero-initialised when no tariff is configured,
    // so unconditional accumulation is safe and the no-tariff hot loop
    // pays one extra add of 0.0 per step — negligible vs. dispatch.
    importCostEur += buf.importCostEur[idx];
    exportRevenueEur += buf.exportRevenueEur[idx];
    // DC-coupling columns are zero-filled when no DC topology is
    // configured; same negligible-overhead rationale as tariff.
    dcDirectChargeKwh += buf.dcDirectChargeKwh[idx];
    dcCurtailedKwh += buf.dcCurtailedKwh[idx];
  }
}

/// Columnar storage for one simulation's reported steps. Scalars live in
/// parallel `Float64List`s / `Int32List`s; per-battery, per-bank and
/// per-array breakdowns live in row-major 2D `Float64List`s (one strip
/// per step). The simulator writes here directly — `SimulationStep`
/// instances are only materialised lazily when callers iterate
/// `SimulationResult.steps`.
///
/// Sizing: `capacity = days × stepsPerDay`. For a 365-day quarter-hourly
/// year with 2 batteries / 1 bank / 3 arrays this is roughly:
///   18 × 35 040 doubles (scalars)          ≈ 5 MiB
///   3 × 35 040 × 2 doubles (battery 2D)    ≈ 1.7 MiB
///   2 × 35 040 × 1 doubles (bank 2D)       ≈ 0.6 MiB
///   2 × 35 040 × 3 doubles (array 2D)      ≈ 1.7 MiB
/// Total ≈ 9 MiB, allocated once. Pre-Phase-9 this was 35 040
/// `SimulationStep` objects + 35 040 × 7 unmodifiable `List` wrappers —
/// many small allocations and the GC pressure that goes with them.
class _StepBuffer {
  _StepBuffer({
    required this.batteryCount,
    required this.bankCount,
    required this.arrayCount,
    required int capacity,
  })  : dayIndex = Int32List(capacity),
        dayOfYear = Int32List(capacity),
        stepOfDay = Int32List(capacity),
        hourOfDay = Float64List(capacity),
        pvDcKwh = Float64List(capacity),
        pvAcKwh = Float64List(capacity),
        loadKwh = Float64List(capacity),
        selfConsumptionKwh = Float64List(capacity),
        batteryChargeKwh = Float64List(capacity),
        batteryDischargeKwh = Float64List(capacity),
        batterySocKwh = Float64List(capacity),
        gridImportKwh = Float64List(capacity),
        gridExportKwh = Float64List(capacity),
        curtailedDcKwh = Float64List(capacity),
        curtailedAcKwh = Float64List(capacity),
        curtailedExportKwh = Float64List(capacity),
        microInverterDeliveredKwh = Float64List(capacity),
        microInverterShortfallKwh = Float64List(capacity),
        unservedLoadKwh = Float64List(capacity),
        importCostEur = Float64List(capacity),
        exportRevenueEur = Float64List(capacity),
        dcDirectChargeKwh = Float64List(capacity),
        dcCurtailedKwh = Float64List(capacity),
        batteryCharges = Float64List(capacity * batteryCount),
        batteryDischarges = Float64List(capacity * batteryCount),
        batterySocs = Float64List(capacity * batteryCount),
        bankDeliveries = Float64List(capacity * bankCount),
        bankShortfalls = Float64List(capacity * bankCount),
        arrayDc = Float64List(capacity * arrayCount),
        arrayAc = Float64List(capacity * arrayCount);

  final int batteryCount;
  final int bankCount;
  final int arrayCount;

  /// Number of steps written so far (`<= capacity` of the columns). The `_runLinear`
  /// loop appends; `_runCyclic` resets this to 0 at the start of each
  /// iteration so only the last cycle's data is observable.
  int length = 0;

  final Int32List dayIndex;
  final Int32List dayOfYear;
  final Int32List stepOfDay;
  final Float64List hourOfDay;
  final Float64List pvDcKwh;
  final Float64List pvAcKwh;
  final Float64List loadKwh;
  final Float64List selfConsumptionKwh;
  final Float64List batteryChargeKwh;
  final Float64List batteryDischargeKwh;
  final Float64List batterySocKwh;
  final Float64List gridImportKwh;
  final Float64List gridExportKwh;
  final Float64List curtailedDcKwh;
  final Float64List curtailedAcKwh;
  final Float64List curtailedExportKwh;
  final Float64List microInverterDeliveredKwh;
  final Float64List microInverterShortfallKwh;
  final Float64List unservedLoadKwh;

  /// Per-step grid-import cost in €. Zero-filled when
  /// `SimulationConfig.tariff` is null — the engine doesn't pay the
  /// branching cost in the hot loop, summary stays null instead.
  final Float64List importCostEur;

  /// Per-step grid-export revenue in €. Same zero-filling convention.
  final Float64List exportRevenueEur;

  /// Per-step DC-side charging energy delivered to DC-coupled batteries
  /// via charge controllers, summed across batteries on all DC buses.
  /// In **DC kWh**. Zero-filled when no DC coupling is configured.
  final Float64List dcDirectChargeKwh;

  /// Per-step PV energy curtailed on `batteryFed` DC buses because the
  /// battery could not absorb it and no AC bypass path exists. In **DC
  /// kWh**. Zero-filled when no `batteryFed` bus is configured.
  final Float64List dcCurtailedKwh;

  // Row-major 2D: index = `step * dim + slot`.
  final Float64List batteryCharges;
  final Float64List batteryDischarges;
  final Float64List batterySocs;
  final Float64List bankDeliveries;
  final Float64List bankShortfalls;
  final Float64List arrayDc;
  final Float64List arrayAc;

  /// Returns a non-copying, **immutable** view of one row of a 2D
  /// column. The underlying `Float64List.sublistView` shares the
  /// buffer's `ByteBuffer` (so iteration stays cheap), but the
  /// `UnmodifiableListView` wrapper forbids writes — preserving the
  /// pre-Phase-9 contract that `SimulationStep`'s list fields are
  /// immutable. Pre-Phase-9 this was `List<double>.unmodifiable(...)`,
  /// which copied; the wrapper here is non-copying.
  List<double> _row(Float64List col, int idx, int dim) {
    if (dim == 0) return const <double>[];
    final start = idx * dim;
    return UnmodifiableListView<double>(
      Float64List.sublistView(col, start, start + dim),
    );
  }

  /// Materialises a `SimulationStep` view backed by this buffer at the
  /// given index. Scalar getters return the column slot; list getters
  /// return non-copying `Float64List` views. Called only when a caller
  /// indexes `SimulationResult.steps[i]`.
  SimulationStep stepAt(int idx) => SimulationStep(
        dayIndex: dayIndex[idx],
        dayOfYear: dayOfYear[idx],
        stepOfDay: stepOfDay[idx],
        hourOfDay: hourOfDay[idx],
        pvDcKwh: pvDcKwh[idx],
        pvAcKwh: pvAcKwh[idx],
        loadKwh: loadKwh[idx],
        selfConsumptionKwh: selfConsumptionKwh[idx],
        batteryChargeKwh: batteryChargeKwh[idx],
        batteryDischargeKwh: batteryDischargeKwh[idx],
        batterySocKwh: batterySocKwh[idx],
        batteryChargesKwh: _row(batteryCharges, idx, batteryCount),
        batteryDischargesKwh: _row(batteryDischarges, idx, batteryCount),
        batterySocsKwh: _row(batterySocs, idx, batteryCount),
        gridImportKwh: gridImportKwh[idx],
        gridExportKwh: gridExportKwh[idx],
        curtailedDcKwh: curtailedDcKwh[idx],
        curtailedAcKwh: curtailedAcKwh[idx],
        curtailedExportKwh: curtailedExportKwh[idx],
        microInverterDeliveredKwh: microInverterDeliveredKwh[idx],
        microInverterShortfallKwh: microInverterShortfallKwh[idx],
        microInverterDeliveriesKwh: _row(bankDeliveries, idx, bankCount),
        microInverterShortfallsKwh: _row(bankShortfalls, idx, bankCount),
        unservedLoadKwh: unservedLoadKwh[idx],
        dcKwhByArray: _row(arrayDc, idx, arrayCount),
        acKwhByArray: _row(arrayAc, idx, arrayCount),
        importCostEur: importCostEur[idx],
        exportRevenueEur: exportRevenueEur[idx],
        dcDirectChargeKwh: dcDirectChargeKwh[idx],
        dcCurtailedKwh: dcCurtailedKwh[idx],
      );
}

/// Lazy list view over `_StepBuffer`. Implements the public
/// `List<SimulationStep>` API expected by `SimulationResult.steps` —
/// CSV export, the monthly aggregator and any external consumer can
/// iterate it normally. Each `[i]` materialises a fresh `SimulationStep`
/// (with non-copying sub-list views over the buffer's 2D columns), so
/// allocation only happens when callers actually read.
class _StepListView extends ListBase<SimulationStep> {
  _StepListView(this._buffer);

  final _StepBuffer _buffer;

  @override
  int get length => _buffer.length;

  @override
  set length(int newLength) =>
      throw UnsupportedError('SimulationResult.steps is immutable.');

  @override
  SimulationStep operator [](int index) {
    if (index < 0 || index >= _buffer.length) {
      throw RangeError.index(index, this, 'index', null, _buffer.length);
    }
    return _buffer.stepAt(index);
  }

  @override
  void operator []=(int index, SimulationStep value) =>
      throw UnsupportedError('SimulationResult.steps is immutable.');
}

class PvSimulator {
  const PvSimulator();

  /// Runs the simulation. When [onProgress] is supplied, the callback
  /// fires once at the end of every simulated day (pre-run days included)
  /// with a [SimulationProgress] describing the current phase. The engine
  /// itself imposes no throttling — callers running across an isolate
  /// boundary should batch or drop intermediate events.
  SimulationResult run(SimulationConfig config, {ProgressCallback? onProgress}) {
    config.validate();
    // Pre-flight the weather source against the array roster so a
    // typo in an array id surfaces immediately instead of producing
    // a quiet zero-yield column in the summary.
    config.effectiveWeatherSource
        .validateForArrays(config.arrays.map((a) => a.id));
    if (config.simulationYears > 1) {
      return _runMultiYear(config, onProgress: onProgress);
    }
    switch (config.preRunMode) {
      case PreRunMode.manual:
        return _runLinear(config, preRunDays: 0, onProgress: onProgress);
      case PreRunMode.singleWarmUp:
        return _runLinear(config, preRunDays: config.preRunDays, onProgress: onProgress);
      case PreRunMode.cyclicConvergence:
        return _runCyclic(config, onProgress: onProgress);
    }
  }

  /// Multi-year driver: runs the existing per-year path
  /// (`_runLinear`) once per year with arrays derated for that year and
  /// the SOC ledger carried across. Pre-run executes ONCE in year 0 only
  /// (subsequent years start from the prior year's end SOC, which is
  /// already physically warm). The reported [SimulationResult.steps]
  /// holds only the **final** year's per-step data, when retained at
  /// all; per-year scalar KPIs are returned via
  /// [SimulationSummary.perYearSummaries]. The top-level summary is the
  /// aggregate across all years.
  SimulationResult _runMultiYear(SimulationConfig config,
      {ProgressCallback? onProgress}) {
    final years = config.simulationYears;
    final perYear = <SimulationSummary>[];
    SimulationResult? last;
    // SOC ledger carried between years. Initialise from the configured
    // initial SOC of every battery; subsequent years overwrite this
    // from the prior year's final SOC.
    var carriedSocs = <double>[
      for (final b in config.batteries) b.effectiveInitialSocKwh,
    ];
    for (var y = 0; y < years; y++) {
      final deratedArrays = [
        for (final a in config.arrays) a.deratedForYear(y),
      ];
      final yearBatteries = [
        for (var i = 0; i < config.batteries.length; i++)
          BatteryConfig(
            id: config.batteries[i].id,
            label: config.batteries[i].label,
            capacityKwh: config.batteries[i].capacityKwh,
            maxChargeKw: config.batteries[i].maxChargeKw,
            maxDischargeKw: config.batteries[i].maxDischargeKw,
            roundTripEfficiency: config.batteries[i].roundTripEfficiency,
            minSocKwh: config.batteries[i].minSocKwh,
            initialSocKwh: carriedSocs[i],
          ),
      ];
      // Only year 0 honours the configured pre-run; later years start
      // from the warm carry-over SOC and do their own 365-day cycle.
      final yearPreRunDays = y == 0 ? config.preRunDays : 0;
      final yearPreRunMode =
          y == 0 ? config.preRunMode : PreRunMode.manual;
      final yearConfig = SimulationConfig(
        arrays: deratedArrays,
        inverters: config.inverters,
        batteries: yearBatteries,
        microInverterBanks: config.microInverterBanks,
        topology: config.topology,
        dispatchPolicy: config.dispatchPolicy,
        loadProfile: config.loadProfile,
        startDayOfYear: config.startDayOfYear,
        days: config.days,
        timeStep: config.timeStep,
        preRunDays: yearPreRunDays,
        preRunMode: yearPreRunMode,
        convergenceToleranceFraction: config.convergenceToleranceFraction,
        maxConvergenceIterations: config.maxConvergenceIterations,
        gridExportLimitKw: config.gridExportLimitKw,
        latitudeDeg: config.latitudeDeg,
        longitudeDeg: config.longitudeDeg,
        weatherSource: config.weatherSource,
        temperatureModel: config.temperatureModel,
        // Only keep per-step data for the final year; earlier years
        // would be discarded anyway and `keepSteps:false` saves the
        // ~9 MiB quarter-hourly buffer allocation per year.
        keepSteps: config.keepSteps && y == years - 1,
        simulationYears: 1,
        tariff: config.tariff,
      );
      final yearProgress = onProgress == null
          ? null
          : (SimulationProgress p) {
              // Multi-year runs report progress via [year] /
              // [totalYears]; keep `iteration` at its inner default so
              // a downstream UI doesn't mistake year 2..N for cyclic-
              // convergence iterations (cyclic + multi-year is
              // rejected at validate() — they're mutually exclusive).
              onProgress(SimulationProgress(
                phase: p.phase,
                completedDays: p.completedDays,
                totalDays: p.totalDays,
                iteration: p.iteration,
                year: y + 1,
                totalYears: years,
              ));
            };
      final res = const PvSimulator()
          .run(yearConfig, onProgress: yearProgress);
      perYear.add(res.summary);
      carriedSocs = res.summary.finalBatterySocsKwh.toList();
      last = res;
    }
    final aggregated = _aggregateYears(
      perYear,
      preRunMode: config.preRunMode,
      // Multi-year always exercises at least one year of settling; the
      // top-level `preRunActive` reflects whether year 0 ran a warm-up.
      preRunActive: perYear.first.preRunActive,
      startSocsUsedKwh: perYear.first.startSocsUsedKwh,
      finalSocsKwh: last!.summary.finalBatterySocsKwh,
    );
    return SimulationResult(
      steps: last.steps,
      summary: aggregated,
    );
  }

  /// Builds the top-level summary for a multi-year run by summing the
  /// per-year scalar KPIs. The list itself is preserved on
  /// `perYearSummaries`.
  SimulationSummary _aggregateYears(
    List<SimulationSummary> perYear, {
    required PreRunMode preRunMode,
    required bool preRunActive,
    required List<double> startSocsUsedKwh,
    required List<double> finalSocsKwh,
  }) {
    var pvDc = 0.0,
        pvAc = 0.0,
        load = 0.0,
        sc = 0.0,
        bc = 0.0,
        bd = 0.0,
        gi = 0.0,
        ge = 0.0,
        cdc = 0.0,
        cac = 0.0,
        cex = 0.0,
        del = 0.0,
        sh = 0.0,
        unserved = 0.0,
        dcDirect = 0.0,
        dcCurtail = 0.0;
    // Tariff KPIs only carry meaning when every year produced one; if
    // some did and some didn't, the sum would mix € with null — treat
    // any null as "no economics".
    var importCost = 0.0;
    var exportRev = 0.0;
    var anyTariff = false;
    var allTariff = true;
    for (final s in perYear) {
      pvDc += s.pvDcKwh;
      pvAc += s.pvAcKwh;
      load += s.loadKwh;
      sc += s.selfConsumptionKwh;
      bc += s.batteryChargeKwh;
      bd += s.batteryDischargeKwh;
      gi += s.gridImportKwh;
      ge += s.gridExportKwh;
      cdc += s.curtailedDcKwh;
      cac += s.curtailedAcKwh;
      cex += s.curtailedExportKwh;
      del += s.microInverterDeliveredKwh;
      sh += s.microInverterShortfallKwh;
      unserved += s.unservedLoadKwh;
      dcDirect += s.dcDirectChargeKwh;
      dcCurtail += s.dcCurtailedKwh;
      if (s.importCostEur != null && s.exportRevenueEur != null) {
        importCost += s.importCostEur!;
        exportRev += s.exportRevenueEur!;
        anyTariff = true;
      } else {
        allTariff = false;
      }
    }
    final tariffActive = anyTariff && allTariff;
    return SimulationSummary(
      pvDcKwh: pvDc,
      pvAcKwh: pvAc,
      loadKwh: load,
      selfConsumptionKwh: sc,
      batteryChargeKwh: bc,
      batteryDischargeKwh: bd,
      gridImportKwh: gi,
      gridExportKwh: ge,
      curtailedDcKwh: cdc,
      curtailedAcKwh: cac,
      curtailedExportKwh: cex,
      finalBatterySocKwh:
          finalSocsKwh.fold<double>(0.0, (a, b) => a + b),
      finalBatterySocsKwh: List<double>.unmodifiable(finalSocsKwh),
      microInverterDeliveredKwh: del,
      microInverterShortfallKwh: sh,
      unservedLoadKwh: unserved,
      preRunMode: preRunMode,
      preRunActive: preRunActive,
      startSocsUsedKwh: List<double>.unmodifiable(startSocsUsedKwh),
      // Per-year settling re-runs the linear path's warm-up only in
      // year 0; mirror that single warm-up event here.
      convergenceIterations: preRunActive ? 1 : 0,
      converged: true,
      perYearSummaries: List<SimulationSummary>.unmodifiable(perYear),
      importCostEur: tariffActive ? importCost : null,
      exportRevenueEur: tariffActive ? exportRev : null,
      netCostEur: tariffActive ? importCost - exportRev : null,
      dcDirectChargeKwh: dcDirect,
      dcCurtailedKwh: dcCurtail,
    );
  }

  /// Linear (non-cyclic) execution path used by [PreRunMode.manual] and
  /// [PreRunMode.singleWarmUp]. Steps with `dayIndex < 0` mutate SOC
  /// but are dropped from the reported series — see Architektur §6
  /// "Der Pre-Run wird nicht in Jahres-KPIs eingerechnet".
  SimulationResult _runLinear(SimulationConfig config, {required int preRunDays, ProgressCallback? onProgress}) {
    final accumulator = _StepAccumulator();
    final socs = [for (final b in config.batteries) b.effectiveInitialSocKwh];
    final startSocs = List<double>.unmodifiable(socs);
    var capturedReportSocs = false;
    var reportedStartSocs = startSocs;

    final reportedSteps = config.days * config.timeStep.stepsPerDay;
    // When the caller doesn't want the per-step series, allocate a
    // 1-slot scratch buffer and overwrite it on every reported step.
    // The accumulator still reads scalars from index 0 — annual totals
    // are unchanged — but the 35 040-slot buffer's worth of memory is
    // no longer allocated. Pre-Phase-9-equivalent: ~5 MiB of scalar
    // columns + ~4 MiB of 2D rows per quarter-hourly year.
    final bufCapacity = config.keepSteps ? reportedSteps : 1;
    final buf = _StepBuffer(
      batteryCount: config.batteries.length,
      bankCount: config.microInverterBanks.length,
      arrayCount: config.arrays.length,
      capacity: bufCapacity,
    );
    final arrayDcScratch = Float64List(config.arrays.length);
    final arrayAcScratch = Float64List(config.arrays.length);
    var writeIdx = 0;

    for (var dayIndex = -preRunDays; dayIndex < config.days; dayIndex++) {
      final dayOfYear = _wrapDay(config.startDayOfYear + dayIndex);
      for (var stepOfDay = 0; stepOfDay < config.timeStep.stepsPerDay; stepOfDay++) {
        if (!capturedReportSocs && dayIndex >= 0) {
          // The "start SOC the reported year actually saw" is the SOC at
          // the entry of the first reported step (post-warm-up).
          reportedStartSocs = List<double>.unmodifiable(socs);
          capturedReportSocs = true;
        }
        final hourOfDay = (stepOfDay + 0.5) * config.timeStep.hours;
        if (dayIndex >= 0) {
          // With `keepSteps: false` the scratch buffer has capacity 1
          // and every step writes to index 0; with `keepSteps: true`
          // we advance the cursor to record each step.
          final slot = config.keepSteps ? writeIdx : 0;
          _simulateStep(config, socs, dayIndex, dayOfYear, stepOfDay, hourOfDay,
              buf, slot, arrayDcScratch, arrayAcScratch);
          accumulator.addFromBuffer(buf, slot);
          if (config.keepSteps) writeIdx++;
        } else {
          // Pre-run: advance SOC only; no buffer write, no allocation.
          _simulateStep(config, socs, dayIndex, dayOfYear, stepOfDay, hourOfDay,
              null, 0, arrayDcScratch, arrayAcScratch);
        }
      }
      if (onProgress != null) {
        if (dayIndex < 0) {
          onProgress(SimulationProgress(
            phase: SimulationPhase.preRun,
            completedDays: dayIndex + preRunDays + 1,
            totalDays: preRunDays,
          ));
        } else {
          onProgress(SimulationProgress(
            phase: SimulationPhase.reporting,
            completedDays: dayIndex + 1,
            totalDays: config.days,
          ));
        }
      }
    }

    buf.length = writeIdx;
    final preRunActive = preRunDays > 0 && config.batteries.isNotEmpty;
    return SimulationResult(
      steps: config.keepSteps ? _StepListView(buf) : const [],
      summary: _summarize(
        accumulator,
        socs,
        preRunMode: config.preRunMode,
        preRunActive: preRunActive,
        startSocsUsedKwh: reportedStartSocs,
        convergenceIterations: preRunActive ? 1 : 0,
        converged: true,
        tariff: config.tariff,
      ),
    );
  }

  /// Repeats the full 365-day year until the per-battery start↔end SOC
  /// delta is within `tolerance × usableCapacity` for every battery, or
  /// `maxConvergenceIterations` is reached. Only the final cycle's
  /// steps survive into [SimulationResult.steps] — earlier iterations
  /// are pre-run and are not reported per Architektur §6.
  SimulationResult _runCyclic(SimulationConfig config, {ProgressCallback? onProgress}) {
    final batteries = config.batteries;
    final socs = [for (final b in batteries) b.effectiveInitialSocKwh];
    final usable = [
      for (final b in batteries)
        math.max(0.0, b.capacityKwh - b.minSocKwh),
    ];
    final tolerances = [
      for (final u in usable) u * config.convergenceToleranceFraction,
    ];

    var lastAccumulator = _StepAccumulator();
    var iterations = 0;
    var converged = false;
    List<double> startSocs = List<double>.unmodifiable(socs);

    final reportedSteps = 365 * config.timeStep.stepsPerDay;
    // Reused across iterations — only the last cycle's data needs to
    // survive into `SimulationResult.steps`, and `writeIdx` resets to 0
    // at the start of every cycle so we overwrite in place. When the
    // caller doesn't want the per-step series, the buffer shrinks to a
    // single scratch slot — see the same logic in `_runLinear`.
    final bufCapacity = config.keepSteps ? reportedSteps : 1;
    final buf = _StepBuffer(
      batteryCount: batteries.length,
      bankCount: config.microInverterBanks.length,
      arrayCount: config.arrays.length,
      capacity: bufCapacity,
    );
    final arrayDcScratch = Float64List(config.arrays.length);
    final arrayAcScratch = Float64List(config.arrays.length);

    while (iterations < config.maxConvergenceIterations) {
      iterations += 1;
      startSocs = List<double>.unmodifiable(socs);
      final cycleAccumulator = _StepAccumulator();
      var writeIdx = 0;
      for (var dayIndex = 0; dayIndex < 365; dayIndex++) {
        final dayOfYear = _wrapDay(config.startDayOfYear + dayIndex);
        for (var stepOfDay = 0; stepOfDay < config.timeStep.stepsPerDay; stepOfDay++) {
          final hourOfDay = (stepOfDay + 0.5) * config.timeStep.hours;
          final slot = config.keepSteps ? writeIdx : 0;
          _simulateStep(config, socs, dayIndex, dayOfYear, stepOfDay, hourOfDay,
              buf, slot, arrayDcScratch, arrayAcScratch);
          cycleAccumulator.addFromBuffer(buf, slot);
          if (config.keepSteps) writeIdx++;
        }
        if (onProgress != null) {
          onProgress(SimulationProgress(
            phase: SimulationPhase.reporting,
            completedDays: dayIndex + 1,
            totalDays: 365,
            iteration: iterations,
          ));
        }
      }
      buf.length = writeIdx;
      lastAccumulator = cycleAccumulator;
      // Convergence: every battery's |start - end| must be within its
      // own usable-capacity tolerance. Batteries with usable == 0 are
      // trivially converged (the tolerance is 0 and the SOC cannot move).
      var allWithin = true;
      for (var i = 0; i < batteries.length; i++) {
        if ((socs[i] - startSocs[i]).abs() > tolerances[i]) {
          allWithin = false;
          break;
        }
      }
      if (allWithin) {
        converged = true;
        break;
      }
    }

    // When the loop exits without convergence, the buffer holds the
    // last (non-converged) cycle — the user still gets a complete year
    // of output, just marked converged = false.
    return SimulationResult(
      steps: config.keepSteps ? _StepListView(buf) : const [],
      summary: _summarize(
        lastAccumulator,
        socs,
        preRunMode: config.preRunMode,
        preRunActive: batteries.isNotEmpty,
        startSocsUsedKwh: startSocs,
        convergenceIterations: iterations,
        converged: converged || batteries.isEmpty,
        tariff: config.tariff,
      ),
    );
  }

  /// Runs one step's energy compute and writes the results into [buf] at
  /// [writeIdx]. Pass `buf = null` for pre-run steps — the SOC is still
  /// advanced via `router.apply()` (it mutates `socs` in place), but no
  /// step output is recorded.
  ///
  /// [arrayDcScratch] and [arrayAcScratch] are caller-owned reusable
  /// buffers sized to `config.arrays.length`; reusing them across all
  /// steps eliminates ~70 000 small list allocations on a quarter-hourly
  /// year and the GC pressure that comes with them.
  void _simulateStep(
    SimulationConfig config,
    List<double> socs,
    int dayIndex,
    int dayOfYear,
    int stepOfDay,
    double hourOfDay,
    _StepBuffer? buf,
    int writeIdx,
    Float64List arrayDcScratch,
    Float64List arrayAcScratch,
  ) {
    final stepHours = config.timeStep.hours;
    final inverterById = {for (final i in config.inverters) i.id: i};
    final dcByInverter = <String, double>{};
    final source = config.effectiveWeatherSource;
    final tempModel = config.temperatureModel;
    final topology = config.effectiveTopology;
    var pvDcKwh = 0.0;

    // === Phase 4b: DC-coupling pre-routing ===
    // Build cc lookup and the array→cc routing map from explicit edges.
    // When no charge controllers exist (legacy), `hasDcPath` stays
    // false and every downstream branch short-circuits — preserving
    // byte-identical results for AC-only scenarios.
    final ccById = {for (final c in topology.chargeControllers) c.id: c};
    final arrayToCc = <String, String>{};
    if (ccById.isNotEmpty) {
      for (final e in topology.edges) {
        if (ccById.containsKey(e.toId)) {
          arrayToCc[e.fromId] = e.toId;
        }
      }
    }
    final hasDcPath = arrayToCc.isNotEmpty;
    final dcByController = hasDcPath ? <String, double>{} : null;

    for (var i = 0; i < config.arrays.length; i++) {
      final array = config.arrays[i];
      final weather = source.sampleFor(WeatherQuery(
        arrayId: array.id,
        tiltDeg: array.tiltDeg,
        azimuthDeg: array.azimuthDeg,
        dayOfYear: dayOfYear,
        hourOfDay: hourOfDay,
        latitudeDeg: config.latitudeDeg,
      ));
      final dcKwh = _dcPowerKwFromWeather(array, weather, tempModel) * stepHours;
      pvDcKwh += dcKwh;
      arrayDcScratch[i] = dcKwh;
      // Partition: arrays wired into a charge controller via an edge
      // `array.id → cc.id` flow on the DC bus path; everyone else
      // stays on the legacy inverter path.
      final ccId = hasDcPath ? arrayToCc[array.id] : null;
      if (ccId != null) {
        dcByController!.update(ccId, (v) => v + dcKwh, ifAbsent: () => dcKwh);
      } else {
        dcByInverter.update(array.inverterId, (v) => v + dcKwh, ifAbsent: () => dcKwh);
      }
    }

    var pvAcKwh = 0.0;
    var curtailedDcKwh = 0.0;
    var curtailedAcKwh = 0.0;
    var dcDirectChargeKwhTotal = 0.0;
    var dcCurtailedKwhTotal = 0.0;
    // For per-array AC distribution: remember each inverter's
    // (limitedAc, dcAfterCap) pair so the array breakdown can scale
    // each array's DC share by the same loss ratio its inverter saw.
    final acRatioByInverter = <String, double>{};
    // Per-inverter post-clip DC consumed by the AC path; subtracted
    // from `maxDcInputKw * stepHours` when the same inverter also
    // receives PV-DC via a hybrid DC bus, so the inverter's DC stage
    // sees a single shared cap across both flows.
    final dcConsumedByInverter = <String, double>{};
    for (final entry in dcByInverter.entries) {
      final inverter = inverterById[entry.key]!;
      var dcKwh = entry.value;
      // DC-side clipping: oversized arrays driving the inverter past
      // its MPPT/DC rating lose the surplus before AC conversion. The
      // loss is reported in DC kWh — converting to "what AC would
      // have been delivered" would hide the upstream geometry.
      final dcLimit = inverter.maxDcInputKw;
      if (dcLimit != null) {
        final dcCapKwh = dcLimit * stepHours;
        if (dcKwh > dcCapKwh) {
          curtailedDcKwh += dcKwh - dcCapKwh;
          dcKwh = dcCapKwh;
        }
      }
      dcConsumedByInverter[entry.key] = dcKwh;
      final rawAc = dcKwh * inverter.efficiency;
      final limitedAc = math.min(rawAc, inverter.effectiveMaxAcKw * stepHours);
      pvAcKwh += limitedAc;
      curtailedAcKwh += math.max(0.0, rawAc - limitedAc);
      // ratio = limitedAc / entry.value (original pre-cap DC sum) so
      // the per-array distribution captures both DC clipping and AC
      // clipping in one factor.
      acRatioByInverter[entry.key] =
          entry.value > 0 ? limitedAc / entry.value : 0.0;
    }

    // === DC-path: charge-controller clip + efficiency → DC bus ===
    // pvDcByBus[B] is the bus-side energy available to (a) charge a
    // DC-coupled battery on B, and (b) flow through a hybrid inverter
    // to AC. Bookkeeping for per-array AC distribution is captured in
    // `ccCapRatio` (post-cap / pre-cap per controller) and
    // `acBypassRatioByBus` (AC kWh out of the bus per pre-charging DC
    // kWh on the bus).
    final pvDcByBus = <String, double>{};
    final pvDcByBusBefore = <String, double>{};
    final ccCapRatio = <String, double>{};
    final acBypassRatioByBus = <String, double>{};
    final dcDirectCharges = List<double>.filled(config.batteries.length, 0.0);
    final dcCoupledIndices = <int>{};
    if (hasDcPath || topology.batteryCouplings
        .any((c) => c.coupling == BatteryCoupling.dc)) {
      // Pre-cap clip + efficiency per controller.
      if (hasDcPath) {
        for (final entry in dcByController!.entries) {
          final cc = ccById[entry.key]!;
          final dcSumPre = entry.value;
          var postCapDc = dcSumPre;
          final cap = cc.maxInputKw;
          if (cap != null) {
            final capKwh = cap * stepHours;
            if (postCapDc > capKwh) {
              curtailedDcKwh += postCapDc - capKwh;
              postCapDc = capKwh;
            }
          }
          ccCapRatio[cc.id] = dcSumPre > 0 ? postCapDc / dcSumPre : 0.0;
          final busSide = postCapDc * cc.efficiency;
          pvDcByBus.update(cc.dcBusId, (v) => v + busSide,
              ifAbsent: () => busSide);
        }
        pvDcByBusBefore.addAll(pvDcByBus);
      }

      // Identify DC-coupled batteries grouped by bus.
      final dcBatteriesByBus = <String, List<int>>{};
      for (var i = 0; i < config.batteries.length; i++) {
        final coupling = topology.couplingFor(config.batteries[i].id);
        if (coupling.coupling == BatteryCoupling.dc &&
            coupling.dcBusId != null) {
          dcCoupledIndices.add(i);
          dcBatteriesByBus
              .putIfAbsent(coupling.dcBusId!, () => [])
              .add(i);
        }
      }

      // For each DC bus carrying PV-DC: charge DC-coupled batteries
      // (step 1b), then route residual via hybrid inverter (1c) or
      // curtail on batteryFed (1d).
      for (final busId in pvDcByBus.keys.toList()) {
        // 1b: charge DC-coupled batteries (unconditional — physics).
        final batteries = dcBatteriesByBus[busId] ?? const <int>[];
        for (final k in batteries) {
          if ((pvDcByBus[busId] ?? 0) <= 0) break;
          final battery = config.batteries[k];
          final chargeEff = battery.chargeEfficiency;
          if (chargeEff <= 0) continue;
          final headroomStored =
              math.max(0.0, battery.capacityKwh - socs[k]);
          final headroomDc = headroomStored / chargeEff;
          final rateCap = battery.maxChargeKw * stepHours;
          final available = pvDcByBus[busId]!;
          final deliverable =
              math.min(available, math.min(rateCap, headroomDc));
          if (deliverable <= 0) continue;
          socs[k] += deliverable * chargeEff;
          pvDcByBus[busId] = available - deliverable;
          dcDirectCharges[k] += deliverable;
          dcDirectChargeKwhTotal += deliverable;
        }

        final residual = pvDcByBus[busId] ?? 0;
        if (residual <= 0) {
          acBypassRatioByBus[busId] = 0.0;
          continue;
        }
        final bus = topology.dcBusById(busId);
        final mode = bus?.mode ?? BusMode.hybrid;
        if (mode == BusMode.hybrid) {
          // 1c: residual → hybrid inverter → AC. Find the first edge
          // `busId → inverterId` in the topology.
          Inverter? hybrid;
          double hybridEta = 1.0;
          for (final e in topology.edges) {
            if (e.fromId == busId && inverterById.containsKey(e.toId)) {
              hybrid = inverterById[e.toId];
              hybridEta = e.efficiency;
              break;
            }
          }
          if (hybrid != null) {
            // Hybrid inverters share their DC stage with any direct
            // AC-path PV: enforce `maxDcInputKw` on the SUM of legacy
            // AC-path DC and bus-side residual. Already-consumed
            // headroom is subtracted from the cap; remainder is
            // available for the bypass, overflow accrues as DC
            // curtailment (same units as the legacy clip).
            var clippedResidual = residual;
            final dcLimit = hybrid.maxDcInputKw;
            if (dcLimit != null) {
              final consumed =
                  dcConsumedByInverter[hybrid.id] ?? 0.0;
              final remainingDc =
                  math.max(0.0, dcLimit * stepHours - consumed);
              if (clippedResidual > remainingDc) {
                curtailedDcKwh += clippedResidual - remainingDc;
                clippedResidual = remainingDc;
              }
              dcConsumedByInverter[hybrid.id] =
                  consumed + clippedResidual;
            }
            // Inverter own efficiency is multiplicative with the edge
            // efficiency (the edge already carries it in fromLegacy,
            // but explicit topologies might split them — multiply both
            // for safety).
            final rawAc = clippedResidual * hybridEta * hybrid.efficiency;
            final limitedAc =
                math.min(rawAc, hybrid.effectiveMaxAcKw * stepHours);
            pvAcKwh += limitedAc;
            curtailedAcKwh += math.max(0.0, rawAc - limitedAc);
            final preChargeBus = pvDcByBusBefore[busId] ?? 0.0;
            acBypassRatioByBus[busId] =
                preChargeBus > 0 ? limitedAc / preChargeBus : 0.0;
          } else {
            // Hybrid bus without a hybrid inverter wired up — residual
            // has no AC path. Treat as DC curtailment so the energy
            // balance stays honest. Validation should normally catch
            // this misconfiguration (rule 4 in chunk 4).
            dcCurtailedKwhTotal += residual;
            acBypassRatioByBus[busId] = 0.0;
          }
        } else {
          // 1d: batteryFed — residual is lost.
          dcCurtailedKwhTotal += residual;
          acBypassRatioByBus[busId] = 0.0;
        }
        pvDcByBus[busId] = 0;
      }
    }

    for (var i = 0; i < config.arrays.length; i++) {
      final array = config.arrays[i];
      final ccId = hasDcPath ? arrayToCc[array.id] : null;
      if (ccId == null) {
        // Legacy AC path.
        arrayAcScratch[i] = arrayDcScratch[i] *
            (acRatioByInverter[array.inverterId] ?? 0.0);
      } else {
        // DC path: factor in cc input clip, cc efficiency, and the
        // bus-side AC-bypass ratio. For batteryFed buses or buses
        // where the battery absorbed everything, the ratio is 0.
        final cc = ccById[ccId]!;
        final clip = ccCapRatio[ccId] ?? 0.0;
        final busRatio = acBypassRatioByBus[cc.dcBusId] ?? 0.0;
        arrayAcScratch[i] =
            arrayDcScratch[i] * clip * cc.efficiency * busRatio;
      }
    }

    final loadKwh = config.loadProfile.energyKwhForStep(hourOfDay: hourOfDay, timeStep: config.timeStep);

    // Dispatch-policy pipeline. The legacy battery dispatch + grid
    // import/export logic now lives in the router; the policy decides
    // *what to request*, the router enforces hard limits.
    final batteryIds = [for (final b in config.batteries) b.id];
    final capacities = [for (final b in config.batteries) b.capacityKwh];
    final minSocs = [for (final b in config.batteries) b.minSocKwh];
    final maxCharge = [for (final b in config.batteries) b.maxChargeKw];
    final maxDischarge = [for (final b in config.batteries) b.maxDischargeKw];
    final chargeEta = [for (final b in config.batteries) b.chargeEfficiency];
    final dischargeEta = [for (final b in config.batteries) b.dischargeEfficiency];

    final policy = config.effectiveDispatchPolicy;
    final ctx = DispatchContext(
      hourOfDay: hourOfDay,
      dayOfYear: dayOfYear,
      stepHours: stepHours,
      pvAcKwh: pvAcKwh,
      loadKwh: loadKwh,
      batteryStates: List<double>.unmodifiable(socs),
      batteryCapacitiesKwh: capacities,
      batteryMinSocsKwh: minSocs,
      batteryMaxChargeKw: maxCharge,
      batteryMaxDischargeKw: maxDischarge,
      batteryChargeEfficiency: chargeEta,
      batteryDischargeEfficiency: dischargeEta,
      batteryIds: batteryIds,
      banks: config.microInverterBanks,
      topology: topology,
      gridExportLimitKw: config.gridExportLimitKw,
    );

    final plan = policy.plan(ctx);

    // Per-battery AC envelope per Architektur §5.3:
    //   `allowedPowerW = min(targetPowerW, battery.maxDischargeW, inverterLimitW)`.
    // When a battery's topology coupling names an AC-side `inverterId`,
    // take the **minimum** of the battery's own discharge rating and that
    // inverter's effective AC cap (already 800-W-clamped for
    // `InverterRole.microInverter800W`). Without an inverter — or for a
    // DC-coupled battery, where `inverterId` describes a non-AC path —
    // fall back to the legacy `maxDischargeKw` cap, preserving pre-Phase-4
    // behaviour.
    final acCapKwh = <double>[
      for (var i = 0; i < config.batteries.length; i++)
        () {
          final batteryAcCap = maxDischarge[i] * stepHours;
          final coupling = topology.couplingFor(config.batteries[i].id);
          if (coupling.coupling != BatteryCoupling.ac) return batteryAcCap;
          final invId = coupling.inverterId;
          if (invId == null) return batteryAcCap;
          final inv = inverterById[invId];
          if (inv == null) return batteryAcCap;
          final inverterAcCap = inv.effectiveMaxAcKw * stepHours;
          return inverterAcCap < batteryAcCap ? inverterAcCap : batteryAcCap;
        }(),
    ];

    final flows = const EnergyRouter().apply(
      plan: plan,
      socs: socs,
      capacitiesKwh: capacities,
      minSocsKwh: minSocs,
      maxChargeKw: maxCharge,
      maxDischargeKw: maxDischarge,
      chargeEfficiency: chargeEta,
      dischargeEfficiency: dischargeEta,
      batteryIds: batteryIds,
      banks: config.microInverterBanks,
      pvAcKwh: pvAcKwh,
      loadKwh: loadKwh,
      stepHours: stepHours,
      gridExportLimitKw: config.gridExportLimitKw,
      batteryAcCapKwh: acCapKwh,
      skipChargeIndices: dcCoupledIndices,
    );

    // For pre-run steps `buf` is null — the SOC mutation from
    // `router.apply()` has already happened via `flows`, which is all
    // pre-run needs. Skipping the buffer write here avoids the per-step
    // SimulationStep + 7 List<double> allocations the simulator used to
    // pay for results it threw away anyway.
    if (buf == null) return;

    var totalCharge = 0.0;
    var totalDischarge = 0.0;
    for (var i = 0; i < buf.batteryCount; i++) {
      // For DC-coupled batteries the AC router skipped charging, so
      // `flows.batteryChargesKwh[i]` is 0 — the actual charge came in
      // via the DC pre-step (`dcDirectCharges[i]`). For AC-coupled
      // batteries `dcDirectCharges[i]` is 0. Summing both keeps the
      // per-step "battery in" total honest regardless of coupling.
      final ac = flows.batteryChargesKwh[i];
      final dc = i < dcDirectCharges.length ? dcDirectCharges[i] : 0.0;
      final c = ac + dc;
      final d = flows.batteryDischargesKwh[i];
      totalCharge += c;
      totalDischarge += d;
      final row = writeIdx * buf.batteryCount + i;
      buf.batteryCharges[row] = c;
      buf.batteryDischarges[row] = d;
      buf.batterySocs[row] = flows.batterySocsKwh[i];
    }
    var totalDelivered = 0.0;
    var totalShortfall = 0.0;
    for (var i = 0; i < buf.bankCount; i++) {
      final del = flows.bankDeliveriesKwh[i];
      final sh = flows.bankShortfallsKwh[i];
      totalDelivered += del;
      totalShortfall += sh;
      final row = writeIdx * buf.bankCount + i;
      buf.bankDeliveries[row] = del;
      buf.bankShortfalls[row] = sh;
    }
    var aggregateSoc = 0.0;
    for (var i = 0; i < socs.length; i++) {
      aggregateSoc += socs[i];
    }
    for (var i = 0; i < buf.arrayCount; i++) {
      final row = writeIdx * buf.arrayCount + i;
      buf.arrayDc[row] = arrayDcScratch[i];
      buf.arrayAc[row] = arrayAcScratch[i];
    }

    buf.dayIndex[writeIdx] = dayIndex;
    buf.dayOfYear[writeIdx] = dayOfYear;
    buf.stepOfDay[writeIdx] = stepOfDay;
    buf.hourOfDay[writeIdx] = hourOfDay;
    buf.pvDcKwh[writeIdx] = pvDcKwh;
    buf.pvAcKwh[writeIdx] = pvAcKwh;
    buf.loadKwh[writeIdx] = loadKwh;
    buf.selfConsumptionKwh[writeIdx] = flows.selfConsumptionKwh;
    buf.batteryChargeKwh[writeIdx] = totalCharge;
    buf.batteryDischargeKwh[writeIdx] = totalDischarge;
    buf.batterySocKwh[writeIdx] = aggregateSoc;
    buf.gridImportKwh[writeIdx] = flows.gridImportKwh;
    buf.gridExportKwh[writeIdx] = flows.gridExportKwh;
    buf.curtailedDcKwh[writeIdx] = curtailedDcKwh;
    buf.curtailedAcKwh[writeIdx] = curtailedAcKwh;
    buf.curtailedExportKwh[writeIdx] = flows.curtailedExportKwh;
    buf.microInverterDeliveredKwh[writeIdx] = totalDelivered;
    buf.microInverterShortfallKwh[writeIdx] = totalShortfall;
    buf.unservedLoadKwh[writeIdx] = flows.unservedLoadKwh;
    buf.dcDirectChargeKwh[writeIdx] = dcDirectChargeKwhTotal;
    buf.dcCurtailedKwh[writeIdx] = dcCurtailedKwhTotal;

    // Tariff accounting AFTER the dispatch finalises grid I/O — the
    // locked dispatch order (steps 1..6) is untouched. When no tariff
    // is configured the columns stay at their zero-initialised default.
    final tariff = config.tariff;
    if (tariff != null) {
      buf.importCostEur[writeIdx] =
          flows.gridImportKwh * tariff.importPriceAtHour(hourOfDay);
      buf.exportRevenueEur[writeIdx] =
          flows.gridExportKwh * tariff.exportPriceAtHour(hourOfDay);
    }
  }

  double _dcPowerKwFromWeather(PvArray array, WeatherSample weather, TemperatureModel tempModel) {
    if (weather.poaWPerM2 <= 0) return 0;
    final cellTemp = tempModel.cellTemperatureC(
      weather,
      nominalOperatingCellTempC: array.nominalOperatingCellTempC,
    );
    final tempDerate = 1.0 + (array.temperatureCoefficientPctPerC / 100.0) * (cellTemp - 25.0);
    final retained = (1 - array.lossFactor) * (1 - array.shadingFactor);
    return array.peakKw * (weather.poaWPerM2 / 1000.0) * retained * math.max(0.0, tempDerate);
  }

  SimulationSummary _summarize(
    _StepAccumulator acc,
    List<double> finalSocs, {
    required PreRunMode preRunMode,
    required bool preRunActive,
    required List<double> startSocsUsedKwh,
    required int convergenceIterations,
    required bool converged,
    TariffConfig? tariff,
  }) {
    final hasTariff = tariff != null;
    return SimulationSummary(
      pvDcKwh: acc.pvDcKwh,
      pvAcKwh: acc.pvAcKwh,
      loadKwh: acc.loadKwh,
      selfConsumptionKwh: acc.selfConsumptionKwh,
      batteryChargeKwh: acc.batteryChargeKwh,
      batteryDischargeKwh: acc.batteryDischargeKwh,
      gridImportKwh: acc.gridImportKwh,
      gridExportKwh: acc.gridExportKwh,
      curtailedDcKwh: acc.curtailedDcKwh,
      curtailedAcKwh: acc.curtailedAcKwh,
      curtailedExportKwh: acc.curtailedExportKwh,
      finalBatterySocKwh: finalSocs.fold<double>(0.0, (a, b) => a + b),
      finalBatterySocsKwh: List<double>.unmodifiable(finalSocs),
      microInverterDeliveredKwh: acc.microInverterDeliveredKwh,
      microInverterShortfallKwh: acc.microInverterShortfallKwh,
      unservedLoadKwh: acc.unservedLoadKwh,
      preRunMode: preRunMode,
      preRunActive: preRunActive,
      startSocsUsedKwh: List<double>.unmodifiable(startSocsUsedKwh),
      convergenceIterations: convergenceIterations,
      converged: converged,
      importCostEur: hasTariff ? acc.importCostEur : null,
      exportRevenueEur: hasTariff ? acc.exportRevenueEur : null,
      netCostEur: hasTariff ? acc.importCostEur - acc.exportRevenueEur : null,
      dcDirectChargeKwh: acc.dcDirectChargeKwh,
      dcCurtailedKwh: acc.dcCurtailedKwh,
    );
  }

  int _wrapDay(int day) {
    // Modulo wrap into [1, 365] in O(1). The double-modulo form handles
    // negative inputs correctly under Dart's truncating `%`.
    return ((day - 1) % 365 + 365) % 365 + 1;
  }
}

void _require(bool condition, String message) {
  if (!condition) throw ArgumentError(message);
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  throw ArgumentError('Expected num, got ${value.runtimeType}');
}

InverterRole _inverterRoleFromName(String name) {
  for (final role in InverterRole.values) {
    if (role.name == name) return role;
  }
  throw ArgumentError('Unknown InverterRole: $name');
}

TimeStep _timeStepFromName(String name) {
  for (final step in TimeStep.values) {
    if (step.name == name) return step;
  }
  throw ArgumentError('Unknown TimeStep: $name');
}
