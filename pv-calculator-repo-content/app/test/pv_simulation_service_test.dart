import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator/domain/models.dart';
import 'package:pv_calculator/services/pv_simulation_service.dart';

void main() {
  test('simulation creates hourly steps and non-negative energy values', () {
    const config = SimulationConfig(
      projectName: 'Test',
      days: 2,
      usePreRunYear: false,
      arrays: [
        PvArray(name: 'Array', peakKw: 2, tiltDeg: 30, azimuthDeg: 0, lossPercent: 10, inverterId: 'main'),
      ],
      inverters: [
        Inverter(id: 'main', role: InverterRole.grid, acLimitKw: 1.5),
      ],
      battery: Battery(
        capacityKwh: 4,
        initialSocKwh: 2,
        minSocKwh: 0.5,
        maxChargeKw: 1,
        maxDischargeKw: 1,
        roundTripEfficiency: 0.9,
      ),
      loadProfile: LoadProfile([0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]),
    );

    final result = PvSimulationService().simulate(config);

    expect(result.steps, hasLength(48));
    expect(result.summary.acPvKwh, greaterThan(0));
    expect(result.summary.gridImportKwh, greaterThanOrEqualTo(0));
    expect(result.summary.finalSocKwh, greaterThanOrEqualTo(config.battery!.minSocKwh));
  });
}
