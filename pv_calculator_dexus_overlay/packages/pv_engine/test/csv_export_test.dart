import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('stepsCsv', () {
    test('emits header + one row per step with CRLF line endings', () {
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'r', label: 'R', peakKw: 1.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5.0)],
        loadProfile: const LoadProfile(dailyKwh: 5),
        startDayOfYear: 172,
        days: 1,
      ));

      final csv = stepsCsv(result.steps);
      final lines = csv.split('\r\n');
      // 24 data rows + 1 header + 1 empty trailing element from split on final CRLF
      expect(lines, hasLength(24 + 1 + 1));
      expect(lines.first.split(';'), contains('pvAcKwh'));
      for (final col in ['socKwh_1', 'chargeKwh_1', 'dischargeKwh_1']) {
        expect(lines.first.split(';'), isNot(contains(col)),
            reason: 'no per-battery columns when batteryCount is 0');
      }
    });

    test('appends per-battery charge / discharge / soc columns in declared order', () {
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'r', label: 'R', peakKw: 2.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5.0)],
        batteries: const [
          BatteryConfig(id: 'a', capacityKwh: 2, maxChargeKw: 2, maxDischargeKw: 2),
          BatteryConfig(id: 'b', capacityKwh: 2, maxChargeKw: 2, maxDischargeKw: 2),
        ],
        loadProfile: const LoadProfile(dailyKwh: 3),
        startDayOfYear: 172,
        days: 1,
      ));

      final csv = stepsCsv(result.steps, batteryCount: 2);
      final lines = csv.split('\r\n');
      final headers = lines.first.split(';');
      expect(headers, containsAll([
        'chargeKwh_1', 'chargeKwh_2',
        'dischargeKwh_1', 'dischargeKwh_2',
        'socKwh_1', 'socKwh_2',
      ]));
      // Charge → discharge → soc, each in declared order.
      expect(headers.indexOf('chargeKwh_1'), lessThan(headers.indexOf('chargeKwh_2')));
      expect(headers.indexOf('chargeKwh_2'), lessThan(headers.indexOf('dischargeKwh_1')));
      expect(headers.indexOf('dischargeKwh_2'), lessThan(headers.indexOf('socKwh_1')));
      expect(headers.indexOf('socKwh_1'), lessThan(headers.indexOf('socKwh_2')));
    });

    test('comma delimiter is honoured', () {
      final csv = stepsCsv(const [], delimiter: ',');
      expect(csv.split('\r\n').first, contains('pvAcKwh'));
      expect(csv.split('\r\n').first, contains(','));
      expect(csv.split('\r\n').first, isNot(contains(';')));
    });

    test('arrayIds emits one dcKwh_<id> / acKwh_<id> column per array', () {
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'south', label: 'South', peakKw: 2.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
          PvArray(id: 'east', label: 'East', peakKw: 1.0, azimuthDeg: 90, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5.0)],
        loadProfile: const LoadProfile(dailyKwh: 3),
        startDayOfYear: 172,
        days: 1,
      ));

      final csv = stepsCsv(result.steps, arrayIds: ['south', 'east']);
      final headers = csv.split('\r\n').first.split(';');
      expect(headers, containsAll(['dcKwh_south', 'dcKwh_east', 'acKwh_south', 'acKwh_east']));
      // DC columns come before AC columns; per-array order is preserved.
      expect(headers.indexOf('dcKwh_south'), lessThan(headers.indexOf('dcKwh_east')));
      expect(headers.indexOf('dcKwh_east'), lessThan(headers.indexOf('acKwh_south')));
    });

    test('per-array DC sums to step.pvDcKwh; per-array AC sums to step.pvAcKwh', () {
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'south', label: 'South', peakKw: 2.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
          PvArray(id: 'east', label: 'East', peakKw: 1.0, azimuthDeg: 90, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5.0)],
        loadProfile: const LoadProfile(dailyKwh: 3),
        startDayOfYear: 172,
        days: 1,
      ));

      for (final step in result.steps) {
        final dcSum = step.dcKwhByArray.fold<double>(0, (s, v) => s + v);
        final acSum = step.acKwhByArray.fold<double>(0, (s, v) => s + v);
        expect(dcSum, closeTo(step.pvDcKwh, 1e-9));
        expect(acSum, closeTo(step.pvAcKwh, 1e-9));
      }
    });

    test('arrayIds with reserved characters are sanitised into safe column names', () {
      final csv = stepsCsv(const [], arrayIds: ['south;roof', 'east "wing"']);
      final headers = csv.split('\r\n').first.split(';');
      // Reserved chars folded to `_`; column count is still 2 × 2 = 4
      // (dcKwh + acKwh per array).
      expect(headers.where((h) => h.startsWith('dcKwh_')), hasLength(2));
      expect(headers.where((h) => h.startsWith('acKwh_')), hasLength(2));
      expect(headers.any((h) => h.contains(';')), isFalse,
          reason: 'delimiter must never appear in a header');
    });

    test('cashflow columns are always present as trailing headers', () {
      final csv = stepsCsv(const []);
      final headers = csv.split('\r\n').first.split(';');
      expect(headers, containsAllInOrder(['importCostEur', 'exportRevenueEur']));
      expect(headers.last, 'exportRevenueEur');
      expect(headers[headers.length - 2], 'importCostEur');
    });

    test('cashflow values populate when a tariff is configured', () {
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'r', label: 'R', peakKw: 1.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5.0)],
        loadProfile: const LoadProfile(dailyKwh: 5),
        startDayOfYear: 172,
        days: 1,
        tariff: const TariffConfig(
          importPricePerKwh: 0.30,
          exportPricePerKwh: 0.08,
        ),
      ));
      final csv = stepsCsv(result.steps);
      final lines = csv.split('\r\n');
      final headers = lines.first.split(';');
      final importIdx = headers.indexOf('importCostEur');
      final exportIdx = headers.indexOf('exportRevenueEur');
      // At least one data row must have a non-zero € value once the
      // simulator has spent or earned anything against the tariff.
      var anyNonZero = false;
      for (var i = 1; i < lines.length - 1; i++) {
        final row = lines[i].split(';');
        if (double.parse(row[importIdx]) > 0 ||
            double.parse(row[exportIdx]) > 0) {
          anyNonZero = true;
          break;
        }
      }
      expect(anyNonZero, isTrue);
    });

    test('cashflow values stay zero when no tariff is configured', () {
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'r', label: 'R', peakKw: 1.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5.0)],
        loadProfile: const LoadProfile(dailyKwh: 5),
        startDayOfYear: 172,
        days: 1,
      ));
      final csv = stepsCsv(result.steps);
      final lines = csv.split('\r\n');
      final headers = lines.first.split(';');
      final importIdx = headers.indexOf('importCostEur');
      final exportIdx = headers.indexOf('exportRevenueEur');
      for (var i = 1; i < lines.length - 1; i++) {
        final row = lines[i].split(';');
        expect(double.parse(row[importIdx]), 0);
        expect(double.parse(row[exportIdx]), 0);
      }
    });
  });

  group('monthlyCsv', () {
    test('emits 12 data rows', () {
      final csv = monthlyCsv(SummaryAggregator.monthly(const []));
      final lines = csv.split('\r\n');
      expect(lines, hasLength(12 + 1 + 1));
      expect(lines.first.split(';').first, 'month');
      expect(lines[1].split(';').first, '1');
      expect(lines[12].split(';').first, '12');
    });

    test('cashflow columns appear as trailing headers including netCostEur', () {
      final csv = monthlyCsv(SummaryAggregator.monthly(const []));
      final headers = csv.split('\r\n').first.split(';');
      expect(headers, containsAllInOrder(
          ['importCostEur', 'exportRevenueEur', 'netCostEur']));
      expect(headers.last, 'netCostEur');
    });

    test('cashflow row values are formatted with 6 decimals and net = import − export',
        () {
      // Hand-crafted bucket with known € values; assert the literal
      // CSV cell formatting + the derived `netCostEur` column.
      const bucket = MonthlyBucket(
        month: 7,
        pvAcKwh: 0, loadKwh: 0, selfConsumptionKwh: 0,
        batteryChargeKwh: 0, batteryDischargeKwh: 0,
        gridImportKwh: 0, gridExportKwh: 0,
        curtailedDcKwh: 0, curtailedAcKwh: 0, curtailedExportKwh: 0,
        importCostEur: 12.5, exportRevenueEur: 4.25,
      );
      final csv = monthlyCsv([bucket]);
      final lines = csv.split('\r\n');
      final headers = lines.first.split(';');
      final row = lines[1].split(';');
      final imp = row[headers.indexOf('importCostEur')];
      final exp = row[headers.indexOf('exportRevenueEur')];
      final net = row[headers.indexOf('netCostEur')];
      expect(imp, '12.500000');
      expect(exp, '4.250000');
      expect(net, '8.250000');
    });

    test('cashflow values populate when a tariff is configured (monthlyCsv)',
        () {
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'r', label: 'R', peakKw: 4.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5.0)],
        loadProfile: const LoadProfile(dailyKwh: 8),
        days: 365,
        latitudeDeg: 50.0,
        tariff: const TariffConfig(
            importPricePerKwh: 0.30, exportPricePerKwh: 0.08),
      ));
      final buckets = SummaryAggregator.monthly(result.steps);
      final csv = monthlyCsv(buckets);
      final lines = csv.split('\r\n');
      final headers = lines.first.split(';');
      final impIdx = headers.indexOf('importCostEur');
      final netIdx = headers.indexOf('netCostEur');
      var anyNonZeroImport = false;
      for (var i = 1; i < lines.length - 1; i++) {
        final row = lines[i].split(';');
        if (double.parse(row[impIdx]) > 0) {
          anyNonZeroImport = true;
          // For every row, netCostEur must equal import − export.
          final exp = double.parse(row[headers.indexOf('exportRevenueEur')]);
          final imp = double.parse(row[impIdx]);
          final net = double.parse(row[netIdx]);
          // CSV cells are formatted to 6 decimals (see csv_export.dart
          // `_num`), so the parsed-back values can differ from the
          // engine's full-precision floats by up to ~5e-7 per cell.
          expect(net, closeTo(imp - exp, 1e-6));
        }
      }
      expect(anyNonZeroImport, isTrue);
    });
  });

  group('perYearMonthlyCsv', () {
    test('empty input emits header-only', () {
      final csv = perYearMonthlyCsv(const []);
      final lines = csv.split('\r\n');
      // header + trailing empty line
      expect(lines, hasLength(2));
      final headers = lines.first.split(';');
      expect(headers.first, 'year');
      expect(headers[1], 'month');
      expect(headers.last, 'netCostEur');
    });

    test('emits one row per (year, month) in year-major order', () {
      // Build a 2 × 12 nested list with the year/month encoded in
      // pvAcKwh so the row order is verifiable.
      final perYear = <List<MonthlyBucket>>[
        for (var y = 1; y <= 2; y++)
          [
            for (var m = 1; m <= 12; m++)
              MonthlyBucket(
                month: m,
                pvAcKwh: y * 100.0 + m,
                loadKwh: 0, selfConsumptionKwh: 0,
                batteryChargeKwh: 0, batteryDischargeKwh: 0,
                gridImportKwh: 0, gridExportKwh: 0,
                curtailedDcKwh: 0, curtailedAcKwh: 0, curtailedExportKwh: 0,
                importCostEur: 0, exportRevenueEur: 0,
              ),
          ],
      ];
      final csv = perYearMonthlyCsv(perYear);
      final lines = csv.split('\r\n');
      // 1 header + 24 data + 1 trailing empty
      expect(lines, hasLength(26));
      final headers = lines.first.split(';');
      final yearIdx = headers.indexOf('year');
      final monthIdx = headers.indexOf('month');
      final pvAcIdx = headers.indexOf('pvAcKwh');
      // Year 1, month 1 in row index 1.
      var row = lines[1].split(';');
      expect(row[yearIdx], '1');
      expect(row[monthIdx], '1');
      expect(double.parse(row[pvAcIdx]), closeTo(101.0, 1e-9));
      // Year 1, month 12 in row index 12.
      row = lines[12].split(';');
      expect(row[yearIdx], '1');
      expect(row[monthIdx], '12');
      // Year 2, month 1 in row index 13.
      row = lines[13].split(';');
      expect(row[yearIdx], '2');
      expect(row[monthIdx], '1');
      expect(double.parse(row[pvAcIdx]), closeTo(201.0, 1e-9));
      // Year 2, month 12 in row index 24.
      row = lines[24].split(';');
      expect(row[yearIdx], '2');
      expect(row[monthIdx], '12');
    });

    test('comma delimiter is honoured', () {
      final perYear = <List<MonthlyBucket>>[
        [
          for (var m = 1; m <= 12; m++)
            MonthlyBucket(
              month: m,
              pvAcKwh: 0, loadKwh: 0, selfConsumptionKwh: 0,
              batteryChargeKwh: 0, batteryDischargeKwh: 0,
              gridImportKwh: 0, gridExportKwh: 0,
              curtailedDcKwh: 0, curtailedAcKwh: 0, curtailedExportKwh: 0,
              importCostEur: 0, exportRevenueEur: 0,
            ),
        ],
      ];
      final csv = perYearMonthlyCsv(perYear, delimiter: ',');
      expect(csv.split('\r\n').first.startsWith('year,month,pvAcKwh,'), isTrue);
    });

    test('end-to-end with simulator: row count = years × 12', () {
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(
            id: 'r',
            label: 'R',
            peakKw: 4.0,
            azimuthDeg: 180,
            tiltDeg: 35,
            inverterId: 'i',
            degradationPctPerYear: 0.5,
          ),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5.0)],
        loadProfile: const LoadProfile(dailyKwh: 8),
        days: 365,
        simulationYears: 3,
        keepSteps: false,
        latitudeDeg: 50.0,
      ));
      final csv = perYearMonthlyCsv(result.summary.perYearMonthly);
      final dataLines = csv
          .split('\r\n')
          .where((l) => l.isNotEmpty)
          .skip(1)
          .toList();
      expect(dataLines, hasLength(3 * 12));
    });
  });
}
