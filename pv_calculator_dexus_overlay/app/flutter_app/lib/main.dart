import 'package:flutter/material.dart';
import 'package:pv_engine/pv_engine.dart';

void main() => runApp(const PvCalculatorApp());

class PvCalculatorApp extends StatelessWidget {
  const PvCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PV Calculator',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.amber),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late SimulationResult _result;

  @override
  void initState() {
    super.initState();
    _result = const PvSimulator().run(_config());
  }

  void _runAgain() {
    setState(() => _result = const PvSimulator().run(_config()));
  }

  @override
  Widget build(BuildContext context) {
    final s = _result.summary;
    return Scaffold(
      appBar: AppBar(title: const Text('PV Calculator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Demo-Simulation', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Synthetisches Demo-Modell mit PV-Arrays, 800-W-Micro-Inverter und Batterie-SOC-Carry-over.'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _KpiCard(label: 'PV AC', value: '${s.pvAcKwh.toStringAsFixed(0)} kWh'),
              _KpiCard(label: 'Last', value: '${s.loadKwh.toStringAsFixed(0)} kWh'),
              _KpiCard(label: 'Eigenverbrauch', value: '${s.selfConsumptionKwh.toStringAsFixed(0)} kWh'),
              _KpiCard(label: 'Netzimport', value: '${s.gridImportKwh.toStringAsFixed(0)} kWh'),
              _KpiCard(label: 'Netzeinspeisung', value: '${s.gridExportKwh.toStringAsFixed(0)} kWh'),
              _KpiCard(label: 'Abregelung', value: '${s.curtailedKwh.toStringAsFixed(0)} kWh'),
              _KpiCard(label: 'Autarkie', value: '${(s.autarkyRate * 100).toStringAsFixed(1)} %'),
              _KpiCard(label: 'EV-Quote', value: '${(s.selfConsumptionRate * 100).toStringAsFixed(1)} %'),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _runAgain, icon: const Icon(Icons.play_arrow), label: const Text('Simulation erneut starten')),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ]),
        ),
      ),
    );
  }
}

SimulationConfig _config() {
  return SimulationConfig(
    arrays: const [
      PvArray(id: 'south-roof', label: 'Süddach', peakKw: 4.8, azimuthDeg: 180, tiltDeg: 35, inverterId: 'main'),
      PvArray(id: 'balcony', label: 'Balkon', peakKw: 1.2, azimuthDeg: 180, tiltDeg: 30, inverterId: 'micro'),
    ],
    inverters: const [
      Inverter(id: 'main', label: 'Hauptwechselrichter', maxAcKw: 5.0),
      Inverter(id: 'micro', label: '800-W-Micro-Inverter', maxAcKw: 0.8, role: InverterRole.microInverter800W),
    ],
    battery: const BatteryConfig(capacityKwh: 7.5, maxChargeKw: 3.0, maxDischargeKw: 3.0, minSocKwh: 0.5),
    loadProfile: const LoadProfile(dailyKwh: 10.5),
    days: 365,
    preRunDays: 365,
    gridExportLimitKw: 6.0,
    latitudeDeg: 50.1,
  );
}
