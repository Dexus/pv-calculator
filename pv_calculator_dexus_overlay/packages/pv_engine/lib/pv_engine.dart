import 'dart:math' as math;

import 'src/dispatch_policies.dart';
import 'src/dispatch_policy.dart';
import 'src/energy_router.dart';
import 'src/micro_inverter_bank.dart';
import 'src/temperature_model.dart';
import 'src/topology.dart';
import 'src/weather.dart';

export 'src/csv_export.dart';
export 'src/dispatch_policies.dart';
export 'src/dispatch_policy.dart';
export 'src/energy_router.dart';
export 'src/micro_inverter_bank.dart';
export 'src/pvgis.dart';
export 'src/pvgis_client.dart';
export 'src/summary_aggregator.dart';
export 'src/temperature_model.dart';
export 'src/topology.dart';
export 'src/transposition.dart';
export 'src/weather.dart';

enum InverterRole { grid, microInverter800W, batteryCoupled }

enum TimeStep {
  hourly(60),
  quarterHourly(15);

  const TimeStep(this.minutes);
  final int minutes;
  double get hours => minutes / 60.0;
  int get stepsPerDay => (24 * 60 / minutes).round();
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
    this.gridExportLimitKw,
    this.latitudeDeg = 50.0,
    this.longitudeDeg = 10.0,
    this.weatherSource,
    this.temperatureModel = const NoctTemperatureModel(),
  });

  final List<PvArray> arrays;
  final List<Inverter> inverters;
  final List<BatteryConfig> batteries;

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
    if (explicitTopology != null) {
      explicitTopology.validate(
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
    // actually set, so legacy consumers continue to see v1 JSON.
    final hasPhase4 = topology != null ||
        dispatchPolicy != null ||
        microInverterBanks.isNotEmpty;
    final json = <String, dynamic>{
      'schemaVersion': hasPhase4 ? 2 : 1,
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
    };
    if (hasPhase4) {
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
    return json;
  }

  static SimulationConfig fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as int? ?? 1;
    if (version != 1 && version != 2) {
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
      gridExportLimitKw: json['gridExportLimitKw'] == null ? null : _toDouble(json['gridExportLimitKw']),
      latitudeDeg: _toDouble(json['latitudeDeg'] ?? 50.0),
      longitudeDeg: _toDouble(json['longitudeDeg'] ?? 10.0),
    );
  }
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
  });

  final double pvDcKwh;
  final double pvAcKwh;
  final double loadKwh;
  final double selfConsumptionKwh;
  final double batteryChargeKwh;
  final double batteryDischargeKwh;
  final double gridImportKwh;
  final double gridExportKwh;

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

  double get selfConsumptionRate => pvAcKwh <= 0 ? 0 : selfConsumptionKwh / pvAcKwh;
  double get autarkyRate => loadKwh <= 0 ? 0 : selfConsumptionKwh / loadKwh;
}

class SimulationResult {
  const SimulationResult({required this.steps, required this.summary});
  final List<SimulationStep> steps;
  final SimulationSummary summary;
}

class PvSimulator {
  const PvSimulator();

  SimulationResult run(SimulationConfig config) {
    config.validate();
    // Pre-flight the weather source against the array roster so a
    // typo in an array id surfaces immediately instead of producing
    // a quiet zero-yield column in the summary.
    config.effectiveWeatherSource
        .validateForArrays(config.arrays.map((a) => a.id));
    final steps = <SimulationStep>[];
    final socs = [for (final b in config.batteries) b.effectiveInitialSocKwh];

    for (var dayIndex = -config.preRunDays; dayIndex < config.days; dayIndex++) {
      final dayOfYear = _wrapDay(config.startDayOfYear + dayIndex);
      for (var stepOfDay = 0; stepOfDay < config.timeStep.stepsPerDay; stepOfDay++) {
        final hourOfDay = (stepOfDay + 0.5) * config.timeStep.hours;
        final step = _simulateStep(config, socs, dayIndex, dayOfYear, stepOfDay, hourOfDay);
        if (dayIndex >= 0) steps.add(step);
      }
    }
    return SimulationResult(steps: steps, summary: _summarize(steps, socs));
  }

  SimulationStep _simulateStep(SimulationConfig config, List<double> socs, int dayIndex, int dayOfYear, int stepOfDay, double hourOfDay) {
    final stepHours = config.timeStep.hours;
    final inverterById = {for (final i in config.inverters) i.id: i};
    final dcByInverter = <String, double>{};
    final source = config.effectiveWeatherSource;
    final tempModel = config.temperatureModel;
    var pvDcKwh = 0.0;

    for (final array in config.arrays) {
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
      dcByInverter.update(array.inverterId, (value) => value + dcKwh, ifAbsent: () => dcKwh);
    }

    var pvAcKwh = 0.0;
    var curtailedDcKwh = 0.0;
    var curtailedAcKwh = 0.0;
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
      final rawAc = dcKwh * inverter.efficiency;
      final limitedAc = math.min(rawAc, inverter.effectiveMaxAcKw * stepHours);
      pvAcKwh += limitedAc;
      curtailedAcKwh += math.max(0.0, rawAc - limitedAc);
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
    final topology = config.effectiveTopology;
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

    // Per-battery AC envelope (Architektur §5.3 `inverterLimitW`). When
    // a battery's topology coupling names an `inverterId`, use that
    // inverter's effective AC cap (already 800-W-clamped for the
    // `microInverter800W` role); otherwise fall back to the legacy
    // `maxDischargeKw` cap so pre-Phase-4 projects keep their numbers.
    final acCapKwh = <double>[
      for (var i = 0; i < config.batteries.length; i++)
        () {
          final coupling = topology.couplingFor(config.batteries[i].id);
          final invId = coupling.inverterId;
          if (invId == null) return maxDischarge[i] * stepHours;
          final inv = inverterById[invId];
          if (inv == null) return maxDischarge[i] * stepHours;
          return inv.effectiveMaxAcKw * stepHours;
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
    );

    final aggregateSoc = socs.fold<double>(0.0, (a, b) => a + b);
    final totalCharge = flows.batteryChargesKwh.fold<double>(0.0, (a, b) => a + b);
    final totalDischarge = flows.batteryDischargesKwh.fold<double>(0.0, (a, b) => a + b);
    final totalDelivered = flows.bankDeliveriesKwh.fold<double>(0.0, (a, b) => a + b);
    final totalShortfall = flows.bankShortfallsKwh.fold<double>(0.0, (a, b) => a + b);

    return SimulationStep(
      dayIndex: dayIndex,
      dayOfYear: dayOfYear,
      stepOfDay: stepOfDay,
      hourOfDay: hourOfDay,
      pvDcKwh: pvDcKwh,
      pvAcKwh: pvAcKwh,
      loadKwh: loadKwh,
      selfConsumptionKwh: flows.selfConsumptionKwh,
      batteryChargeKwh: totalCharge,
      batteryDischargeKwh: totalDischarge,
      batterySocKwh: aggregateSoc,
      batteryChargesKwh: flows.batteryChargesKwh,
      batteryDischargesKwh: flows.batteryDischargesKwh,
      batterySocsKwh: flows.batterySocsKwh,
      gridImportKwh: flows.gridImportKwh,
      gridExportKwh: flows.gridExportKwh,
      curtailedDcKwh: curtailedDcKwh,
      curtailedAcKwh: curtailedAcKwh,
      curtailedExportKwh: flows.curtailedExportKwh,
      microInverterDeliveredKwh: totalDelivered,
      microInverterShortfallKwh: totalShortfall,
      microInverterDeliveriesKwh: flows.bankDeliveriesKwh,
      microInverterShortfallsKwh: flows.bankShortfallsKwh,
      unservedLoadKwh: flows.unservedLoadKwh,
    );
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

  SimulationSummary _summarize(List<SimulationStep> steps, List<double> finalSocs) {
    double sum(double Function(SimulationStep step) selector) => steps.fold<double>(0.0, (total, step) => total + selector(step));
    return SimulationSummary(
      pvDcKwh: sum((s) => s.pvDcKwh),
      pvAcKwh: sum((s) => s.pvAcKwh),
      loadKwh: sum((s) => s.loadKwh),
      selfConsumptionKwh: sum((s) => s.selfConsumptionKwh),
      batteryChargeKwh: sum((s) => s.batteryChargeKwh),
      batteryDischargeKwh: sum((s) => s.batteryDischargeKwh),
      gridImportKwh: sum((s) => s.gridImportKwh),
      gridExportKwh: sum((s) => s.gridExportKwh),
      curtailedDcKwh: sum((s) => s.curtailedDcKwh),
      curtailedAcKwh: sum((s) => s.curtailedAcKwh),
      curtailedExportKwh: sum((s) => s.curtailedExportKwh),
      finalBatterySocKwh: finalSocs.fold<double>(0.0, (a, b) => a + b),
      finalBatterySocsKwh: List<double>.unmodifiable(finalSocs),
      microInverterDeliveredKwh: sum((s) => s.microInverterDeliveredKwh),
      microInverterShortfallKwh: sum((s) => s.microInverterShortfallKwh),
      unservedLoadKwh: sum((s) => s.unservedLoadKwh),
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
