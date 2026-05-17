import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/scenario_comparison_controller.dart';
import '../widgets/results/scenario_compare_chart.dart';
import '../widgets/results/scenario_compare_table.dart';

/// Phase-7 scenario comparison page. Takes its selection from the
/// [ScenarioComparisonController] in the widget tree; the projects tab
/// populates the selection before pushing this page.
///
/// On first build it triggers `resolve()` so the user doesn't have to
/// click a "Run" button — comparison without numbers is uninteresting.
class ScenarioComparePage extends StatefulWidget {
  const ScenarioComparePage({super.key});

  @override
  State<ScenarioComparePage> createState() => _ScenarioComparePageState();
}

class _ScenarioComparePageState extends State<ScenarioComparePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScenarioComparisonController>().resolve();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScenarioComparisonController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Szenariovergleich')),
      body: _body(context, controller),
    );
  }

  Widget _body(BuildContext context, ScenarioComparisonController c) {
    if (c.running) {
      return const Center(child: CircularProgressIndicator());
    }
    final err = c.error;
    if (err != null) {
      return _placeholder(context, Icons.error_outline, err);
    }
    final entries = c.entries;
    if (entries == null) {
      return _placeholder(context, Icons.hourglass_empty, 'Wird vorbereitet…');
    }
    if (entries.isEmpty) {
      return _placeholder(
        context,
        Icons.compare_arrows,
        'Wähle mindestens zwei Szenarien aus dem Projekte-Tab.',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'KPIs',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ScenarioCompareTable(entries: entries),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Energiebilanz im Vergleich',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ScenarioCompareChart(entries: entries),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context, IconData icon, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: scheme.outline),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
