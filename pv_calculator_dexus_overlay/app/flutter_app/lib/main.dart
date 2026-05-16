import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/project_controller.dart';
import 'widgets/forms/editor_page.dart';
import 'widgets/results/results_page.dart';

void main() => runApp(const PvCalculatorApp());

class PvCalculatorApp extends StatelessWidget {
  const PvCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProjectController(),
      child: MaterialApp(
        title: 'PV Calculator',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.amber),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return EditorPage(
      onRunRequested: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (innerContext) => ChangeNotifierProvider<ProjectController>.value(
              value: context.read<ProjectController>(),
              child: const ResultsPage(),
            ),
          ),
        );
      },
    );
  }
}
