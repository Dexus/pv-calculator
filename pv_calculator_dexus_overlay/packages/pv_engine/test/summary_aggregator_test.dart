import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SummaryAggregator', () {
    test('monthOfDayOfYear maps boundary days correctly', () {
      expect(SummaryAggregator.monthOfDayOfYear(1), 1);
      expect(SummaryAggregator.monthOfDayOfYear(31), 1);
      expect(SummaryAggregator.monthOfDayOfYear(32), 2);
      expect(SummaryAggregator.monthOfDayOfYear(59), 2);
      expect(SummaryAggregator.monthOfDayOfYear(60), 3);
      expect(SummaryAggregator.monthOfDayOfYear(365), 12);
    });

    test('monthly bucket sums equal SimulationSummary annual totals', () {
      final config = SimulationConfig(
        arrays: const [
          PvArray(id: 'r', label: 'R', peakKw: 4.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5.0)],
        batteries: const [BatteryConfig(id: 'b', capacityKwh: 5, maxChargeKw: 2, maxDischargeKw: 2)],
        loadProfile: const LoadProfile(dailyKwh: 8),
        days: 365,
        latitudeDeg: 50.0,
      );
      final result = const PvSimulator().run(config);
      final monthly = SummaryAggregator.monthly(result.steps);

      double sumOf(double Function(MonthlyBucket b) selector) =>
          monthly.fold<double>(0, (acc, b) => acc + selector(b));

      expect(sumOf((b) => b.pvAcKwh), closeTo(result.summary.pvAcKwh, 1e-9));
      expect(sumOf((b) => b.loadKwh), closeTo(result.summary.loadKwh, 1e-9));
      expect(sumOf((b) => b.selfConsumptionKwh), closeTo(result.summary.selfConsumptionKwh, 1e-9));
      expect(sumOf((b) => b.batteryChargeKwh), closeTo(result.summary.batteryChargeKwh, 1e-9));
      expect(sumOf((b) => b.batteryDischargeKwh), closeTo(result.summary.batteryDischargeKwh, 1e-9));
      expect(sumOf((b) => b.gridImportKwh), closeTo(result.summary.gridImportKwh, 1e-9));
      expect(sumOf((b) => b.gridExportKwh), closeTo(result.summary.gridExportKwh, 1e-9));
      expect(sumOf((b) => b.curtailedDcKwh), closeTo(result.summary.curtailedDcKwh, 1e-9));
      expect(sumOf((b) => b.curtailedAcKwh), closeTo(result.summary.curtailedAcKwh, 1e-9));
      expect(sumOf((b) => b.curtailedExportKwh), closeTo(result.summary.curtailedExportKwh, 1e-9));
      // No tariff configured → all cashflow buckets must be zero.
      expect(sumOf((b) => b.importCostEur), 0);
      expect(sumOf((b) => b.exportRevenueEur), 0);
      expect(sumOf((b) => b.netCostEur), 0);
    });

    test('monthly cashflow buckets sum to annual SimulationSummary scalars', () {
      final config = SimulationConfig(
        arrays: const [
          PvArray(id: 'r', label: 'R', peakKw: 4.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5.0)],
        batteries: const [BatteryConfig(id: 'b', capacityKwh: 5, maxChargeKw: 2, maxDischargeKw: 2)],
        loadProfile: const LoadProfile(dailyKwh: 8),
        days: 365,
        latitudeDeg: 50.0,
        tariff: const TariffConfig(
          importPricePerKwh: 0.30,
          exportPricePerKwh: 0.08,
        ),
      );
      final result = const PvSimulator().run(config);
      final monthly = SummaryAggregator.monthly(result.steps);

      double sumOf(double Function(MonthlyBucket b) selector) =>
          monthly.fold<double>(0, (acc, b) => acc + selector(b));

      expect(result.summary.importCostEur, isNotNull);
      expect(result.summary.exportRevenueEur, isNotNull);
      expect(sumOf((b) => b.importCostEur),
          closeTo(result.summary.importCostEur!, 1e-9));
      expect(sumOf((b) => b.exportRevenueEur),
          closeTo(result.summary.exportRevenueEur!, 1e-9));
      expect(sumOf((b) => b.netCostEur),
          closeTo(result.summary.netCostEur!, 1e-9));
    });

    test('one-day run lands in the expected month bucket', () {
      final config = SimulationConfig(
        arrays: const [
          PvArray(id: 'r', label: 'R', peakKw: 1.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5.0)],
        loadProfile: const LoadProfile(dailyKwh: 0),
        startDayOfYear: 200, // mid-July (day 200 → month 7)
        days: 1,
      );
      final result = const PvSimulator().run(config);
      final monthly = SummaryAggregator.monthly(result.steps);

      expect(monthly[6].pvAcKwh, greaterThan(0));
      for (var i = 0; i < 12; i++) {
        if (i != 6) expect(monthly[i].pvAcKwh, 0);
      }
    });

    test('returns 12 zero-filled buckets for empty input', () {
      final monthly = SummaryAggregator.monthly(const []);
      expect(monthly, hasLength(12));
      for (var i = 0; i < 12; i++) {
        expect(monthly[i].month, i + 1);
        expect(monthly[i].pvAcKwh, 0);
      }
    });

    test('buffer fast path matches list fallback bucket-for-bucket', () {
      // Reproduce a full-year run, then re-aggregate the same steps via
      // a plain List<SimulationStep> copy. The first call hits the
      // _StepListView buffer path; the second hits the per-step list
      // path. Bucket-for-bucket equality is the parity invariant.
      final config = SimulationConfig(
        arrays: const [
          PvArray(id: 'r', label: 'R', peakKw: 4.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5.0)],
        batteries: const [BatteryConfig(id: 'b', capacityKwh: 5, maxChargeKw: 2, maxDischargeKw: 2)],
        loadProfile: const LoadProfile(dailyKwh: 8),
        days: 365,
        latitudeDeg: 50.0,
      );
      final result = const PvSimulator().run(config);
      final viaBuffer = SummaryAggregator.monthly(result.steps);
      final viaList = SummaryAggregator.monthly(
        List<SimulationStep>.of(result.steps),
      );
      expect(viaBuffer, hasLength(12));
      expect(viaList, hasLength(12));
      for (var i = 0; i < 12; i++) {
        expect(viaBuffer[i].pvAcKwh, closeTo(viaList[i].pvAcKwh, 1e-9));
        expect(viaBuffer[i].loadKwh, closeTo(viaList[i].loadKwh, 1e-9));
        expect(viaBuffer[i].selfConsumptionKwh,
            closeTo(viaList[i].selfConsumptionKwh, 1e-9));
        expect(viaBuffer[i].batteryChargeKwh,
            closeTo(viaList[i].batteryChargeKwh, 1e-9));
        expect(viaBuffer[i].batteryDischargeKwh,
            closeTo(viaList[i].batteryDischargeKwh, 1e-9));
        expect(viaBuffer[i].gridImportKwh,
            closeTo(viaList[i].gridImportKwh, 1e-9));
        expect(viaBuffer[i].gridExportKwh,
            closeTo(viaList[i].gridExportKwh, 1e-9));
        expect(viaBuffer[i].curtailedDcKwh,
            closeTo(viaList[i].curtailedDcKwh, 1e-9));
        expect(viaBuffer[i].curtailedAcKwh,
            closeTo(viaList[i].curtailedAcKwh, 1e-9));
        expect(viaBuffer[i].curtailedExportKwh,
            closeTo(viaList[i].curtailedExportKwh, 1e-9));
        expect(viaBuffer[i].importCostEur,
            closeTo(viaList[i].importCostEur, 1e-9));
        expect(viaBuffer[i].exportRevenueEur,
            closeTo(viaList[i].exportRevenueEur, 1e-9));
      }
    });

    test('buffer fast path matches list fallback for cashflow buckets', () {
      // Same parity invariant as above, but with a tariff configured so
      // the cashflow columns carry non-zero values that must line up
      // between the buffer fast path and the per-step list fallback.
      final config = SimulationConfig(
        arrays: const [
          PvArray(id: 'r', label: 'R', peakKw: 4.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5.0)],
        batteries: const [BatteryConfig(id: 'b', capacityKwh: 5, maxChargeKw: 2, maxDischargeKw: 2)],
        loadProfile: const LoadProfile(dailyKwh: 8),
        days: 365,
        latitudeDeg: 50.0,
        tariff: const TariffConfig(
          importPricePerKwh: 0.30,
          exportPricePerKwh: 0.08,
        ),
      );
      final result = const PvSimulator().run(config);
      final viaBuffer = SummaryAggregator.monthly(result.steps);
      final viaList = SummaryAggregator.monthly(
        List<SimulationStep>.of(result.steps),
      );
      double total = 0;
      for (var i = 0; i < 12; i++) {
        total += viaBuffer[i].importCostEur;
        expect(viaBuffer[i].importCostEur,
            closeTo(viaList[i].importCostEur, 1e-9));
        expect(viaBuffer[i].exportRevenueEur,
            closeTo(viaList[i].exportRevenueEur, 1e-9));
      }
      expect(total, greaterThan(0));
    });
  });
}
