import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

SimulationConfig _config({
  List<PvArray>? arrays,
  List<Inverter>? inverters,
  List<BatteryConfig>? batteries,
  List<MicroInverterBank>? banks,
}) {
  return SimulationConfig(
    arrays: arrays ?? const [],
    inverters: inverters ?? const [],
    batteries: batteries ?? const [],
    microInverterBanks: banks ?? const [],
    loadProfile: const LoadProfile(dailyKwh: 1),
  );
}

PvArray _array({required String inverterId, required double peakKw}) =>
    PvArray(
      id: 'a-$inverterId-$peakKw',
      label: 'a',
      peakKw: peakKw,
      tiltDeg: 30,
      azimuthDeg: 0,
      inverterId: inverterId,
    );

Inverter _inverter({required String id, required double maxAcKw}) => Inverter(
      id: id,
      label: id,
      role: InverterRole.grid,
      maxAcKw: maxAcKw,
      efficiency: 0.96,
    );

BatteryConfig _battery({
  required String id,
  required double capacityKwh,
  required double maxDischargeKw,
  double minSocKwh = 0,
}) =>
    BatteryConfig(
      id: id,
      label: id,
      capacityKwh: capacityKwh,
      maxChargeKw: 3,
      maxDischargeKw: maxDischargeKw,
      roundTripEfficiency: 0.9,
      minSocKwh: minSocKwh,
    );

MicroInverterBank _bank({
  required String id,
  required String batteryId,
  required int count,
  required double unitW,
}) =>
    MicroInverterBank(
      id: id,
      label: id,
      batteryId: batteryId,
      count: count,
      unitRatedPowerW: unitW,
    );

void main() {
  test('empty config has no warnings', () {
    expect(_config().nonBlockingWarnings(), isEmpty);
  });

  group('inverter-oversized', () {
    test('emits when DC peak / AC cap > 1.3', () {
      final config = _config(
        inverters: [_inverter(id: 'inv1', maxAcKw: 2)],
        arrays: [_array(inverterId: 'inv1', peakKw: 6)], // ratio 3.0
      );
      final warnings = config.nonBlockingWarnings();
      expect(warnings, hasLength(1));
      expect(warnings.first.code, 'inverter-oversized');
      expect(warnings.first.args['inverter'], 'inv1');
      expect(warnings.first.args['ratio'], '3.00');
    });

    test('stays silent at exactly the 1.3 boundary', () {
      final config = _config(
        inverters: [_inverter(id: 'inv1', maxAcKw: 1)],
        arrays: [_array(inverterId: 'inv1', peakKw: 1.3)], // ratio 1.3 exactly
      );
      expect(config.nonBlockingWarnings(), isEmpty);
    });

    test('zero AC cap is skipped (would divide by zero)', () {
      final config = _config(
        inverters: [_inverter(id: 'inv1', maxAcKw: 0)],
        arrays: [_array(inverterId: 'inv1', peakKw: 5)],
      );
      expect(config.nonBlockingWarnings(), isEmpty);
    });
  });

  group('bank-exceeds-discharge', () {
    test('emits when bank AC kW > battery discharge', () {
      final config = _config(
        batteries: [
          _battery(id: 'bat1', capacityKwh: 10, maxDischargeKw: 3),
        ],
        banks: [
          // 5 × 800 W = 4 kW AC, battery only 3 kW discharge → warn.
          _bank(id: 'bank1', batteryId: 'bat1', count: 5, unitW: 800),
        ],
      );
      final warnings = config.nonBlockingWarnings();
      expect(warnings.map((w) => w.code), contains('bank-exceeds-discharge'));
      final w = warnings.firstWhere((w) => w.code == 'bank-exceeds-discharge');
      expect(w.args['bank'], 'bank1');
      expect(w.args['bankKw'], '4.00');
      expect(w.args['dischargeKw'], '3.00');
    });

    test('orphan bank (battery missing) emits nothing', () {
      final config = _config(
        banks: [_bank(id: 'b', batteryId: 'missing', count: 5, unitW: 800)],
      );
      expect(config.nonBlockingWarnings(), isEmpty);
    });
  });

  group('battery-min-soc-high', () {
    test('emits when minSoc / capacity > 0.5', () {
      final config = _config(
        batteries: [
          _battery(
            id: 'bat1',
            capacityKwh: 10,
            maxDischargeKw: 3,
            minSocKwh: 6,
          ),
        ],
      );
      final warnings = config.nonBlockingWarnings();
      expect(warnings.map((w) => w.code), contains('battery-min-soc-high'));
      final w = warnings.firstWhere((w) => w.code == 'battery-min-soc-high');
      expect(w.args['battery'], 'bat1');
      expect(w.args['pct'], '60');
    });

    test('stays silent at exactly 0.5', () {
      final config = _config(
        batteries: [
          _battery(
            id: 'bat1',
            capacityKwh: 10,
            maxDischargeKw: 3,
            minSocKwh: 5,
          ),
        ],
      );
      expect(
        config.nonBlockingWarnings().map((w) => w.code),
        isNot(contains('battery-min-soc-high')),
      );
    });
  });
}
