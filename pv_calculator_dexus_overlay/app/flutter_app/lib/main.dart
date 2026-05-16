import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/project_controller.dart';
import 'widgets/project_list_page.dart';

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
        home: const ProjectListPage(),
      ),
    );
  }
}
