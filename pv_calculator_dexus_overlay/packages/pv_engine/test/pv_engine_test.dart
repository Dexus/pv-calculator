import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('PvSimulator', () {
    test('runs a full year with battery SOC within limits', () {
      final result = const PvSimulator().run(_config());
      expect(result.steps, hasLength(365 * 24));
      expect(result.summary.pvAcKwh, greaterThan(0));
      expect(result.summary.loadKwh, closeTo(365 * 10.5, 0.01));
      for (final step in result.steps) {
        expect(step.batterySocKwh, greaterThanOrEqualTo(0.5));
        expect(step.batterySocKwh, lessThanOrEqualTo(7.5));
      }
    });

    test('micro inverter is capped at 800 W AC', () {
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'oversized', label: 'Oversized', peakKw: 3.0, azimuthDeg: 180, tiltDeg: 30, inverterId: 'micro'),
        ],
        inverters: const [
          Inverter(id: 'micro', label: 'Micro', maxAcKw: 2.0, role: InverterRole.microInverter800W),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        startDayOfYear: 172,
      ));
      for (final step in result.steps) {
        expect(step.pvAcKwh, lessThanOrEqualTo(0.8 + 1e-9));
      }
    });

    test('grid export limit curtails surplus', () {
      final unlimited = const PvSimulator().run(_config(battery: null, gridExportLimitKw: null));
      final limited = const PvSimulator().run(_config(battery: null, gridExportLimitKw: 0.1));
      expect(limited.summary.gridExportKwh, lessThan(unlimited.summary.gridExportKwh));
      expect(limited.summary.curtailedKwh, greaterThan(unlimited.summary.curtailedKwh));
    });
  });
}

SimulationConfig _config({BatteryConfig? battery = const BatteryConfig(capacityKwh: 7.5, maxChargeKw: 3.0, maxDischargeKw: 3.0, minSocKwh: 0.5), double? gridExportLimitKw = 6.0}) {
  return SimulationConfig(
    arrays: const [
      PvArray(id: 'south-roof', label: 'Süddach', peakKw: 4.8, azimuthDeg: 180, tiltDeg: 35, inverterId: 'main'),
      PvArray(id: 'balcony', label: 'Balkon', peakKw: 1.2, azimuthDeg: 180, tiltDeg: 30, inverterId: 'micro'),
    ],
    inverters: const [
      Inverter(id: 'main', label: 'Main', maxAcKw: 5.0),
      Inverter(id: 'micro', label: 'Micro', maxAcKw: 0.8, role: InverterRole.microInverter800W),
    ],
    battery: battery,
    loadProfile: const LoadProfile(dailyKwh: 10.5),
    days: 365,
    preRunDays: 365,
    gridExportLimitKw: gridExportLimitKw,
    latitudeDeg: 50.1,
  );
}
