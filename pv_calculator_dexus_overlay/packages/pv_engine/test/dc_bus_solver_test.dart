import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

DcBusBattery _battery({
  int index = 0,
  double chargeRateKwh = 10.0,
  double dischargeRateKwh = 10.0,
  double chargeEff = 1.0,
  double dischargeEff = 1.0,
  double headroomStoredKwh = 100.0,
  double usableStoredKwh = 100.0,
  double chargeTargetKwh = double.infinity,
  double dischargeTargetKwh = double.infinity,
}) =>
    DcBusBattery(
      batteryIndex: index,
      chargeRateCapKwh: chargeRateKwh,
      dischargeRateCapKwh: dischargeRateKwh,
      chargeEfficiency: chargeEff,
      dischargeEfficiency: dischargeEff,
      headroomStoredKwh: headroomStoredKwh,
      usableStoredKwh: usableStoredKwh,
      chargeTargetKwh: chargeTargetKwh,
      dischargeTargetKwh: dischargeTargetKwh,
    );

HybridInverterInfo _inv({
  String id = 'inv',
  double edgeEta = 1.0,
  double invEta = 1.0,
  double acRemainingKwh = 10.0,
  double? dcRemainingKwh,
  double? edgeMaxPowerKwh,
}) =>
    HybridInverterInfo(
      inverterId: id,
      edgeEfficiency: edgeEta,
      inverterEfficiency: invEta,
      inverterAcCapRemainingKwh: acRemainingKwh,
      inverterDcCapRemainingKwh: dcRemainingKwh,
      edgeMaxPowerKwh: edgeMaxPowerKwh,
    );

DcBusInput _hybrid({
  double pvDcInKwh = 0.0,
  double loadAcShareKwh = 0.0,
  List<DcBusBattery>? batteries,
  HybridInverterInfo? busInverter,
}) =>
    DcBusInput(
      busId: 'dc-1',
      mode: BusMode.hybrid,
      pvDcInKwh: pvDcInKwh,
      loadAcShareKwh: loadAcShareKwh,
      batteries: batteries ?? const [],
      stepHours: 1.0,
      busInverter: busInverter ?? _inv(),
    );

void main() {
  const solver = DcBusSolver();

  group('DcBusSolver — single-bus allocation order', () {
    test('hybrid + empty battery: load covered first, surplus charges, leftover exports', () {
      final outcome = solver.solve(_hybrid(
        pvDcInKwh: 10.0,
        loadAcShareKwh: 2.0,
        batteries: [_battery(chargeRateKwh: 5.0)],
        busInverter: _inv(acRemainingKwh: 10.0),
      ));
      // Load takes 2 kWh AC = 2 kWh bus-side (η=1).
      expect(outcome.loadCoveredAcKwh, closeTo(2.0, 1e-9));
      // Battery takes its 5 kWh rate cap.
      expect(outcome.batteryChargesDcKwh[0], closeTo(5.0, 1e-9));
      // Remaining 3 kWh bypass to AC.
      expect(outcome.bypassAcKwh, closeTo(3.0, 1e-9));
      // Inverter consumed 5 kWh AC total (2 load + 3 bypass).
      expect(outcome.inverterAcConsumedKwh, closeTo(5.0, 1e-9));
      expect(outcome.curtailedDcKwh, closeTo(0.0, 1e-9));
    });

    test('hybrid + full battery: all surplus exports, no curtail when AC cap is enough', () {
      final outcome = solver.solve(_hybrid(
        pvDcInKwh: 4.0,
        batteries: [_battery(headroomStoredKwh: 0.0)],
        busInverter: _inv(acRemainingKwh: 10.0),
      ));
      expect(outcome.batteryChargesDcKwh, isEmpty);
      expect(outcome.bypassAcKwh, closeTo(4.0, 1e-9));
      expect(outcome.curtailedDcKwh, closeTo(0.0, 1e-9));
    });

    test('hybrid + full battery + tight AC cap: residual curtails', () {
      final outcome = solver.solve(_hybrid(
        pvDcInKwh: 10.0,
        batteries: [_battery(headroomStoredKwh: 0.0)],
        busInverter: _inv(acRemainingKwh: 4.0),
      ));
      // Inverter only emits 4 kWh AC → bus-side DC consumed = 4 kWh.
      // Remaining 6 kWh DC is curtailed.
      expect(outcome.bypassAcKwh, closeTo(4.0, 1e-9));
      expect(outcome.curtailedDcKwh, closeTo(6.0, 1e-9));
      expect(outcome.inverterAcConsumedKwh, closeTo(4.0, 1e-9));
    });

    test('lossy bus→inverter edge: bus-side DC converts to AC × edge.η × inv.η', () {
      // Edge η = 0.5, inverter own η = 0.9 ⇒ acPerBusDc = 0.45.
      final outcome = solver.solve(_hybrid(
        pvDcInKwh: 4.0,
        batteries: [_battery(headroomStoredKwh: 0.0)],
        busInverter: _inv(edgeEta: 0.5, invEta: 0.9, acRemainingKwh: 100.0),
      ));
      expect(outcome.bypassAcKwh, closeTo(4.0 * 0.5 * 0.9, 1e-9));
      // DC consumed = bus-side amount (4 kWh).
      expect(outcome.inverterDcConsumedKwh, closeTo(4.0, 1e-9));
    });

    test('batteryFed: load coverage is not allowed; PV goes to battery or curtails', () {
      final inputBatteryFed = DcBusInput(
        busId: 'dc-1',
        mode: BusMode.batteryFed,
        pvDcInKwh: 5.0,
        loadAcShareKwh: 1.0, // ignored
        batteries: [_battery(chargeRateKwh: 3.0)],
        stepHours: 1.0,
        busInverter: _inv(acRemainingKwh: 100.0),
      );
      final outcome = solver.solve(inputBatteryFed);
      expect(outcome.loadCoveredAcKwh, closeTo(0.0, 1e-9));
      expect(outcome.bypassAcKwh, closeTo(0.0, 1e-9));
      expect(outcome.batteryChargesDcKwh[0], closeTo(3.0, 1e-9));
      expect(outcome.curtailedDcKwh, closeTo(2.0, 1e-9));
    });

    test('two batteries share the bus inverter AC cap on discharge', () {
      // No PV, just load → batteries must discharge through one
      // 5 kWh-AC-cap inverter. Combined output ≤ 5 kWh AC.
      final outcome = solver.solve(_hybrid(
        loadAcShareKwh: 100.0, // huge load
        batteries: [
          _battery(index: 0, dischargeRateKwh: 5.0, usableStoredKwh: 20.0),
          _battery(index: 1, dischargeRateKwh: 5.0, usableStoredKwh: 20.0),
        ],
        busInverter: _inv(acRemainingKwh: 5.0),
      ));
      final combinedAc = outcome.dischargeAcKwh;
      expect(combinedAc, lessThanOrEqualTo(5.0 + 1e-9));
      final combinedDc = outcome.batteryDischargesDcKwh.values
          .fold<double>(0.0, (a, b) => a + b);
      expect(combinedDc, closeTo(5.0, 1e-9));
    });

    test('chargeTarget caps charging below available DC', () {
      final outcome = solver.solve(_hybrid(
        pvDcInKwh: 10.0,
        batteries: [_battery(chargeTargetKwh: 2.5)],
        busInverter: _inv(acRemainingKwh: 100.0),
      ));
      expect(outcome.batteryChargesDcKwh[0], closeTo(2.5, 1e-9));
      // The rest bypasses to AC.
      expect(outcome.bypassAcKwh, closeTo(7.5, 1e-9));
    });

    test('inverter DC input cap binds before AC cap', () {
      // 10 kWh on bus, inverter has only 2 kWh DC input headroom.
      final outcome = solver.solve(_hybrid(
        pvDcInKwh: 10.0,
        batteries: [_battery(headroomStoredKwh: 0.0)],
        busInverter:
            _inv(acRemainingKwh: 100.0, dcRemainingKwh: 2.0),
      ));
      expect(outcome.bypassAcKwh, closeTo(2.0, 1e-9));
      expect(outcome.curtailedDcKwh, closeTo(8.0, 1e-9));
    });

    test('edge.maxPowerKw binds before inverter caps when tighter', () {
      // Edge limit 1.5 kWh < inverter 5 kWh DC input.
      final outcome = solver.solve(_hybrid(
        pvDcInKwh: 10.0,
        batteries: [_battery(headroomStoredKwh: 0.0)],
        busInverter: _inv(
          acRemainingKwh: 100.0,
          dcRemainingKwh: 5.0,
          edgeMaxPowerKwh: 1.5,
        ),
      ));
      expect(outcome.bypassAcKwh, closeTo(1.5, 1e-9));
      expect(outcome.curtailedDcKwh, closeTo(8.5, 1e-9));
    });

    test('charge-only hybrid bus (no busInverter) curtails PV beyond battery', () {
      final outcome = solver.solve(DcBusInput(
        busId: 'dc-1',
        mode: BusMode.hybrid,
        pvDcInKwh: 5.0,
        loadAcShareKwh: 1.0, // can't be served — no inverter
        batteries: [_battery(chargeRateKwh: 2.0)],
        stepHours: 1.0,
      ));
      expect(outcome.batteryChargesDcKwh[0], closeTo(2.0, 1e-9));
      expect(outcome.bypassAcKwh, closeTo(0.0, 1e-9));
      expect(outcome.loadCoveredAcKwh, closeTo(0.0, 1e-9));
      expect(outcome.curtailedDcKwh, closeTo(3.0, 1e-9));
    });
  });

  group('DcBusSolver — bus energy balance invariant', () {
    void checkBalance(DcBusInput input) {
      final out = solver.solve(input);
      final chargesDc =
          out.batteryChargesDcKwh.values.fold<double>(0.0, (a, b) => a + b);
      final dischargesDc = out.batteryDischargesDcKwh.values
          .fold<double>(0.0, (a, b) => a + b);
      // Bus DC ledger: PV-in plus battery discharge equals what got
      // stored, plus what passed through the inverter (load + bypass
      // + discharge AC, summed back to bus-side as `inverterDcConsumed`),
      // plus curtailment.
      final balance = input.pvDcInKwh +
          dischargesDc -
          chargesDc -
          out.inverterDcConsumedKwh;
      expect(balance, closeTo(out.curtailedDcKwh, 1e-9),
          reason: 'bus DC ledger must balance');
      // No negative numbers.
      expect(out.bypassAcKwh, greaterThanOrEqualTo(-1e-12));
      expect(out.loadCoveredAcKwh, greaterThanOrEqualTo(-1e-12));
      expect(out.dischargeAcKwh, greaterThanOrEqualTo(-1e-12));
      expect(out.curtailedDcKwh, greaterThanOrEqualTo(-1e-12));
      // Inverter AC consumed never exceeds its remaining headroom.
      final invAcCap =
          input.busInverter?.inverterAcCapRemainingKwh ?? double.infinity;
      expect(out.inverterAcConsumedKwh,
          lessThanOrEqualTo(invAcCap + 1e-9));
      // Bus-side DC at the inverter never exceeds DC / edge caps.
      final dcCap = input.busInverter?.inverterDcCapRemainingKwh ??
          double.infinity;
      final edgeCap =
          input.busInverter?.edgeMaxPowerKwh ?? double.infinity;
      expect(out.inverterDcConsumedKwh, lessThanOrEqualTo(dcCap + 1e-9));
      expect(out.inverterDcConsumedKwh, lessThanOrEqualTo(edgeCap + 1e-9));
      // Battery rate / target / headroom caps.
      for (final b in input.batteries) {
        final c = out.batteryChargesDcKwh[b.batteryIndex] ?? 0.0;
        final d = out.batteryDischargesDcKwh[b.batteryIndex] ?? 0.0;
        expect(c, lessThanOrEqualTo(b.chargeRateCapKwh + 1e-9));
        expect(c, lessThanOrEqualTo(b.chargeTargetKwh + 1e-9));
        expect(c * b.chargeEfficiency,
            lessThanOrEqualTo(b.headroomStoredKwh + 1e-9));
        expect(d, lessThanOrEqualTo(b.dischargeRateCapKwh + 1e-9));
        expect(d, lessThanOrEqualTo(b.dischargeTargetKwh + 1e-9));
        if (b.dischargeEfficiency > 0) {
          expect(d / b.dischargeEfficiency,
              lessThanOrEqualTo(b.usableStoredKwh + 1e-9));
        }
      }
    }

    test('invariants hold across hand-picked edge cases', () {
      // 1. Plain hybrid, empty battery, lossless.
      checkBalance(_hybrid(
        pvDcInKwh: 5.0,
        loadAcShareKwh: 1.5,
        batteries: [_battery()],
      ));
      // 2. Tight AC cap.
      checkBalance(_hybrid(
        pvDcInKwh: 12.0,
        batteries: [_battery(headroomStoredKwh: 1.0)],
        busInverter: _inv(acRemainingKwh: 3.0),
      ));
      // 3. Two batteries, partial discharge.
      checkBalance(_hybrid(
        loadAcShareKwh: 8.0,
        batteries: [
          _battery(index: 0, dischargeRateKwh: 3.0, usableStoredKwh: 5.0),
          _battery(index: 1, dischargeRateKwh: 3.0, usableStoredKwh: 5.0),
        ],
        busInverter: _inv(acRemainingKwh: 4.5),
      ));
      // 4. Lossy edge, lossy inverter, tight DC cap.
      checkBalance(_hybrid(
        pvDcInKwh: 9.0,
        loadAcShareKwh: 1.0,
        batteries: [_battery(chargeTargetKwh: 2.0)],
        busInverter: _inv(
            edgeEta: 0.95,
            invEta: 0.92,
            acRemainingKwh: 4.0,
            dcRemainingKwh: 5.0),
      ));
      // 5. batteryFed mode.
      checkBalance(DcBusInput(
        busId: 'dc-1',
        mode: BusMode.batteryFed,
        pvDcInKwh: 4.0,
        loadAcShareKwh: 5.0,
        batteries: [_battery(chargeRateKwh: 1.5)],
        stepHours: 1.0,
        busInverter: _inv(acRemainingKwh: 100.0),
      ));
      // 6. No PV, only load + discharge.
      checkBalance(_hybrid(
        loadAcShareKwh: 3.0,
        batteries: [_battery(usableStoredKwh: 4.0)],
        busInverter: _inv(acRemainingKwh: 100.0),
      ));
      // 7. Charge-only hybrid bus (no busInverter).
      checkBalance(DcBusInput(
        busId: 'dc-1',
        mode: BusMode.hybrid,
        pvDcInKwh: 7.0,
        loadAcShareKwh: 0.0,
        batteries: [_battery(chargeRateKwh: 4.0)],
        stepHours: 1.0,
      ));
    });
  });
}
