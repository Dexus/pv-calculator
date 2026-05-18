/// Electricity tariff model used by the engine to compute cashflow
/// KPIs alongside the energy summary.
///
/// `importPricePerKwh` and `exportPricePerKwh` are flat fall-back prices
/// (€/kWh, sign-positive for both — import costs, export earns).
/// [hourlyImportPrices] / [hourlyExportPrices] are optional 24-slot
/// time-of-use schedules; when non-null, slot `h ∈ [0, 23]` overrides
/// the flat price for any simulation step whose hourOfDay falls in
/// `[h, h+1)`. Quarter-hourly steps inside the same hour share the
/// same slot — the schedule is intentionally hourly-quantised so the
/// engine doesn't have to interpolate price boundaries.
///
/// The engine accepts the TOU arrays unconditionally; any Pro/Free
/// gating lives in the calling UI (see Flutter `kProFeatures`).
class TariffConfig {
  const TariffConfig({
    required this.importPricePerKwh,
    required this.exportPricePerKwh,
    this.hourlyImportPrices,
    this.hourlyExportPrices,
  });

  final double importPricePerKwh;
  final double exportPricePerKwh;
  final List<double>? hourlyImportPrices;
  final List<double>? hourlyExportPrices;

  /// Price paid for one kWh imported during a step whose midpoint is
  /// at `hourOfDay`. Falls back to [importPricePerKwh] when no TOU
  /// schedule is configured.
  double importPriceAtHour(double hourOfDay) {
    final hours = hourlyImportPrices;
    if (hours == null) return importPricePerKwh;
    return hours[hourOfDay.floor().clamp(0, 23)];
  }

  /// Price earned for one kWh exported during a step whose midpoint is
  /// at `hourOfDay`. Falls back to [exportPricePerKwh].
  double exportPriceAtHour(double hourOfDay) {
    final hours = hourlyExportPrices;
    if (hours == null) return exportPricePerKwh;
    return hours[hourOfDay.floor().clamp(0, 23)];
  }

  void validate() {
    // `value < 0` is *not* enough — `NaN < 0` is false in Dart, so a NaN
    // price would otherwise slip through and propagate as NaN through
    // every cost accumulator. Reject anything that isn't a finite,
    // non-negative double.
    if (!importPricePerKwh.isFinite || importPricePerKwh < 0) {
      throw ArgumentError('Tariff importPricePerKwh must be finite and >= 0.');
    }
    if (!exportPricePerKwh.isFinite || exportPricePerKwh < 0) {
      throw ArgumentError('Tariff exportPricePerKwh must be finite and >= 0.');
    }
    final imp = hourlyImportPrices;
    if (imp != null) {
      if (imp.length != 24) {
        throw ArgumentError(
            'Tariff hourlyImportPrices must have 24 entries, got ${imp.length}.');
      }
      for (final p in imp) {
        if (!p.isFinite || p < 0) {
          throw ArgumentError(
              'Tariff hourlyImportPrices entries must be finite and >= 0.');
        }
      }
    }
    final exp = hourlyExportPrices;
    if (exp != null) {
      if (exp.length != 24) {
        throw ArgumentError(
            'Tariff hourlyExportPrices must have 24 entries, got ${exp.length}.');
      }
      for (final p in exp) {
        if (!p.isFinite || p < 0) {
          throw ArgumentError(
              'Tariff hourlyExportPrices entries must be finite and >= 0.');
        }
      }
    }
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'importPricePerKwh': importPricePerKwh,
      'exportPricePerKwh': exportPricePerKwh,
    };
    if (hourlyImportPrices != null) {
      json['hourlyImportPrices'] = hourlyImportPrices;
    }
    if (hourlyExportPrices != null) {
      json['hourlyExportPrices'] = hourlyExportPrices;
    }
    return json;
  }

  static TariffConfig fromJson(Map<String, dynamic> json) {
    List<double>? readList(Object? raw) {
      if (raw == null) return null;
      return (raw as List)
          .map((e) => (e as num).toDouble())
          .toList(growable: false);
    }

    return TariffConfig(
      importPricePerKwh: (json['importPricePerKwh'] as num).toDouble(),
      exportPricePerKwh: (json['exportPricePerKwh'] as num).toDouble(),
      hourlyImportPrices: readList(json['hourlyImportPrices']),
      hourlyExportPrices: readList(json['hourlyExportPrices']),
    );
  }
}
