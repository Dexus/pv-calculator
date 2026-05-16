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
        themeMode: ThemeMode.system,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const ProjectListPage(),
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.amber,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(),
    ),
  );
}
