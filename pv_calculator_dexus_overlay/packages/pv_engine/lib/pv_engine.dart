import 'dart:math' as math;

export 'src/csv_export.dart';
export 'src/summary_aggregator.dart';

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
  });

  final String id;
  final String label;
  final double peakKw;
  final double azimuthDeg;
  final double tiltDeg;
  final String inverterId;
  final double lossFactor;
  final double shadingFactor;

  void validate() {
    _require(id.trim().isNotEmpty, 'PV array id must not be empty.');
    _require(peakKw > 0, 'PV array $id peakKw must be positive.');
    _require(tiltDeg >= 0 && tiltDeg <= 90, 'PV array $id tiltDeg must be between 0 and 90.');
    _require(lossFactor >= 0 && lossFactor < 1, 'PV array $id lossFactor must be in [0, 1).');
    _require(shadingFactor >= 0 && shadingFactor < 1, 'PV array $id shadingFactor must be in [0, 1).');
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
      );
}

class Inverter {
  const Inverter({
    required this.id,
    required this.label,
    required this.maxAcKw,
    this.role = InverterRole.grid,
    this.efficiency = 0.965,
  });

  final String id;
  final String label;
  final double maxAcKw;
  final InverterRole role;
  final double efficiency;

  double get effectiveMaxAcKw => role == InverterRole.microInverter800W ? math.min(maxAcKw, 0.8) : maxAcKw;

  void validate() {
    _require(id.trim().isNotEmpty, 'Inverter id must not be empty.');
    _require(maxAcKw > 0, 'Inverter $id maxAcKw must be positive.');
    _require(efficiency > 0 && efficiency <= 1, 'Inverter $id efficiency must be in (0, 1].');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'maxAcKw': maxAcKw,
        'role': role.name,
        'efficiency': efficiency,
      };

  static Inverter fromJson(Map<String, dynamic> json) => Inverter(
        id: (json['id'] as String).trim(),
        label: json['label'] as String,
        maxAcKw: _toDouble(json['maxAcKw']),
        role: _inverterRoleFromName(json['role'] as String? ?? 'grid'),
        efficiency: _toDouble(json['efficiency'] ?? 0.965),
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
    this.startDayOfYear = 1,
    this.days = 365,
    this.timeStep = TimeStep.hourly,
    this.preRunDays = 0,
    this.gridExportLimitKw,
    this.latitudeDeg = 50.0,
  });

  final List<PvArray> arrays;
  final List<Inverter> inverters;
  final List<BatteryConfig> batteries;
  final LoadProfile loadProfile;
  final int startDayOfYear;
  final int days;
  final TimeStep timeStep;
  final int preRunDays;
  final double? gridExportLimitKw;
  final double latitudeDeg;

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
    _require(gridExportLimitKw == null || gridExportLimitKw! >= 0, 'gridExportLimitKw must not be negative.');
    final inverterIds = <String>{};
    for (final inverter in inverters) {
      inverter.validate();
      _require(inverterIds.add(inverter.id), 'Duplicate inverter id: ${inverter.id}.');
    }
    for (final array in arrays) {
      array.validate();
      _require(inverterIds.contains(array.inverterId), 'PV array ${array.id} references missing inverter ${array.inverterId}.');
    }
    final batteryIds = <String>{};
    for (final battery in batteries) {
      battery.validate();
      _require(batteryIds.add(battery.id), 'Duplicate battery id: ${battery.id}.');
    }
    loadProfile.validate();
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
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
      };

  static SimulationConfig fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as int? ?? 1;
    if (version != 1) {
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

    return SimulationConfig(
      arrays: (json['arrays'] as List)
          .map((e) => PvArray.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
      inverters: (json['inverters'] as List)
          .map((e) => Inverter.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
      batteries: batteries,
      loadProfile: LoadProfile.fromJson((json['loadProfile'] as Map).cast<String, dynamic>()),
      startDayOfYear: (json['startDayOfYear'] as num?)?.toInt() ?? 1,
      days: (json['days'] as num?)?.toInt() ?? 365,
      timeStep: _timeStepFromName(json['timeStep'] as String? ?? 'hourly'),
      preRunDays: (json['preRunDays'] as num?)?.toInt() ?? 0,
      gridExportLimitKw: json['gridExportLimitKw'] == null ? null : _toDouble(json['gridExportLimitKw']),
      latitudeDeg: _toDouble(json['latitudeDeg'] ?? 50.0),
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
    required this.curtailedKwh,
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
  final double curtailedKwh;
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
    required this.curtailedKwh,
    required this.finalBatterySocKwh,
    required this.finalBatterySocsKwh,
  });

  final double pvDcKwh;
  final double pvAcKwh;
  final double loadKwh;
  final double selfConsumptionKwh;
  final double batteryChargeKwh;
  final double batteryDischargeKwh;
  final double gridImportKwh;
  final double gridExportKwh;
  final double curtailedKwh;
  final double finalBatterySocKwh;
  final List<double> finalBatterySocsKwh;

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
    var pvDcKwh = 0.0;

    for (final array in config.arrays) {
      final dcKwh = _dcPowerKw(array, dayOfYear, hourOfDay, config.latitudeDeg) * stepHours;
      pvDcKwh += dcKwh;
      dcByInverter.update(array.inverterId, (value) => value + dcKwh, ifAbsent: () => dcKwh);
    }

    var pvAcKwh = 0.0;
    var curtailedKwh = 0.0;
    for (final entry in dcByInverter.entries) {
      final inverter = inverterById[entry.key]!;
      final rawAc = entry.value * inverter.efficiency;
      final limitedAc = math.min(rawAc, inverter.effectiveMaxAcKw * stepHours);
      pvAcKwh += limitedAc;
      curtailedKwh += math.max(0.0, rawAc - limitedAc);
    }

    final loadKwh = config.loadProfile.energyKwhForStep(hourOfDay: hourOfDay, timeStep: config.timeStep);
    var selfConsumptionKwh = math.min(pvAcKwh, loadKwh);
    var surplusKwh = math.max(0.0, pvAcKwh - loadKwh);
    var remainingLoadKwh = math.max(0.0, loadKwh - pvAcKwh);
    var batteryChargeKwh = 0.0;
    var batteryDischargeKwh = 0.0;
    final perBatteryCharge = List<double>.filled(config.batteries.length, 0.0);
    final perBatteryDischarge = List<double>.filled(config.batteries.length, 0.0);

    for (var i = 0; i < config.batteries.length; i++) {
      if (surplusKwh <= 0) break;
      final battery = config.batteries[i];
      if (battery.capacityKwh <= 0 || battery.maxChargeKw <= 0) continue;
      final capacityLeft = math.max(0.0, battery.capacityKwh - socs[i]);
      final maxInput = math.min(surplusKwh, battery.maxChargeKw * stepHours);
      final input = math.min(maxInput, capacityLeft / battery.chargeEfficiency);
      if (input <= 0) continue;
      socs[i] += input * battery.chargeEfficiency;
      perBatteryCharge[i] = input;
      batteryChargeKwh += input;
      surplusKwh -= input;
    }

    for (var i = 0; i < config.batteries.length; i++) {
      if (remainingLoadKwh <= 0) break;
      final battery = config.batteries[i];
      if (battery.capacityKwh <= 0 || battery.maxDischargeKw <= 0) continue;
      final usableSoc = math.max(0.0, socs[i] - battery.minSocKwh);
      final maxOutput = math.min(remainingLoadKwh, battery.maxDischargeKw * stepHours);
      final output = math.min(maxOutput, usableSoc * battery.dischargeEfficiency);
      if (output <= 0) continue;
      socs[i] -= output / battery.dischargeEfficiency;
      perBatteryDischarge[i] = output;
      batteryDischargeKwh += output;
      selfConsumptionKwh += output;
      remainingLoadKwh -= output;
    }

    for (var i = 0; i < config.batteries.length; i++) {
      socs[i] = socs[i].clamp(config.batteries[i].minSocKwh, config.batteries[i].capacityKwh).toDouble();
    }

    var gridExportKwh = surplusKwh;
    final exportLimitKw = config.gridExportLimitKw;
    if (exportLimitKw != null) {
      final maxExport = exportLimitKw * stepHours;
      if (gridExportKwh > maxExport) {
        curtailedKwh += gridExportKwh - maxExport;
        gridExportKwh = maxExport;
      }
    }

    final aggregateSoc = socs.fold<double>(0.0, (a, b) => a + b);

    return SimulationStep(
      dayIndex: dayIndex,
      dayOfYear: dayOfYear,
      stepOfDay: stepOfDay,
      hourOfDay: hourOfDay,
      pvDcKwh: pvDcKwh,
      pvAcKwh: pvAcKwh,
      loadKwh: loadKwh,
      selfConsumptionKwh: selfConsumptionKwh,
      batteryChargeKwh: batteryChargeKwh,
      batteryDischargeKwh: batteryDischargeKwh,
      batterySocKwh: aggregateSoc,
      batteryChargesKwh: List<double>.unmodifiable(perBatteryCharge),
      batteryDischargesKwh: List<double>.unmodifiable(perBatteryDischarge),
      batterySocsKwh: List<double>.unmodifiable(socs),
      gridImportKwh: remainingLoadKwh,
      gridExportKwh: gridExportKwh,
      curtailedKwh: curtailedKwh,
    );
  }

  double _dcPowerKw(PvArray array, int dayOfYear, double hourOfDay, double latitudeDeg) {
    final latitudeImpact = (latitudeDeg.abs() / 90.0).clamp(0.0, 1.0).toDouble();
    final dayLength = (12.0 + 4.0 * latitudeImpact * math.cos(2 * math.pi * (dayOfYear - 172) / 365.0)).clamp(7.0, 17.0).toDouble();
    final sunrise = 12.0 - dayLength / 2.0;
    final sunset = 12.0 + dayLength / 2.0;
    if (hourOfDay < sunrise || hourOfDay > sunset) return 0;
    final sun = math.sin(math.pi * (hourOfDay - sunrise) / dayLength).clamp(0.0, 1.0).toDouble();
    final season = (0.72 + 0.28 * math.cos(2 * math.pi * (dayOfYear - 172) / 365.0)).clamp(0.25, 1.0).toDouble();
    final azimuthPenalty = ((array.azimuthDeg - 180).abs() / 180.0).clamp(0.0, 1.0).toDouble();
    final tiltPenalty = ((array.tiltDeg - 35).abs() / 90.0).clamp(0.0, 1.0).toDouble();
    final orientation = (1.0 - 0.22 * azimuthPenalty - 0.12 * tiltPenalty).clamp(0.55, 1.0).toDouble();
    final retained = (1 - array.lossFactor) * (1 - array.shadingFactor);
    return array.peakKw * sun * season * orientation * retained;
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
      curtailedKwh: sum((s) => s.curtailedKwh),
      finalBatterySocKwh: finalSocs.fold<double>(0.0, (a, b) => a + b),
      finalBatterySocsKwh: List<double>.unmodifiable(finalSocs),
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
