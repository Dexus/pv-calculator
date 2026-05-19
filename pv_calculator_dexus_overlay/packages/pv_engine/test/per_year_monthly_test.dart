import 'dart:convert';

import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

SimulationConfig _baseConfig({
  int years = 3,
  bool withTariff = false,
}) {
  return SimulationConfig(
    arrays: [
      PvArray(
        id: 'roof',
        label: 'Roof',
        peakKw: 5.0,
        azimuthDeg: 180,
        tiltDeg: 30,
        inverterId: 'main',
        degradationPctPerYear: 0.5,
      ),
    ],
    inverters: const [Inverter(id: 'main', label: 'Main', maxAcKw: 5.0)],
    batteries: const [
      BatteryConfig(
        id: 'b',
        capacityKwh: 5.0,
        maxChargeKw: 2.5,
        maxDischargeKw: 2.5,
        minSocKwh: 0.5,
        initialSocKwh: 2.5,
      ),
    ],
    loadProfile: const LoadProfile(dailyKwh: 10.0),
    days: 365,
    simulationYears: years,
    keepSteps: false,
    tariff: withTariff
        ? const TariffConfig(
            importPricePerKwh: 0.30,
            exportPricePerKwh: 0.10,
          )
        : null,
  );
}

void main() {
  group('per-year monthly buckets', () {
    test('single-year run leaves perYearMonthly empty', () {
      final cfg = _baseConfig(years: 1);
      final result = const PvSimulator().run(cfg);
      expect(result.summary.perYearSummaries, isEmpty);
      expect(result.summary.perYearMonthly, isEmpty);
    });

    test('per-year monthly bucket sums match per-year scalar summaries', () {
      final cfg = _baseConfig(years: 3, withTariff: true);
      final result = const PvSimulator().run(cfg);
      final per = result.summary.perYearSummaries;
      final perMonthly = result.summary.perYearMonthly;
      expect(perMonthly, hasLength(per.length));

      for (var y = 0; y < per.length; y++) {
        final buckets = perMonthly[y];
        expect(buckets, hasLength(12),
            reason: 'year $y should have 12 monthly buckets');
        final summed = _sumBuckets(buckets);
        final s = per[y];
        expect(summed.pvAcKwh, closeTo(s.pvAcKwh, 1e-9),
            reason: 'year $y pvAcKwh');
        expect(summed.loadKwh, closeTo(s.loadKwh, 1e-9),
            reason: 'year $y loadKwh');
        expect(summed.selfConsumptionKwh, closeTo(s.selfConsumptionKwh, 1e-9),
            reason: 'year $y selfConsumption');
        expect(summed.batteryChargeKwh, closeTo(s.batteryChargeKwh, 1e-9),
            reason: 'year $y batteryCharge');
        expect(summed.batteryDischargeKwh,
            closeTo(s.batteryDischargeKwh, 1e-9),
            reason: 'year $y batteryDischarge');
        expect(summed.gridImportKwh, closeTo(s.gridImportKwh, 1e-9),
            reason: 'year $y gridImport');
        expect(summed.gridExportKwh, closeTo(s.gridExportKwh, 1e-9),
            reason: 'year $y gridExport');
        expect(summed.importCostEur, closeTo(s.importCostEur ?? 0.0, 1e-9),
            reason: 'year $y importCostEur');
        expect(summed.exportRevenueEur,
            closeTo(s.exportRevenueEur ?? 0.0, 1e-9),
            reason: 'year $y exportRevenueEur');
      }
    });

    test(
        'bucket-wise sum across all years matches aggregated top-level summary',
        () {
      final cfg = _baseConfig(years: 4, withTariff: true);
      final result = const PvSimulator().run(cfg);
      final perMonthly = result.summary.perYearMonthly;

      var pvAc = 0.0,
          load = 0.0,
          sc = 0.0,
          bc = 0.0,
          bd = 0.0,
          gi = 0.0,
          ge = 0.0,
          imp = 0.0,
          exp_ = 0.0;
      for (final year in perMonthly) {
        for (final b in year) {
          pvAc += b.pvAcKwh;
          load += b.loadKwh;
          sc += b.selfConsumptionKwh;
          bc += b.batteryChargeKwh;
          bd += b.batteryDischargeKwh;
          gi += b.gridImportKwh;
          ge += b.gridExportKwh;
          imp += b.importCostEur;
          exp_ += b.exportRevenueEur;
        }
      }
      final s = result.summary;
      expect(pvAc, closeTo(s.pvAcKwh, 1e-9));
      expect(load, closeTo(s.loadKwh, 1e-9));
      expect(sc, closeTo(s.selfConsumptionKwh, 1e-9));
      expect(bc, closeTo(s.batteryChargeKwh, 1e-9));
      expect(bd, closeTo(s.batteryDischargeKwh, 1e-9));
      expect(gi, closeTo(s.gridImportKwh, 1e-9));
      expect(ge, closeTo(s.gridExportKwh, 1e-9));
      expect(imp, closeTo(s.importCostEur!, 1e-9));
      expect(exp_, closeTo(s.exportRevenueEur!, 1e-9));
    });

    test('JSON round-trip preserves perYearMonthly shape and values', () {
      final cfg = _baseConfig(years: 3, withTariff: true);
      final result = const PvSimulator().run(cfg);
      final encoded = jsonEncode(result.summary.toJson());
      final decoded = SimulationSummary.fromJson(
          (jsonDecode(encoded) as Map).cast<String, dynamic>());

      expect(decoded.perYearMonthly, hasLength(3));
      for (var y = 0; y < 3; y++) {
        final original = result.summary.perYearMonthly[y];
        final round = decoded.perYearMonthly[y];
        expect(round, hasLength(12));
        for (var m = 0; m < 12; m++) {
          expect(round[m].month, original[m].month);
          expect(round[m].pvAcKwh, closeTo(original[m].pvAcKwh, 1e-12));
          expect(round[m].loadKwh, closeTo(original[m].loadKwh, 1e-12));
          expect(round[m].selfConsumptionKwh,
              closeTo(original[m].selfConsumptionKwh, 1e-12));
          expect(round[m].batteryChargeKwh,
              closeTo(original[m].batteryChargeKwh, 1e-12));
          expect(round[m].batteryDischargeKwh,
              closeTo(original[m].batteryDischargeKwh, 1e-12));
          expect(round[m].gridImportKwh,
              closeTo(original[m].gridImportKwh, 1e-12));
          expect(round[m].gridExportKwh,
              closeTo(original[m].gridExportKwh, 1e-12));
          expect(round[m].curtailedDcKwh,
              closeTo(original[m].curtailedDcKwh, 1e-12));
          expect(round[m].curtailedAcKwh,
              closeTo(original[m].curtailedAcKwh, 1e-12));
          expect(round[m].curtailedExportKwh,
              closeTo(original[m].curtailedExportKwh, 1e-12));
          expect(round[m].importCostEur,
              closeTo(original[m].importCostEur, 1e-12));
          expect(round[m].exportRevenueEur,
              closeTo(original[m].exportRevenueEur, 1e-12));
        }
      }
    });

    test('single-year toJson() omits the perYearMonthly key', () {
      final cfg = _baseConfig(years: 1);
      final result = const PvSimulator().run(cfg);
      final json = result.summary.toJson();
      expect(json.containsKey('perYearMonthly'), isFalse);
      expect(json.containsKey('perYearSummaries'), isFalse);
    });

    test('multi-year toJson() emits a 12×N nested list of named maps', () {
      final cfg = _baseConfig(years: 2);
      final result = const PvSimulator().run(cfg);
      final json = result.summary.toJson();
      expect(json['perYearMonthly'], isA<List>());
      final outer = json['perYearMonthly'] as List;
      expect(outer, hasLength(2));
      for (final yearJson in outer) {
        expect(yearJson, isA<List>());
        expect(yearJson as List, hasLength(12));
        for (final m in yearJson) {
          expect(m, isA<Map>());
          final bucket = m as Map;
          expect(bucket['month'], isA<int>());
          expect(bucket['pvAcKwh'], isA<num>());
        }
      }
    });

    test('keepSteps:false on multi-year still produces per-year monthly', () {
      // The user's `keepSteps: false` opt-out applies to
      // `result.steps`; per-year monthly is streamed into the engine-
      // private `_MonthlyAccumulator` so no per-year step buffer is
      // allocated. Verified indirectly: the result carries non-trivial
      // monthly KPIs while `result.steps` stays empty.
      final cfg = _baseConfig(years: 3);
      final result = const PvSimulator().run(cfg);
      expect(result.steps, isEmpty);
      expect(result.summary.perYearMonthly, hasLength(3));
      expect(result.summary.perYearMonthly.first, hasLength(12));
      // Non-zero on at least one month — confirms the streaming
      // accumulator actually accumulated (not just zero-initialised).
      final hasYield = result.summary.perYearMonthly.first
          .any((b) => b.pvAcKwh > 0);
      expect(hasYield, isTrue);
    });

    test(
        'keepSteps:false multi-year monthly equals keepSteps:true multi-year monthly',
        () {
      // Byte-identity guard for the streaming accumulator path: the
      // per-year buckets produced via `_MonthlyAccumulator` (when
      // `keepSteps: false` skips the full step buffer) must match the
      // buckets produced via `SummaryAggregator.monthly(result.steps)`
      // on the final year of a `keepSteps: true` run.
      final cfgNoSteps = _baseConfig(years: 3);
      final cfgWithSteps = SimulationConfig(
        arrays: cfgNoSteps.arrays,
        inverters: cfgNoSteps.inverters,
        batteries: cfgNoSteps.batteries,
        loadProfile: cfgNoSteps.loadProfile,
        days: 365,
        simulationYears: 3,
        keepSteps: true,
        tariff: cfgNoSteps.tariff,
      );
      final noSteps = const PvSimulator().run(cfgNoSteps);
      final withSteps = const PvSimulator().run(cfgWithSteps);
      expect(noSteps.summary.perYearMonthly, hasLength(3));
      expect(withSteps.summary.perYearMonthly, hasLength(3));
      for (var y = 0; y < 3; y++) {
        for (var m = 0; m < 12; m++) {
          final a = noSteps.summary.perYearMonthly[y][m];
          final b = withSteps.summary.perYearMonthly[y][m];
          expect(a.pvAcKwh, closeTo(b.pvAcKwh, 1e-9),
              reason: 'year $y month ${m + 1} pvAcKwh');
          expect(a.loadKwh, closeTo(b.loadKwh, 1e-9));
          expect(a.gridImportKwh, closeTo(b.gridImportKwh, 1e-9));
          expect(a.gridExportKwh, closeTo(b.gridExportKwh, 1e-9));
          expect(a.batteryChargeKwh, closeTo(b.batteryChargeKwh, 1e-9));
          expect(a.batteryDischargeKwh, closeTo(b.batteryDischargeKwh, 1e-9));
        }
      }
    });
  });
}

class _BucketSums {
  double pvAcKwh = 0;
  double loadKwh = 0;
  double selfConsumptionKwh = 0;
  double batteryChargeKwh = 0;
  double batteryDischargeKwh = 0;
  double gridImportKwh = 0;
  double gridExportKwh = 0;
  double importCostEur = 0;
  double exportRevenueEur = 0;
}

_BucketSums _sumBuckets(List<MonthlyBucket> buckets) {
  final sums = _BucketSums();
  for (final b in buckets) {
    sums.pvAcKwh += b.pvAcKwh;
    sums.loadKwh += b.loadKwh;
    sums.selfConsumptionKwh += b.selfConsumptionKwh;
    sums.batteryChargeKwh += b.batteryChargeKwh;
    sums.batteryDischargeKwh += b.batteryDischargeKwh;
    sums.gridImportKwh += b.gridImportKwh;
    sums.gridExportKwh += b.gridExportKwh;
    sums.importCostEur += b.importCostEur;
    sums.exportRevenueEur += b.exportRevenueEur;
  }
  return sums;
}
