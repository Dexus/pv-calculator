import '../pv_engine.dart';

const _lineEnding = '\r\n';

String stepsCsv(
  List<SimulationStep> steps, {
  int batteryCount = 0,
  int bankCount = 0,
  List<String> arrayIds = const [],
  String delimiter = ';',
}) {
  // Sanitise array identifiers so they can be embedded in column
  // headers without breaking the CSV: replace anything that isn't
  // alphanumeric / underscore / dash with `_` and fall back to a
  // positional label when the resulting string would be empty.
  String safeColumn(int index) {
    final raw = index < arrayIds.length ? arrayIds[index] : '';
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
    return cleaned.isEmpty ? 'array_${index + 1}' : cleaned;
  }

  final arrayCount = arrayIds.length;
  final headers = <String>[
    'dayIndex', 'dayOfYear', 'stepOfDay', 'hourOfDay',
    'pvDcKwh', 'pvAcKwh', 'loadKwh', 'selfConsumptionKwh',
    'batteryChargeKwh', 'batteryDischargeKwh', 'batterySocKwh',
    'gridImportKwh', 'gridExportKwh',
    'curtailedDcKwh', 'curtailedAcKwh', 'curtailedExportKwh',
    'microInverterDeliveredKwh', 'microInverterShortfallKwh', 'unservedLoadKwh',
    for (var i = 0; i < arrayCount; i++) 'dcKwh_${safeColumn(i)}',
    for (var i = 0; i < arrayCount; i++) 'acKwh_${safeColumn(i)}',
    for (var i = 1; i <= batteryCount; i++) 'chargeKwh_$i',
    for (var i = 1; i <= batteryCount; i++) 'dischargeKwh_$i',
    for (var i = 1; i <= batteryCount; i++) 'socKwh_$i',
    for (var i = 1; i <= bankCount; i++) 'bankDeliveredKwh_$i',
    for (var i = 1; i <= bankCount; i++) 'bankShortfallKwh_$i',
    'importCostEur', 'exportRevenueEur',
  ];

  final buffer = StringBuffer()..write(headers.map((h) => _quote(h, delimiter)).join(delimiter))..write(_lineEnding);

  for (final step in steps) {
    final row = <String>[
      step.dayIndex.toString(),
      step.dayOfYear.toString(),
      step.stepOfDay.toString(),
      _num(step.hourOfDay),
      _num(step.pvDcKwh),
      _num(step.pvAcKwh),
      _num(step.loadKwh),
      _num(step.selfConsumptionKwh),
      _num(step.batteryChargeKwh),
      _num(step.batteryDischargeKwh),
      _num(step.batterySocKwh),
      _num(step.gridImportKwh),
      _num(step.gridExportKwh),
      _num(step.curtailedDcKwh),
      _num(step.curtailedAcKwh),
      _num(step.curtailedExportKwh),
      _num(step.microInverterDeliveredKwh),
      _num(step.microInverterShortfallKwh),
      _num(step.unservedLoadKwh),
      for (var i = 0; i < arrayCount; i++)
        _num(i < step.dcKwhByArray.length ? step.dcKwhByArray[i] : 0.0),
      for (var i = 0; i < arrayCount; i++)
        _num(i < step.acKwhByArray.length ? step.acKwhByArray[i] : 0.0),
      for (var i = 0; i < batteryCount; i++)
        _num(i < step.batteryChargesKwh.length ? step.batteryChargesKwh[i] : 0.0),
      for (var i = 0; i < batteryCount; i++)
        _num(i < step.batteryDischargesKwh.length ? step.batteryDischargesKwh[i] : 0.0),
      for (var i = 0; i < batteryCount; i++)
        _num(i < step.batterySocsKwh.length ? step.batterySocsKwh[i] : 0.0),
      for (var i = 0; i < bankCount; i++)
        _num(i < step.microInverterDeliveriesKwh.length ? step.microInverterDeliveriesKwh[i] : 0.0),
      for (var i = 0; i < bankCount; i++)
        _num(i < step.microInverterShortfallsKwh.length ? step.microInverterShortfallsKwh[i] : 0.0),
      _num(step.importCostEur),
      _num(step.exportRevenueEur),
    ];
    buffer..write(row.map((v) => _quote(v, delimiter)).join(delimiter))..write(_lineEnding);
  }

  return buffer.toString();
}

/// Per-year monthly CSV for multi-year results. One row per (year,
/// month); years are 1-based. Header matches [monthlyCsv] with a
/// leading `year` column so a single file captures the multi-year
/// breakdown. Returns the header-only output when [perYearMonthly]
/// is empty (single-year run).
String perYearMonthlyCsv(
  List<List<MonthlyBucket>> perYearMonthly, {
  String delimiter = ';',
}) {
  const headers = [
    'year', 'month', 'pvAcKwh', 'loadKwh', 'selfConsumptionKwh',
    'batteryChargeKwh', 'batteryDischargeKwh',
    'gridImportKwh', 'gridExportKwh',
    'curtailedDcKwh', 'curtailedAcKwh', 'curtailedExportKwh',
    'importCostEur', 'exportRevenueEur', 'netCostEur',
  ];
  final buffer = StringBuffer()
    ..write(headers.map((h) => _quote(h, delimiter)).join(delimiter))
    ..write(_lineEnding);
  for (var y = 0; y < perYearMonthly.length; y++) {
    for (final b in perYearMonthly[y]) {
      final row = <String>[
        (y + 1).toString(),
        b.month.toString(),
        _num(b.pvAcKwh),
        _num(b.loadKwh),
        _num(b.selfConsumptionKwh),
        _num(b.batteryChargeKwh),
        _num(b.batteryDischargeKwh),
        _num(b.gridImportKwh),
        _num(b.gridExportKwh),
        _num(b.curtailedDcKwh),
        _num(b.curtailedAcKwh),
        _num(b.curtailedExportKwh),
        _num(b.importCostEur),
        _num(b.exportRevenueEur),
        _num(b.netCostEur),
      ];
      buffer
        ..write(row.map((v) => _quote(v, delimiter)).join(delimiter))
        ..write(_lineEnding);
    }
  }
  return buffer.toString();
}

String monthlyCsv(List<MonthlyBucket> buckets, {String delimiter = ';'}) {
  const headers = [
    'month', 'pvAcKwh', 'loadKwh', 'selfConsumptionKwh',
    'batteryChargeKwh', 'batteryDischargeKwh',
    'gridImportKwh', 'gridExportKwh',
    'curtailedDcKwh', 'curtailedAcKwh', 'curtailedExportKwh',
    'importCostEur', 'exportRevenueEur', 'netCostEur',
  ];

  final buffer = StringBuffer()..write(headers.map((h) => _quote(h, delimiter)).join(delimiter))..write(_lineEnding);

  for (final b in buckets) {
    final row = <String>[
      b.month.toString(),
      _num(b.pvAcKwh),
      _num(b.loadKwh),
      _num(b.selfConsumptionKwh),
      _num(b.batteryChargeKwh),
      _num(b.batteryDischargeKwh),
      _num(b.gridImportKwh),
      _num(b.gridExportKwh),
      _num(b.curtailedDcKwh),
      _num(b.curtailedAcKwh),
      _num(b.curtailedExportKwh),
      _num(b.importCostEur),
      _num(b.exportRevenueEur),
      _num(b.netCostEur),
    ];
    buffer..write(row.map((v) => _quote(v, delimiter)).join(delimiter))..write(_lineEnding);
  }

  return buffer.toString();
}

String _num(double value) => value.toStringAsFixed(6);

String _quote(String value, String delimiter) {
  final needsQuotes = value.contains(delimiter) || value.contains('"') || value.contains('\n') || value.contains('\r');
  if (!needsQuotes) return value;
  return '"${value.replaceAll('"', '""')}"';
}
