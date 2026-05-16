import 'dart:math' as math;

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
    _require(id.isNotEmpty, 'PV array id must not be empty.');
    _require(peakKw > 0, 'PV array $id peakKw must be positive.');
    _require(tiltDeg >= 0 && tiltDeg <= 90, 'PV array $id tiltDeg must be between 0 and 90.');
    _require(lossFactor >= 0 && lossFactor < 1, 'PV array $id lossFactor must be in [0, 1).');
    _require(shadingFactor >= 0 && shadingFactor < 1, 'PV array $id shadingFactor must be in [0, 1).');
  }
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
    _require(id.isNotEmpty, 'Inverter id must not be empty.');
    _require(maxAcKw > 0, 'Inverter $id maxAcKw must be positive.');
    _require(efficiency > 0 && efficiency <= 1, 'Inverter $id efficiency must be in (0, 1].');
  }
}

class BatteryConfig {
  const BatteryConfig({
    required this.capacityKwh,
    required this.maxChargeKw,
    required this.maxDischargeKw,
    this.roundTripEfficiency = 0.9,
    this.minSocKwh = 0,
    this.initialSocKwh,
  });

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
    _require(capacityKwh >= 0, 'Battery capacityKwh must not be negative.');
    _require(maxChargeKw >= 0, 'Battery maxChargeKw must not be negative.');
    _require(maxDischargeKw >= 0, 'Battery maxDischargeKw must not be negative.');
    _require(roundTripEfficiency > 0 && roundTripEfficiency <= 1, 'Battery roundTripEfficiency must be in (0, 1].');
    _require(minSocKwh >= 0 && minSocKwh <= capacityKwh, 'Battery minSocKwh must be between 0 and capacityKwh.');
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
}

class SimulationConfig {
  const SimulationConfig({
    required this.arrays,
    required this.inverters,
    required this.loadProfile,
    this.battery,
    this.startDayOfYear = 1,
    this.days = 365,
    this.timeStep = TimeStep.hourly,
    this.preRunDays = 0,
    this.gridExportLimitKw,
    this.latitudeDeg = 50.0,
  });

  final List<PvArray> arrays;
  final List<Inverter> inverters;
  final BatteryConfig? battery;
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
    _require(days > 0, 'days must be positive.');
    _require(preRunDays >= 0, 'preRunDays must not be negative.');
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
    battery?.validate();
    loadProfile.validate();
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
    var soc = config.battery?.effectiveInitialSocKwh ?? 0.0;

    for (var dayIndex = -config.preRunDays; dayIndex < config.days; dayIndex++) {
      final dayOfYear = _wrapDay(config.startDayOfYear + dayIndex);
      for (var stepOfDay = 0; stepOfDay < config.timeStep.stepsPerDay; stepOfDay++) {
        final hourOfDay = (stepOfDay + 0.5) * config.timeStep.hours;
        final step = _simulateStep(config, soc, dayIndex, dayOfYear, stepOfDay, hourOfDay);
        soc = step.batterySocKwh;
        if (dayIndex >= 0) steps.add(step);
      }
    }
    return SimulationResult(steps: steps, summary: _summarize(steps));
  }

  SimulationStep _simulateStep(SimulationConfig config, double batterySoc, int dayIndex, int dayOfYear, int stepOfDay, double hourOfDay) {
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

    final battery = config.battery;
    if (battery != null && battery.capacityKwh > 0) {
      if (surplusKwh > 0 && battery.maxChargeKw > 0) {
        final capacityLeft = math.max(0.0, battery.capacityKwh - batterySoc);
        final maxInput = math.min(surplusKwh, battery.maxChargeKw * stepHours);
        final input = math.min(maxInput, capacityLeft / battery.chargeEfficiency);
        batterySoc += input * battery.chargeEfficiency;
        batteryChargeKwh = input;
        surplusKwh -= input;
      }
      if (remainingLoadKwh > 0 && battery.maxDischargeKw > 0) {
        final usableSoc = math.max(0.0, batterySoc - battery.minSocKwh);
        final maxOutput = math.min(remainingLoadKwh, battery.maxDischargeKw * stepHours);
        final output = math.min(maxOutput, usableSoc * battery.dischargeEfficiency);
        batterySoc -= output / battery.dischargeEfficiency;
        batteryDischargeKwh = output;
        selfConsumptionKwh += output;
        remainingLoadKwh -= output;
      }
      batterySoc = batterySoc.clamp(battery.minSocKwh, battery.capacityKwh).toDouble();
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
      batterySocKwh: batterySoc,
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

  SimulationSummary _summarize(List<SimulationStep> steps) {
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
      finalBatterySocKwh: steps.isEmpty ? 0 : steps.last.batterySocKwh,
    );
  }

  int _wrapDay(int day) {
    var normalized = day;
    while (normalized < 1) {
      normalized += 365;
    }
    while (normalized > 365) {
      normalized -= 365;
    }
    return normalized;
  }
}

void _require(bool condition, String message) {
  if (!condition) throw ArgumentError(message);
}
