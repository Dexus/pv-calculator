import '../pv_engine.dart';

class MonthlyBucket {
  const MonthlyBucket({
    required this.month,
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
  });

  final int month;
  final double pvAcKwh;
  final double loadKwh;
  final double selfConsumptionKwh;
  final double batteryChargeKwh;
  final double batteryDischargeKwh;
  final double gridImportKwh;
  final double gridExportKwh;

  /// DC-side MPPT curtailment in **DC kWh**.
  final double curtailedDcKwh;

  /// AC-side inverter-cap curtailment in **AC kWh**.
  final double curtailedAcKwh;

  /// AC-side grid-export-limit curtailment in **AC kWh**.
  final double curtailedExportKwh;
}

class SummaryAggregator {
  const SummaryAggregator();

  // Fixed 365-day calendar — matches the engine's _wrapDay which clamps to
  // [1, 365] and does not model leap years. Update this table if the engine
  // ever grows leap-day support.
  static const _daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  static int monthOfDayOfYear(int dayOfYear) {
    var remaining = dayOfYear;
    for (var month = 0; month < 12; month++) {
      remaining -= _daysInMonth[month];
      if (remaining <= 0) return month + 1;
    }
    return 12;
  }

  static List<MonthlyBucket> monthly(List<SimulationStep> steps) {
    final pv = List<double>.filled(12, 0);
    final load = List<double>.filled(12, 0);
    final self = List<double>.filled(12, 0);
    final charge = List<double>.filled(12, 0);
    final discharge = List<double>.filled(12, 0);
    final import = List<double>.filled(12, 0);
    final export = List<double>.filled(12, 0);
    final curtailedDc = List<double>.filled(12, 0);
    final curtailedAc = List<double>.filled(12, 0);
    final curtailedExport = List<double>.filled(12, 0);

    for (final step in steps) {
      final m = monthOfDayOfYear(step.dayOfYear) - 1;
      pv[m] += step.pvAcKwh;
      load[m] += step.loadKwh;
      self[m] += step.selfConsumptionKwh;
      charge[m] += step.batteryChargeKwh;
      discharge[m] += step.batteryDischargeKwh;
      import[m] += step.gridImportKwh;
      export[m] += step.gridExportKwh;
      curtailedDc[m] += step.curtailedDcKwh;
      curtailedAc[m] += step.curtailedAcKwh;
      curtailedExport[m] += step.curtailedExportKwh;
    }

    return List<MonthlyBucket>.generate(
      12,
      (i) => MonthlyBucket(
        month: i + 1,
        pvAcKwh: pv[i],
        loadKwh: load[i],
        selfConsumptionKwh: self[i],
        batteryChargeKwh: charge[i],
        batteryDischargeKwh: discharge[i],
        gridImportKwh: import[i],
        gridExportKwh: export[i],
        curtailedDcKwh: curtailedDc[i],
        curtailedAcKwh: curtailedAc[i],
        curtailedExportKwh: curtailedExport[i],
      ),
    );
  }
}
