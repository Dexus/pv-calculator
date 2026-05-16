import 'dart:math' as math;

import '../domain/models.dart';

class PvSimulationService {
  SimulationResult simulate(SimulationConfig config) {
    final inverters = {for (final inverter in config.inverters) inverter.id: inverter};
    final battery = config.battery;
    final roundTrip = battery == null ? 1.0 : math.sqrt(battery.roundTripEfficiency);
    final totalDays = (config.usePreRunYear ? config.days : 0) + config.days;
    final recordStartDay = config.usePreRunYear ? config.days : 0;
    final steps = <SimulationStep>[];

    var soc = battery == null
        ? 0.0
        : battery.initialSocKwh.clamp(battery.minSocKwh, battery.capacityKwh).toDouble();

    for (var day = 0; day < totalDays; day++) {
      final season = _seasonFactor((day % 365) + 1);
      for (var hour = 0; hour < 24; hour++) {
        final bucketByInverter = <String, double>{};
        var rawPv = 0.0;

        for (final array in config.arrays) {
          final production = array.peakKw *
              _sunFactor(hour) *
              season *
              array.orientationFactor() *
              (1 - array.lossPercent / 100);
          rawPv += production;
          bucketByInverter.update(
            array.inverterId,
            (value) => value + production,
            ifAbsent: () => production,
          );
        }

        var acPv = 0.0;
        var curtailed = 0.0;
        for (final entry in bucketByInverter.entries) {
          final limit = inverters[entry.key]?.acLimitKw ?? entry.value;
          acPv += math.min(entry.value, limit);
          curtailed += math.max(0, entry.value - limit);
        }

        final load = config.loadProfile.valueForHour(hour);
        final directUse = math.min(acPv, load);
        var remainingLoad = load - directUse;
        var surplus = acPv - directUse;
        var charge = 0.0;
        var discharge = 0.0;

        if (battery != null) {
          final freeCapacity = math.max(0, battery.capacityKwh - soc);
          charge = [surplus, battery.maxChargeKw, freeCapacity / roundTrip].reduce(math.min);
          soc += charge * roundTrip;
          surplus -= charge;

          final available = math.max(0, soc - battery.minSocKwh);
          discharge = [remainingLoad / roundTrip, battery.maxDischargeKw, available].reduce(math.min);
          soc -= discharge;
          remainingLoad -= discharge * roundTrip;
        }

        if (day >= recordStartDay) {
          final actualDay = day - recordStartDay;
          steps.add(SimulationStep(
            day: actualDay + 1,
            month: ((actualDay / config.days) * 12).floor() + 1,
            hour: hour,
            rawPvKwh: rawPv,
            acPvKwh: acPv,
            loadKwh: load,
            directUseKwh: directUse,
            batteryChargeKwh: charge,
            batteryDischargeKwh: discharge,
            gridImportKwh: math.max(0, remainingLoad),
            feedInKwh: math.max(0, surplus),
            curtailedKwh: curtailed,
            socKwh: soc,
          ));
        }
      }
    }

    return SimulationResult(steps: steps, summary: _summarize(steps, soc));
  }

  double _sunFactor(int hour) {
    final daylightCurve = math.sin(((hour - 6) / 12) * math.pi);
    return math.max(0, daylightCurve);
  }

  double _seasonFactor(int dayOfYear) {
    final angle = ((dayOfYear - 172) / 365) * math.pi * 2;
    return (0.58 + 0.42 * math.cos(angle)).clamp(0.18, 1.0).toDouble();
  }

  SimulationSummary _summarize(List<SimulationStep> steps, double finalSoc) {
    var rawPv = 0.0;
    var acPv = 0.0;
    var load = 0.0;
    var direct = 0.0;
    var charge = 0.0;
    var discharge = 0.0;
    var gridImport = 0.0;
    var feedIn = 0.0;
    var curtailed = 0.0;

    for (final step in steps) {
      rawPv += step.rawPvKwh;
      acPv += step.acPvKwh;
      load += step.loadKwh;
      direct += step.directUseKwh;
      charge += step.batteryChargeKwh;
      discharge += step.batteryDischargeKwh;
      gridImport += step.gridImportKwh;
      feedIn += step.feedInKwh;
      curtailed += step.curtailedKwh;
    }

    return SimulationSummary(
      rawPvKwh: rawPv,
      acPvKwh: acPv,
      loadKwh: load,
      directUseKwh: direct,
      batteryChargeKwh: charge,
      batteryDischargeKwh: discharge,
      gridImportKwh: gridImport,
      feedInKwh: feedIn,
      curtailedKwh: curtailed,
      finalSocKwh: finalSoc,
    );
  }
}
