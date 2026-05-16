import '../pv_engine.dart';

const _lineEnding = '\r\n';

String stepsCsv(
  List<SimulationStep> steps, {
  int batteryCount = 0,
  String delimiter = ';',
}) {
  final headers = <String>[
    'dayIndex', 'dayOfYear', 'stepOfDay', 'hourOfDay',
    'pvDcKwh', 'pvAcKwh', 'loadKwh', 'selfConsumptionKwh',
    'batteryChargeKwh', 'batteryDischargeKwh', 'batterySocKwh',
    'gridImportKwh', 'gridExportKwh', 'curtailedKwh',
    for (var i = 1; i <= batteryCount; i++) 'socKwh_$i',
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
      _num(step.curtailedKwh),
      for (var i = 0; i < batteryCount; i++)
        _num(i < step.batterySocsKwh.length ? step.batterySocsKwh[i] : 0.0),
    ];
    buffer..write(row.map((v) => _quote(v, delimiter)).join(delimiter))..write(_lineEnding);
  }

  return buffer.toString();
}

String monthlyCsv(List<MonthlyBucket> buckets, {String delimiter = ';'}) {
  const headers = [
    'month', 'pvAcKwh', 'loadKwh', 'selfConsumptionKwh',
    'batteryChargeKwh', 'batteryDischargeKwh',
    'gridImportKwh', 'gridExportKwh', 'curtailedKwh',
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
      _num(b.curtailedKwh),
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
