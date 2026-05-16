import 'package:pv_engine/pv_engine.dart';

void main() {
  final result = const PvSimulator().run(_demoConfig());
  final s = result.summary;
  print('PV AC: ${s.pvAcKwh.toStringAsFixed(0)} kWh');
  print('Load: ${s.loadKwh.toStringAsFixed(0)} kWh');
  print('Self consumption: ${s.selfConsumptionKwh.toStringAsFixed(0)} kWh');
  print('Grid import: ${s.gridImportKwh.toStringAsFixed(0)} kWh');
  print('Grid export: ${s.gridExportKwh.toStringAsFixed(0)} kWh');
  print('Curtailed: ${s.curtailedKwh.toStringAsFixed(0)} kWh');
  print('Autarky: ${(s.autarkyRate * 100).toStringAsFixed(1)}%');
  print('Final battery SOC per pack: ${s.finalBatterySocsKwh.map((v) => v.toStringAsFixed(2)).join(', ')}');
}

SimulationConfig _demoConfig() {
  return SimulationConfig(
    arrays: const [
      // Phase 3: temperature coefficient + NOCT now drive cell-temperature derating.
      PvArray(
        id: 'south-roof', label: 'Süddach', peakKw: 4.8,
        azimuthDeg: 180, tiltDeg: 35, inverterId: 'main',
        temperatureCoefficientPctPerC: -0.4,
        nominalOperatingCellTempC: 45,
      ),
      PvArray(
        id: 'balcony', label: 'Balkon', peakKw: 1.2,
        azimuthDeg: 180, tiltDeg: 30, inverterId: 'micro',
        temperatureCoefficientPctPerC: -0.4,
      ),
    ],
    inverters: const [
      // Phase 3: optional DC input cap models MPPT/string clipping.
      Inverter(id: 'main', label: 'Hauptwechselrichter', maxAcKw: 5.0, maxDcInputKw: 6.0),
      Inverter(id: 'micro', label: '800-W-Micro-Inverter', maxAcKw: 0.8, role: InverterRole.microInverter800W),
    ],
    batteries: const [
      BatteryConfig(id: 'main', label: 'Hauptspeicher', capacityKwh: 7.5, maxChargeKw: 3.0, maxDischargeKw: 3.0, minSocKwh: 0.5),
      BatteryConfig(id: 'secondary', label: 'Zweitspeicher', capacityKwh: 5.0, maxChargeKw: 2.0, maxDischargeKw: 2.0, minSocKwh: 0.2),
    ],
    loadProfile: const LoadProfile(dailyKwh: 10.5),
    days: 365,
    preRunDays: 365,
    gridExportLimitKw: 6.0,
    latitudeDeg: 50.1,
    // weatherSource: null → engine falls back to the SyntheticIrradianceSource
    // demo model. Plug an HourlyWeatherSeries built from PVGIS data here for
    // a measurement-driven run.
  );
}
