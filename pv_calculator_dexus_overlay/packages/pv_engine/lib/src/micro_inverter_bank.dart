/// 24-hour schedule for a [MicroInverterBank]. Returns a target factor
/// in [0, 1] for the given hour-of-day. The bank's effective AC target
/// for that step is `count * unitRatedPowerW / 1000 * factor`.
///
/// Schedules are pure value objects: same hour always returns the same
/// factor. They have no engine state and can be shared across banks.
abstract class BankSchedule {
  const BankSchedule();

  /// `hourOfDay` is in `[0, 24)`. Implementations must be total.
  double factorAt(double hourOfDay);

  void validate();

  Map<String, dynamic> toJson();

  static BankSchedule fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String?;
    switch (kind) {
      case 'alwaysOn':
        return const AlwaysOnSchedule();
      case 'hourly':
        final factors = (json['factors'] as List).map((e) => (e as num).toDouble()).toList(growable: false);
        return HourlySchedule(factors);
      case 'timeWindows':
        final raw = (json['windows'] as List).cast<Map>();
        final windows = raw.map((m) => TimeWindow(
              startHour: (m['startHour'] as num).toDouble(),
              endHour: (m['endHour'] as num).toDouble(),
              factor: (m['factor'] as num?)?.toDouble() ?? 1.0,
            )).toList(growable: false);
        return TimeWindowSchedule(windows);
      default:
        throw ArgumentError('Unknown BankSchedule kind: $kind');
    }
  }
}

/// Delivers `factor = 1.0` at every hour. Used by `ConstantFeed24h`-style
/// banks that should run continuously whenever SOC permits.
class AlwaysOnSchedule extends BankSchedule {
  const AlwaysOnSchedule();

  @override
  double factorAt(double hourOfDay) => 1.0;

  @override
  void validate() {}

  @override
  Map<String, dynamic> toJson() => {'kind': 'alwaysOn'};
}

/// Per-hour factor list, 24 entries. Each entry is the factor for the
/// hour starting at that index (so `factors[18]` covers 18:00–19:00).
class HourlySchedule extends BankSchedule {
  const HourlySchedule(this.factors);

  final List<double> factors;

  @override
  double factorAt(double hourOfDay) {
    final h = hourOfDay.floor().clamp(0, 23).toInt();
    return factors[h];
  }

  @override
  void validate() {
    if (factors.length != 24) {
      throw ArgumentError('HourlySchedule factors must have 24 entries, got ${factors.length}.');
    }
    for (final f in factors) {
      if (f < 0 || f > 1) {
        throw ArgumentError('HourlySchedule factor $f must be in [0, 1].');
      }
    }
  }

  @override
  Map<String, dynamic> toJson() => {'kind': 'hourly', 'factors': factors};
}

/// A start..end window in hours-of-day. `startHour` and `endHour` are in
/// `[0, 24]`. If `startHour > endHour`, the window wraps midnight
/// (e.g. 22:00–06:00).
class TimeWindow {
  const TimeWindow({required this.startHour, required this.endHour, this.factor = 1.0});

  final double startHour;
  final double endHour;
  final double factor;

  bool contains(double hourOfDay) {
    if (startHour <= endHour) {
      return hourOfDay >= startHour && hourOfDay < endHour;
    }
    // Wraps midnight.
    return hourOfDay >= startHour || hourOfDay < endHour;
  }
}

/// Delivers `factor` inside each window and `0` outside. Multiple
/// windows are OR-combined; the first matching window wins.
class TimeWindowSchedule extends BankSchedule {
  const TimeWindowSchedule(this.windows);

  final List<TimeWindow> windows;

  @override
  double factorAt(double hourOfDay) {
    for (final w in windows) {
      if (w.contains(hourOfDay)) return w.factor;
    }
    return 0.0;
  }

  @override
  void validate() {
    for (final w in windows) {
      if (w.startHour < 0 || w.startHour > 24) {
        throw ArgumentError('TimeWindow startHour ${w.startHour} must be in [0, 24].');
      }
      if (w.endHour < 0 || w.endHour > 24) {
        throw ArgumentError('TimeWindow endHour ${w.endHour} must be in [0, 24].');
      }
      if (w.factor < 0 || w.factor > 1) {
        throw ArgumentError('TimeWindow factor ${w.factor} must be in [0, 1].');
      }
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'timeWindows',
        'windows': windows.map((w) => {
              'startHour': w.startHour,
              'endHour': w.endHour,
              'factor': w.factor,
            }).toList(),
      };
}

/// A battery-coupled AC output that pulls DC from a battery and converts
/// it to AC according to a schedule. Models the "800-W class" use case
/// from the architecture doc §5.3: continuous or time-windowed AC
/// delivery from a stationary battery via a dedicated micro-inverter.
///
/// `count * unitRatedPowerW * scheduleFactor(t)` is the **target** AC
/// power per step. The actual delivery is capped by:
///   1. battery `maxDischargeKw` and remaining usable SOC,
///   2. `inverterEfficiency` (losses on the bank-internal conversion),
///   3. `minSocShutdown`: if the source battery's SOC fraction drops
///      below this, the bank delivers 0 W for that step.
/// The gap between target and delivery is reported as **shortfall**.
class MicroInverterBank {
  const MicroInverterBank({
    required this.id,
    required this.batteryId,
    this.label = '',
    this.count = 1,
    this.unitRatedPowerW = 800.0,
    this.minSocShutdown = 0.0,
    this.inverterEfficiency = 0.95,
    this.schedule = const AlwaysOnSchedule(),
  });

  final String id;

  /// Label for UI display. Defaults to empty.
  final String label;

  /// Source battery id. Must match one of the `SimulationConfig.batteries`
  /// entries. The bank drains this battery; multiple banks may share one
  /// battery and are then served in declared order.
  final String batteryId;

  /// Number of identical micro-inverter units in the bank.
  final int count;

  /// Per-unit AC rated power in watts. Defaults to 800 W (the
  /// regulatory "Steckersolar" cap in DE/AT/FR; treat the value as a
  /// per-device assumption, not a country profile).
  final double unitRatedPowerW;

  /// SOC fraction below which the bank refuses to deliver. Compared
  /// against `batteryState.energy / battery.capacityKwh`, not against
  /// usable capacity. `0.0` = never shut down, `1.0` = always shut
  /// down. Default 0.0 keeps legacy behaviour when banks are absent.
  final double minSocShutdown;

  /// DC→AC efficiency of the bank itself, applied to the energy drawn
  /// from the battery before AC delivery.
  final double inverterEfficiency;

  /// 24-hour AC delivery schedule.
  final BankSchedule schedule;

  /// Aggregate AC target in **kW** for the given hour-of-day (no SOC or
  /// rate caps applied yet — those happen in [EnergyRouter]).
  double targetKwAt(double hourOfDay) =>
      count * unitRatedPowerW * schedule.factorAt(hourOfDay) / 1000.0;

  void validate() {
    if (id.trim().isEmpty) {
      throw ArgumentError('MicroInverterBank id must not be empty.');
    }
    if (batteryId.trim().isEmpty) {
      throw ArgumentError('MicroInverterBank $id batteryId must not be empty.');
    }
    if (count < 0) {
      throw ArgumentError('MicroInverterBank $id count must not be negative.');
    }
    if (unitRatedPowerW <= 0) {
      throw ArgumentError('MicroInverterBank $id unitRatedPowerW must be positive.');
    }
    if (minSocShutdown < 0 || minSocShutdown > 1) {
      throw ArgumentError('MicroInverterBank $id minSocShutdown must be in [0, 1].');
    }
    if (inverterEfficiency <= 0 || inverterEfficiency > 1) {
      throw ArgumentError('MicroInverterBank $id inverterEfficiency must be in (0, 1].');
    }
    schedule.validate();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'batteryId': batteryId,
        'count': count,
        'unitRatedPowerW': unitRatedPowerW,
        'minSocShutdown': minSocShutdown,
        'inverterEfficiency': inverterEfficiency,
        'schedule': schedule.toJson(),
      };

  static MicroInverterBank fromJson(Map<String, dynamic> json) => MicroInverterBank(
        id: (json['id'] as String).trim(),
        label: json['label'] as String? ?? '',
        batteryId: (json['batteryId'] as String).trim(),
        count: (json['count'] as num?)?.toInt() ?? 1,
        unitRatedPowerW: (json['unitRatedPowerW'] as num?)?.toDouble() ?? 800.0,
        minSocShutdown: (json['minSocShutdown'] as num?)?.toDouble() ?? 0.0,
        inverterEfficiency: (json['inverterEfficiency'] as num?)?.toDouble() ?? 0.95,
        schedule: json['schedule'] is Map
            ? BankSchedule.fromJson((json['schedule'] as Map).cast<String, dynamic>())
            : const AlwaysOnSchedule(),
      );
}
