import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pv_engine/pv_engine.dart';

import '../state/config_draft.dart';

/// A4 simulation report. Renders KPI tables, monthly breakdown,
/// validation warnings, optional bank runtime, per-array yield and a
/// footer with engine version + AGPL note. Pure-pdf — no Flutter widgets,
/// no async I/O. Caller decides what to do with the bytes (share, save,
/// preview); `printing.Printing.sharePdf` is the natural fit.
///
/// Engine policy: the report MUST consume only `SimulationResult` and
/// `ConfigDraft` data — no simulation re-computation here. Monthly
/// rollups use `SummaryAggregator.monthly`; per-bank runtime uses
/// `SummaryAggregator.bankRuntime`. See AGENTS.md: widgets and services
/// display, the engine computes.
Future<Uint8List> buildReportPdf({
  required SimulationResult result,
  required ConfigDraft draft,
  required String projectName,
  required DateTime runTimestamp,
  required String engineVersion,
}) async {
  final doc = pw.Document(
    title: 'PV Calculator - $projectName',
    subject: 'Simulation report',
  );
  final s = result.summary;
  final warnings = draft.validationWarnings();
  final monthly = result.steps.isEmpty
      ? const <MonthlyBucket>[]
      : SummaryAggregator.monthly(result.steps);
  final hasBanks = draft.microInverterBanks.isNotEmpty;
  final bankRuntime = hasBanks && result.steps.isNotEmpty
      ? SummaryAggregator.bankRuntime(
          result.steps,
          bankCount: draft.microInverterBanks.length,
          timeStep: draft.timeStep,
        )
      : const <BankRuntimeStats>[];
  final usingSynthetic = draft.siteIrradiance.samples == null;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        _title(projectName, runTimestamp, engineVersion),
        pw.SizedBox(height: 16),
        _summaryTable(s),
        pw.SizedBox(height: 16),
        if (s.perYearSummaries.length >= 2) ...[
          _section('Per-year breakdown'),
          _perYearTable(s.perYearSummaries),
          pw.SizedBox(height: 16),
        ],
        if (monthly.isNotEmpty) ...[
          _section(s.perYearSummaries.length >= 2
              ? 'Monthly (final year only)'
              : 'Monthly'),
          _monthlyTable(monthly),
          pw.SizedBox(height: 16),
        ],
        if (draft.arrays.isNotEmpty) ...[
          _section('PV arrays'),
          _arraysTable(draft.arrays),
          pw.SizedBox(height: 16),
        ],
        if (bankRuntime.isNotEmpty) ...[
          _section('Micro-inverter banks'),
          _bankTable(draft.microInverterBanks, bankRuntime),
          pw.SizedBox(height: 16),
        ],
        if (warnings.isNotEmpty) ...[
          _section('Warnings'),
          _warningsList(warnings),
          pw.SizedBox(height: 16),
        ],
        _footer(engineVersion, usingSynthetic: usingSynthetic),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _title(String projectName, DateTime ts, String engineVersion) {
  final stamp = '${ts.year.toString().padLeft(4, '0')}-'
      '${ts.month.toString().padLeft(2, '0')}-'
      '${ts.day.toString().padLeft(2, '0')} '
      '${ts.hour.toString().padLeft(2, '0')}:'
      '${ts.minute.toString().padLeft(2, '0')}';
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Text('PV Calculator',
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 4),
    pw.Text(projectName,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 2),
    pw.Text('Generated $stamp  -  engine $engineVersion',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
  ]);
}

pw.Widget _section(String title) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(title,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
    );

pw.Widget _summaryTable(SimulationSummary s) {
  final rows = <List<String>>[
    ['Metric', 'Value'],
    ['PV AC', '${s.pvAcKwh.toStringAsFixed(0)} kWh'],
    ['Load', '${s.loadKwh.toStringAsFixed(0)} kWh'],
    ['Self-consumption', '${s.selfConsumptionKwh.toStringAsFixed(0)} kWh'],
    ['Grid import', '${s.gridImportKwh.toStringAsFixed(0)} kWh'],
    ['Grid export', '${s.gridExportKwh.toStringAsFixed(0)} kWh'],
    ['Battery charge', '${s.batteryChargeKwh.toStringAsFixed(0)} kWh'],
    ['Battery discharge', '${s.batteryDischargeKwh.toStringAsFixed(0)} kWh'],
    ['Autarky rate', '${(s.autarkyRate * 100).toStringAsFixed(1)} %'],
    ['Self-consumption rate', '${(s.selfConsumptionRate * 100).toStringAsFixed(1)} %'],
    ['Curtailed (DC)', '${s.curtailedDcKwh.toStringAsFixed(0)} kWh'],
    ['Curtailed (AC)', '${s.curtailedAcKwh.toStringAsFixed(0)} kWh'],
    ['Curtailed (export limit)', '${s.curtailedExportKwh.toStringAsFixed(0)} kWh'],
  ];
  if (s.importCostEur != null) {
    rows.addAll([
      ['Import cost', '${s.importCostEur!.toStringAsFixed(2)} EUR'],
      ['Export revenue', '${s.exportRevenueEur!.toStringAsFixed(2)} EUR'],
      ['Net electricity cost', '${s.netCostEur!.toStringAsFixed(2)} EUR'],
    ]);
  }
  return pw.TableHelper.fromTextArray(
    data: rows,
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
    cellStyle: const pw.TextStyle(fontSize: 10),
    cellAlignment: pw.Alignment.centerLeft,
    cellAlignments: const {1: pw.Alignment.centerRight},
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
  );
}

pw.Widget _perYearTable(List<SimulationSummary> years) {
  final rows = <List<String>>[
    ['Year', 'PV AC', 'Load', 'Self-cons.', 'Grid import', 'Grid export'],
    for (var i = 0; i < years.length; i++)
      [
        (i + 1).toString(),
        '${years[i].pvAcKwh.toStringAsFixed(0)} kWh',
        '${years[i].loadKwh.toStringAsFixed(0)} kWh',
        '${years[i].selfConsumptionKwh.toStringAsFixed(0)} kWh',
        '${years[i].gridImportKwh.toStringAsFixed(0)} kWh',
        '${years[i].gridExportKwh.toStringAsFixed(0)} kWh',
      ],
  ];
  return pw.TableHelper.fromTextArray(
    data: rows,
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    cellStyle: const pw.TextStyle(fontSize: 9),
    cellAlignments: const {
      1: pw.Alignment.centerRight,
      2: pw.Alignment.centerRight,
      3: pw.Alignment.centerRight,
      4: pw.Alignment.centerRight,
      5: pw.Alignment.centerRight,
    },
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
  );
}

pw.Widget _monthlyTable(List<MonthlyBucket> rows) {
  final data = <List<String>>[
    ['Month', 'PV AC', 'Load', 'Self', 'Charge', 'Discharge', 'Import', 'Export'],
    for (final b in rows)
      [
        b.month.toString(),
        b.pvAcKwh.toStringAsFixed(0),
        b.loadKwh.toStringAsFixed(0),
        b.selfConsumptionKwh.toStringAsFixed(0),
        b.batteryChargeKwh.toStringAsFixed(0),
        b.batteryDischargeKwh.toStringAsFixed(0),
        b.gridImportKwh.toStringAsFixed(0),
        b.gridExportKwh.toStringAsFixed(0),
      ],
  ];
  return pw.TableHelper.fromTextArray(
    data: data,
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    cellStyle: const pw.TextStyle(fontSize: 9),
    cellAlignments: {
      for (var i = 1; i <= 7; i++) i: pw.Alignment.centerRight,
    },
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
  );
}

pw.Widget _arraysTable(List<PvArrayDraft> arrays) {
  final data = <List<String>>[
    ['ID', 'Label', 'Peak kW', 'Azim.', 'Tilt', 'Inverter', 'Degrad. %/a'],
    for (final a in arrays)
      [
        a.id,
        a.label,
        a.peakKw.toStringAsFixed(2),
        a.azimuthDeg.toStringAsFixed(0),
        a.tiltDeg.toStringAsFixed(0),
        a.inverterId,
        a.degradationPctPerYear.toStringAsFixed(2),
      ],
  ];
  return pw.TableHelper.fromTextArray(
    data: data,
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    cellStyle: const pw.TextStyle(fontSize: 9),
    cellAlignments: const {
      2: pw.Alignment.centerRight,
      3: pw.Alignment.centerRight,
      4: pw.Alignment.centerRight,
      6: pw.Alignment.centerRight,
    },
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
  );
}

pw.Widget _bankTable(
  List<MicroInverterBankDraft> banks,
  List<BankRuntimeStats> stats,
) {
  final data = <List<String>>[
    ['ID', 'Target kWh', 'Delivered kWh', 'Shortfall kWh', 'Coverage %'],
    for (var i = 0; i < stats.length; i++)
      [
        i < banks.length ? (banks[i].label.isEmpty ? banks[i].id : banks[i].label) : '?',
        stats[i].targetKwh.toStringAsFixed(0),
        stats[i].deliveredKwh.toStringAsFixed(0),
        stats[i].shortfallKwh.toStringAsFixed(0),
        (stats[i].coverageRate * 100).toStringAsFixed(1),
      ],
  ];
  return pw.TableHelper.fromTextArray(
    data: data,
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    cellStyle: const pw.TextStyle(fontSize: 9),
    cellAlignments: const {
      1: pw.Alignment.centerRight,
      2: pw.Alignment.centerRight,
      3: pw.Alignment.centerRight,
      4: pw.Alignment.centerRight,
    },
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
  );
}

pw.Widget _warningsList(List<ValidationWarning> warnings) {
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    for (final w in warnings)
      pw.Text(
        '- [${w.severity.name}] ${w.code}'
        '${w.args.isEmpty ? '' : ' ${w.args}'}',
        style: const pw.TextStyle(fontSize: 9),
      ),
  ]);
}

pw.Widget _footer(String engineVersion, {required bool usingSynthetic}) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 12),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
    ),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      if (usingSynthetic)
        pw.Text(
          'Note: this report was generated with the synthetic demo '
          'irradiance model. Numbers are illustrative - not a validated '
          'yield forecast.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      pw.Text(
        'Generated by PV Calculator (AGPL-3.0)  -  engine $engineVersion',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
    ]),
  );
}
