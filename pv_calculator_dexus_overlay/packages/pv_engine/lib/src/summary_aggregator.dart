part of '../pv_engine.dart';

/// Per-bank coverage report over the full reporting horizon.
///
/// Targets are reconstructed as `delivered + shortfall` so the same
/// step series used for the KPIs is the single source of truth — no
/// schedule re-evaluation, which would drift if the bank/schedule were
/// mutated between simulator runs.
class BankRuntimeStats {
  const BankRuntimeStats({
    required this.bankIndex,
    required this.targetKwh,
    required this.deliveredKwh,
    required this.shortfallKwh,
    required this.activeHours,
    required this.scheduledHours,
    required this.fullDeliveryHours,
  });

  /// Index into `SimulationConfig.microInverterBanks`.
  final int bankIndex;

  /// AC kWh the bank was *asked* to deliver (delivered + shortfall).
  final double targetKwh;

  /// AC kWh the bank actually delivered.
  final double deliveredKwh;

  /// AC kWh the bank failed to deliver (SOC shutdown, rate cap, empty
  /// source battery).
  final double shortfallKwh;

  /// Hours during which the bank delivered any positive AC energy.
  /// Useful as a "is the output sustained?" indicator distinct from the
  /// schedule itself.
  final double activeHours;

  /// Hours during which the schedule asked for any positive AC
  /// (`target > 0`). `scheduledHours − activeHours` is the time the
  /// bank was scheduled to feed but couldn't.
  final double scheduledHours;

  /// Hours during which delivery met the requested target within 0.1 %
  /// of the target (so floating-point drift doesn't disqualify steps).
  final double fullDeliveryHours;

  /// Fraction of the target that was actually delivered. `0..1`. Equal
  /// to `1` when the bank had no schedule (target = 0) — there was
  /// nothing to miss.
  double get coverageRate => targetKwh <= 0 ? 1.0 : deliveredKwh / targetKwh;
}

/// One day's worth of per-bank delivery + shortfall + active hours.
/// Used by the Flutter "runtime chart" to plot how long a 24h output
/// can be sustained across the year.
class BankDayStats {
  const BankDayStats({
    required this.dayOfYear,
    required this.targetKwh,
    required this.deliveredKwh,
    required this.shortfallKwh,
    required this.activeHours,
    required this.scheduledHours,
    required this.fullDeliveryHours,
  });

  final int dayOfYear;
  final double targetKwh;
  final double deliveredKwh;
  final double shortfallKwh;

  /// Hours during which the bank delivered any positive AC. Includes
  /// partial-delivery steps where the bank fell short of its target;
  /// chart code that wants a "fully sustained" segment should use
  /// [fullDeliveryHours] instead so partial steps don't masquerade as
  /// 100 % coverage.
  final double activeHours;

  /// Hours the schedule asked for any positive AC (`target > 0`).
  final double scheduledHours;

  /// Hours during which delivery met the target within 0.1 % — same
  /// tolerance as `BankRuntimeStats.fullDeliveryHours`. Visualisations
  /// that stack "satisfied vs. shortfall" should split on this value
  /// rather than `activeHours`: a partially-served step counts as
  /// shortfall time here even though `activeHours` would include it.
  final double fullDeliveryHours;
}

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
    if (steps is _StepListView) {
      return _monthlyFromBuffer(steps._buffer);
    }
    return _monthlyFromList(steps);
  }

  static List<MonthlyBucket> _monthlyFromBuffer(_StepBuffer buf) {
    final pv = Float64List(12);
    final load = Float64List(12);
    final self = Float64List(12);
    final charge = Float64List(12);
    final discharge = Float64List(12);
    final import = Float64List(12);
    final export = Float64List(12);
    final curtailedDc = Float64List(12);
    final curtailedAc = Float64List(12);
    final curtailedExport = Float64List(12);

    for (var i = 0; i < buf.length; i++) {
      final m = monthOfDayOfYear(buf.dayOfYear[i]) - 1;
      pv[m] += buf.pvAcKwh[i];
      load[m] += buf.loadKwh[i];
      self[m] += buf.selfConsumptionKwh[i];
      charge[m] += buf.batteryChargeKwh[i];
      discharge[m] += buf.batteryDischargeKwh[i];
      import[m] += buf.gridImportKwh[i];
      export[m] += buf.gridExportKwh[i];
      curtailedDc[m] += buf.curtailedDcKwh[i];
      curtailedAc[m] += buf.curtailedAcKwh[i];
      curtailedExport[m] += buf.curtailedExportKwh[i];
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

  static List<MonthlyBucket> _monthlyFromList(List<SimulationStep> steps) {
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

  /// Per-bank coverage report for `bankCount` banks. `bankCount` is
  /// passed in (rather than inferred) so callers can pass the value
  /// from `SimulationConfig.microInverterBanks.length` even when the
  /// reported steps would be empty (e.g. days=0). Returns an empty list
  /// when `bankCount` is `0`.
  static List<BankRuntimeStats> bankRuntime(
    List<SimulationStep> steps, {
    required int bankCount,
    required TimeStep timeStep,
  }) {
    if (bankCount == 0) return const <BankRuntimeStats>[];
    if (steps is _StepListView) {
      return _bankRuntimeFromBuffer(steps._buffer,
          bankCount: bankCount, timeStep: timeStep);
    }
    return _bankRuntimeFromList(steps,
        bankCount: bankCount, timeStep: timeStep);
  }

  static List<BankRuntimeStats> _bankRuntimeFromBuffer(
    _StepBuffer buf, {
    required int bankCount,
    required TimeStep timeStep,
  }) {
    final delivered = Float64List(bankCount);
    final shortfall = Float64List(bankCount);
    final activeHours = Float64List(bankCount);
    final scheduledHours = Float64List(bankCount);
    final fullDeliveryHours = Float64List(bankCount);
    final stepHours = timeStep.hours;
    // Buffer column may be wider than the requested bankCount when the
    // simulator was configured with extra banks; clamp once so the inner
    // loop bound is the lesser of the two.
    final innerCount =
        buf.bankCount < bankCount ? buf.bankCount : bankCount;

    for (var s = 0; s < buf.length; s++) {
      final base = s * buf.bankCount;
      for (var i = 0; i < innerCount; i++) {
        final d = buf.bankDeliveries[base + i];
        final sh = buf.bankShortfalls[base + i];
        final target = d + sh;
        delivered[i] += d;
        shortfall[i] += sh;
        if (d > 0) activeHours[i] += stepHours;
        if (target > 0) {
          scheduledHours[i] += stepHours;
          if (d >= target * 0.999) fullDeliveryHours[i] += stepHours;
        }
      }
    }

    return List<BankRuntimeStats>.generate(
      bankCount,
      (i) => BankRuntimeStats(
        bankIndex: i,
        targetKwh: delivered[i] + shortfall[i],
        deliveredKwh: delivered[i],
        shortfallKwh: shortfall[i],
        activeHours: activeHours[i],
        scheduledHours: scheduledHours[i],
        fullDeliveryHours: fullDeliveryHours[i],
      ),
    );
  }

  static List<BankRuntimeStats> _bankRuntimeFromList(
    List<SimulationStep> steps, {
    required int bankCount,
    required TimeStep timeStep,
  }) {
    final delivered = List<double>.filled(bankCount, 0.0);
    final shortfall = List<double>.filled(bankCount, 0.0);
    final activeHours = List<double>.filled(bankCount, 0.0);
    final scheduledHours = List<double>.filled(bankCount, 0.0);
    final fullDeliveryHours = List<double>.filled(bankCount, 0.0);
    final stepHours = timeStep.hours;

    for (final step in steps) {
      for (var i = 0; i < bankCount; i++) {
        final d = i < step.microInverterDeliveriesKwh.length
            ? step.microInverterDeliveriesKwh[i]
            : 0.0;
        final s = i < step.microInverterShortfallsKwh.length
            ? step.microInverterShortfallsKwh[i]
            : 0.0;
        final target = d + s;
        delivered[i] += d;
        shortfall[i] += s;
        if (d > 0) activeHours[i] += stepHours;
        if (target > 0) {
          scheduledHours[i] += stepHours;
          // 0.1 % tolerance — bank-internal eta and battery rate caps
          // can shave delivered by less than that without it being a
          // meaningful shortfall.
          if (d >= target * 0.999) fullDeliveryHours[i] += stepHours;
        }
      }
    }

    return List<BankRuntimeStats>.generate(
      bankCount,
      (i) => BankRuntimeStats(
        bankIndex: i,
        targetKwh: delivered[i] + shortfall[i],
        deliveredKwh: delivered[i],
        shortfallKwh: shortfall[i],
        activeHours: activeHours[i],
        scheduledHours: scheduledHours[i],
        fullDeliveryHours: fullDeliveryHours[i],
      ),
    );
  }

  /// Per-day breakdown for a single bank. Returns a 365-entry list
  /// (one per `dayOfYear` 1..365). Days with no steps for the requested
  /// bank are returned as zeroes. Drives the Flutter runtime/coverage
  /// chart on the Auswertung tab.
  static List<BankDayStats> bankDaily(
    List<SimulationStep> steps, {
    required int bankIndex,
    required TimeStep timeStep,
  }) {
    if (steps is _StepListView) {
      return _bankDailyFromBuffer(steps._buffer,
          bankIndex: bankIndex, timeStep: timeStep);
    }
    return _bankDailyFromList(steps,
        bankIndex: bankIndex, timeStep: timeStep);
  }

  static List<BankDayStats> _bankDailyFromBuffer(
    _StepBuffer buf, {
    required int bankIndex,
    required TimeStep timeStep,
  }) {
    final delivered = Float64List(365);
    final shortfall = Float64List(365);
    final active = Float64List(365);
    final scheduled = Float64List(365);
    final full = Float64List(365);
    final stepHours = timeStep.hours;
    final bankInRange = bankIndex < buf.bankCount;
    final bw = buf.bankCount;

    for (var s = 0; s < buf.length; s++) {
      final d = bankInRange ? buf.bankDeliveries[s * bw + bankIndex] : 0.0;
      final sh = bankInRange ? buf.bankShortfalls[s * bw + bankIndex] : 0.0;
      final dayIdx = (buf.dayOfYear[s] - 1).clamp(0, 364).toInt();
      final target = d + sh;
      delivered[dayIdx] += d;
      shortfall[dayIdx] += sh;
      if (d > 0) active[dayIdx] += stepHours;
      if (target > 0) {
        scheduled[dayIdx] += stepHours;
        if (d >= target * 0.999) full[dayIdx] += stepHours;
      }
    }

    return List<BankDayStats>.generate(
      365,
      (i) => BankDayStats(
        dayOfYear: i + 1,
        targetKwh: delivered[i] + shortfall[i],
        deliveredKwh: delivered[i],
        shortfallKwh: shortfall[i],
        activeHours: active[i],
        scheduledHours: scheduled[i],
        fullDeliveryHours: full[i],
      ),
    );
  }

  static List<BankDayStats> _bankDailyFromList(
    List<SimulationStep> steps, {
    required int bankIndex,
    required TimeStep timeStep,
  }) {
    final delivered = List<double>.filled(365, 0.0);
    final shortfall = List<double>.filled(365, 0.0);
    final active = List<double>.filled(365, 0.0);
    final scheduled = List<double>.filled(365, 0.0);
    final full = List<double>.filled(365, 0.0);
    final stepHours = timeStep.hours;

    for (final step in steps) {
      final d = bankIndex < step.microInverterDeliveriesKwh.length
          ? step.microInverterDeliveriesKwh[bankIndex]
          : 0.0;
      final s = bankIndex < step.microInverterShortfallsKwh.length
          ? step.microInverterShortfallsKwh[bankIndex]
          : 0.0;
      // `num.clamp` is statically `num`; we index a `List<double>`
      // immediately below, so make the int-ness explicit.
      final dayIdx = (step.dayOfYear - 1).clamp(0, 364).toInt();
      final target = d + s;
      delivered[dayIdx] += d;
      shortfall[dayIdx] += s;
      if (d > 0) active[dayIdx] += stepHours;
      if (target > 0) {
        scheduled[dayIdx] += stepHours;
        if (d >= target * 0.999) full[dayIdx] += stepHours;
      }
    }

    return List<BankDayStats>.generate(
      365,
      (i) => BankDayStats(
        dayOfYear: i + 1,
        targetKwh: delivered[i] + shortfall[i],
        deliveredKwh: delivered[i],
        shortfallKwh: shortfall[i],
        activeHours: active[i],
        scheduledHours: scheduled[i],
        fullDeliveryHours: full[i],
      ),
    );
  }
}
