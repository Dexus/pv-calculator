import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pv_engine/pv_engine.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/config_draft.dart';
import '../state/validation_warning_l10n.dart';

/// A4 simulation report. Renders KPI tables, monthly breakdown,
/// validation warnings, optional bank runtime, per-array yield and a
/// footer with engine version + AGPL note. Pure-pdf — no Flutter widgets,
/// no async I/O. Caller decides what to do with the bytes (share, save,
/// preview); `printing.Printing.sharePdf` is the natural fit.
///
/// All user-visible labels go through [l] so the report matches the
/// UI language of the build that generated it (DE/EN/ES/FR currently).
/// Numeric formatting is locale-independent on purpose so the report
/// is comparable across builds — the engine itself emits doubles, not
/// locale-formatted strings.
///
/// Engine policy: the report MUST consume only `SimulationResult` and
/// `ConfigDraft` data — no simulation re-computation here. Monthly
/// rollups use `SummaryAggregator.monthly`; per-bank runtime uses
/// `SummaryAggregator.bankRuntime`. See AGENTS.md: widgets and services
/// display, the engine computes.
Future<Uint8List> buildReportPdf({
  required SimulationResult result,
  required ConfigDraft draft,
  required AppLocalizations l,
  required String projectName,
  required DateTime runTimestamp,
  required String engineVersion,
  bool compress = true,
}) async {
  final doc = pw.Document(
    title: '${l.pdfAppTitle} - $projectName',
    subject: l.resultsPdfReport,
    // `compress: false` keeps text streams uncompressed so tests can
    // grep the raw bytes for expected labels without pulling in a
    // flate decoder. Production callers always default to compressed.
    compress: compress,
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
        _title(l, projectName, runTimestamp, engineVersion),
        pw.SizedBox(height: 16),
        _summaryTable(l, s),
        pw.SizedBox(height: 16),
        if (s.perYearSummaries.length >= 2) ...[
          _section(l.pdfSectionPerYear),
          _perYearTable(l, s.perYearSummaries),
          pw.SizedBox(height: 16),
        ],
        if (monthly.isNotEmpty) ...[
          _section(s.perYearSummaries.length >= 2
              ? l.pdfSectionMonthlyFinalYear
              : l.pdfSectionMonthly),
          _monthlyTable(l, monthly),
          pw.SizedBox(height: 16),
        ],
        if (monthly.isNotEmpty && s.netCostEur != null) ...[
          _section(l.pdfSectionMonthlyCashflow),
          _monthlyCashflowTable(l, monthly),
          pw.SizedBox(height: 16),
        ],
        if (draft.arrays.isNotEmpty) ...[
          _section(l.pdfSectionArrays),
          _arraysTable(l, draft.arrays),
          pw.SizedBox(height: 16),
        ],
        if (bankRuntime.isNotEmpty) ...[
          _section(l.pdfSectionBanks),
          _bankTable(l, draft.microInverterBanks, bankRuntime),
          pw.SizedBox(height: 16),
        ],
        if (warnings.isNotEmpty) ...[
          _section(l.pdfSectionWarnings),
          _warningsList(l, warnings),
          pw.SizedBox(height: 16),
        ],
        _footer(l, engineVersion, usingSynthetic: usingSynthetic),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _title(
  AppLocalizations l,
  String projectName,
  DateTime ts,
  String engineVersion,
) {
  final stamp = '${ts.year.toString().padLeft(4, '0')}-'
      '${ts.month.toString().padLeft(2, '0')}-'
      '${ts.day.toString().padLeft(2, '0')} '
      '${ts.hour.toString().padLeft(2, '0')}:'
      '${ts.minute.toString().padLeft(2, '0')}';
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Text(l.pdfAppTitle,
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 4),
    pw.Text(projectName,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 2),
    pw.Text(l.pdfGeneratedAt(stamp, engineVersion),
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
  ]);
}

pw.Widget _section(String title) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(title,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
    );

pw.Widget _summaryTable(AppLocalizations l, SimulationSummary s) {
  final rows = <List<String>>[
    [l.pdfColMetric, l.pdfColValue],
    [l.resultsKpiPvAc, '${s.pvAcKwh.toStringAsFixed(0)} kWh'],
    [l.resultsKpiLoad, '${s.loadKwh.toStringAsFixed(0)} kWh'],
    [l.resultsKpiSelfConsumption, '${s.selfConsumptionKwh.toStringAsFixed(0)} kWh'],
    [l.resultsKpiGridImport, '${s.gridImportKwh.toStringAsFixed(0)} kWh'],
    [l.resultsKpiGridExport, '${s.gridExportKwh.toStringAsFixed(0)} kWh'],
    [l.resultsKpiBatteryCharge, '${s.batteryChargeKwh.toStringAsFixed(0)} kWh'],
    [l.resultsKpiBatteryDischarge, '${s.batteryDischargeKwh.toStringAsFixed(0)} kWh'],
    [l.resultsKpiAutarky, '${(s.autarkyRate * 100).toStringAsFixed(1)} %'],
    [l.resultsKpiSelfConsumptionRate, '${(s.selfConsumptionRate * 100).toStringAsFixed(1)} %'],
    [l.resultsKpiCurtailDc, '${s.curtailedDcKwh.toStringAsFixed(0)} kWh'],
    [l.resultsKpiCurtailAc, '${s.curtailedAcKwh.toStringAsFixed(0)} kWh'],
    [l.resultsKpiCurtailExport, '${s.curtailedExportKwh.toStringAsFixed(0)} kWh'],
  ];
  if (s.importCostEur != null) {
    rows.addAll([
      [l.resultsKpiImportCost, '${s.importCostEur!.toStringAsFixed(2)} EUR'],
      [l.resultsKpiExportRevenue, '${s.exportRevenueEur!.toStringAsFixed(2)} EUR'],
      [l.resultsKpiNetCost, '${s.netCostEur!.toStringAsFixed(2)} EUR'],
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

pw.Widget _perYearTable(AppLocalizations l, List<SimulationSummary> years) {
  final rows = <List<String>>[
    [
      l.pdfColYear,
      l.resultsKpiPvAc,
      l.resultsKpiLoad,
      l.pdfColSelfShort,
      l.resultsKpiGridImport,
      l.resultsKpiGridExport,
    ],
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

pw.Widget _monthlyCashflowTable(AppLocalizations l, List<MonthlyBucket> rows) {
  final data = <List<String>>[
    [
      l.pdfColMonth,
      l.monthlyColImportCost,
      l.monthlyColExportRevenue,
      l.monthlyColNetCost,
    ],
    for (final b in rows)
      [
        b.month.toString(),
        b.importCostEur.toStringAsFixed(2),
        b.exportRevenueEur.toStringAsFixed(2),
        b.netCostEur.toStringAsFixed(2),
      ],
  ];
  return pw.TableHelper.fromTextArray(
    data: data,
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    cellStyle: const pw.TextStyle(fontSize: 9),
    cellAlignments: {
      for (var i = 1; i <= 3; i++) i: pw.Alignment.centerRight,
    },
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
  );
}

pw.Widget _monthlyTable(AppLocalizations l, List<MonthlyBucket> rows) {
  final data = <List<String>>[
    [
      l.pdfColMonth,
      l.resultsKpiPvAc,
      l.resultsKpiLoad,
      l.pdfColSelfTight,
      l.pdfColCharge,
      l.pdfColDischarge,
      l.pdfColImport,
      l.pdfColExport,
    ],
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

pw.Widget _arraysTable(AppLocalizations l, List<PvArrayDraft> arrays) {
  final data = <List<String>>[
    [
      l.pdfColId,
      l.pdfColLabel,
      l.pdfColPeakKw,
      l.pdfColAzimuth,
      l.pdfColTilt,
      l.pdfColInverter,
      l.pdfColDegradation,
    ],
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
  AppLocalizations l,
  List<MicroInverterBankDraft> banks,
  List<BankRuntimeStats> stats,
) {
  final data = <List<String>>[
    [
      l.pdfColId,
      l.pdfColTargetKwh,
      l.pdfColDeliveredKwh,
      l.pdfColShortfallKwh,
      l.pdfColCoverage,
    ],
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

pw.Widget _warningsList(AppLocalizations l, List<ValidationWarning> warnings) {
  // Localized warning text comes from the same mapping the Auswertung
  // tab uses, so the PDF body matches what the user saw on screen.
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    for (final w in warnings)
      pw.Text(
        '- ${localizeValidationWarning(l, w)}',
        style: const pw.TextStyle(fontSize: 9),
      ),
  ]);
}

pw.Widget _footer(
  AppLocalizations l,
  String engineVersion, {
  required bool usingSynthetic,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 12),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
    ),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      if (usingSynthetic)
        pw.Text(
          l.pdfFooterSynthetic,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      pw.Text(
        l.pdfFooterAgpl(engineVersion),
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
    ]),
  );
}
