import 'package:flutter/material.dart';

import 'domain/models.dart';
import 'services/pv_simulation_service.dart';

void main() {
  runApp(const PvCalculatorApp());
}

class PvCalculatorApp extends StatelessWidget {
  const PvCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final result = PvSimulationService().simulate(demoConfig);

    return MaterialApp(
      title: 'PV Calculator',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('PV Calculator')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(demoConfig.projectName, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            _KpiGrid(summary: result.summary),
            const SizedBox(height: 24),
            Text('Erste 24 Stunden', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _StepsTable(steps: result.steps.take(24).toList()),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.summary});

  final SimulationSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = <String, String>{
      'AC-PV': '${summary.acPvKwh.toStringAsFixed(0)} kWh',
      'Netzbezug': '${summary.gridImportKwh.toStringAsFixed(0)} kWh',
      'Einspeisung': '${summary.feedInKwh.toStringAsFixed(0)} kWh',
      'Autarkie': '${summary.autarkyPercent.toStringAsFixed(1)} %',
    };

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.entries.map((entry) {
        return Card(
          child: SizedBox(
            width: 170,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key),
                  const SizedBox(height: 8),
                  Text(entry.value, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StepsTable extends StatelessWidget {
  const _StepsTable({required this.steps});

  final List<SimulationStep> steps;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Stunde')),
        DataColumn(label: Text('PV')),
        DataColumn(label: Text('Last')),
        DataColumn(label: Text('Import')),
        DataColumn(label: Text('SOC')),
      ],
      rows: steps.map((step) {
        return DataRow(cells: [
          DataCell(Text('${step.hour}')),
          DataCell(Text(step.acPvKwh.toStringAsFixed(2))),
          DataCell(Text(step.loadKwh.toStringAsFixed(2))),
          DataCell(Text(step.gridImportKwh.toStringAsFixed(2))),
          DataCell(Text(step.socKwh.toStringAsFixed(2))),
        ]);
      }).toList(),
    );
  }
}

const demoConfig = SimulationConfig(
  projectName: 'PV Calculator Demo',
  days: 365,
  usePreRunYear: true,
  arrays: [
    PvArray(name: 'Sued Dach', peakKw: 5.2, tiltDeg: 35, azimuthDeg: 0, lossPercent: 10, inverterId: 'main'),
    PvArray(name: 'Ost Dach', peakKw: 2.4, tiltDeg: 25, azimuthDeg: -90, lossPercent: 12, inverterId: 'main'),
    PvArray(name: 'Balkon 800W', peakKw: 1.1, tiltDeg: 20, azimuthDeg: 20, lossPercent: 8, inverterId: 'micro800'),
  ],
  inverters: [
    Inverter(id: 'main', role: InverterRole.grid, acLimitKw: 6.0),
    Inverter(id: 'micro800', role: InverterRole.micro800, acLimitKw: 0.8),
    Inverter(id: 'batteryOut', role: InverterRole.batteryOutput, acLimitKw: 0.8),
  ],
  battery: Battery(
    capacityKwh: 9.6,
    initialSocKwh: 4.8,
    minSocKwh: 0.5,
    maxChargeKw: 3.0,
    maxDischargeKw: 3.0,
    roundTripEfficiency: 0.92,
  ),
  loadProfile: LoadProfile([0.45, 0.38, 0.34, 0.32, 0.35, 0.52, 0.85, 0.95, 0.75, 0.62, 0.58, 0.62, 0.70, 0.72, 0.65, 0.68, 0.82, 1.15, 1.35, 1.12, 0.92, 0.72, 0.62, 0.52]),
);
