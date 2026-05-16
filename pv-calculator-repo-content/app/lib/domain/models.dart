import 'dart:math' as math;

enum InverterRole { grid, micro800, batteryOutput }

class PvArray {
  const PvArray({
    required this.name,
    required this.peakKw,
    required this.tiltDeg,
    required this.azimuthDeg,
    required this.lossPercent,
    required this.inverterId,
  });

  final String name;
  final double peakKw;
  final double tiltDeg;
  final double azimuthDeg;
  final double lossPercent;
  final String inverterId;

  double orientationFactor() {
    final azimuthPenalty = math.cos((azimuthDeg.abs() / 180) * math.pi / 2);
    final tiltPenalty = 1 - math.min((tiltDeg - 35).abs(), 60) / 180;
    return (azimuthPenalty * tiltPenalty).clamp(0.25, 1.05).toDouble();
  }
}

class Inverter {
  const Inverter({
    required this.id,
    required this.role,
    required this.acLimitKw,
  });

  final String id;
  final InverterRole role;
  final double acLimitKw;
}

class Battery {
  const Battery({
    required this.capacityKwh,
    required this.initialSocKwh,
    required this.minSocKwh,
    required this.maxChargeKw,
    required this.maxDischargeKw,
    required this.roundTripEfficiency,
  });

  final double capacityKwh;
  final double initialSocKwh;
  final double minSocKwh;
  final double maxChargeKw;
  final double maxDischargeKw;
  final double roundTripEfficiency;
}

class LoadProfile {
  const LoadProfile(this.hourlyKwh);

  final List<double> hourlyKwh;

  double valueForHour(int hour) => hourlyKwh[hour % hourlyKwh.length];
}

class SimulationConfig {
  const SimulationConfig({
    required this.projectName,
    required this.days,
    required this.usePreRunYear,
    required this.arrays,
    required this.inverters,
    required this.battery,
    required this.loadProfile,
  });

  final String projectName;
  final int days;
  final bool usePreRunYear;
  final List<PvArray> arrays;
  final List<Inverter> inverters;
  final Battery? battery;
  final LoadProfile loadProfile;
}

class SimulationStep {
  const SimulationStep({
    required this.day,
    required this.month,
    required this.hour,
    required this.rawPvKwh,
    required this.acPvKwh,
    required this.loadKwh,
    required this.directUseKwh,
    required this.batteryChargeKwh,
    required this.batteryDischargeKwh,
    required this.gridImportKwh,
    required this.feedInKwh,
    required this.curtailedKwh,
    required this.socKwh,
  });

  final int day;
  final int month;
  final int hour;
  final double rawPvKwh;
  final double acPvKwh;
  final double loadKwh;
  final double directUseKwh;
  final double batteryChargeKwh;
  final double batteryDischargeKwh;
  final double gridImportKwh;
  final double feedInKwh;
  final double curtailedKwh;
  final double socKwh;
}

class SimulationSummary {
  const SimulationSummary({
    required this.rawPvKwh,
    required this.acPvKwh,
    required this.loadKwh,
    required this.directUseKwh,
    required this.batteryChargeKwh,
    required this.batteryDischargeKwh,
    required this.gridImportKwh,
    required this.feedInKwh,
    required this.curtailedKwh,
    required this.finalSocKwh,
  });

  final double rawPvKwh;
  final double acPvKwh;
  final double loadKwh;
  final double directUseKwh;
  final double batteryChargeKwh;
  final double batteryDischargeKwh;
  final double gridImportKwh;
  final double feedInKwh;
  final double curtailedKwh;
  final double finalSocKwh;

  double get selfConsumptionPercent {
    if (acPvKwh == 0) return 0;
    return ((directUseKwh + batteryDischargeKwh) / acPvKwh) * 100;
  }

  double get autarkyPercent {
    if (loadKwh == 0) return 0;
    return (1 - gridImportKwh / loadKwh) * 100;
  }
}

class SimulationResult {
  const SimulationResult({required this.steps, required this.summary});

  final List<SimulationStep> steps;
  final SimulationSummary summary;
}
