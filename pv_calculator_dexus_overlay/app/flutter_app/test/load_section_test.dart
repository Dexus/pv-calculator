import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/load_section.dart';

import '_test_localization.dart';

void main() {
  testWidgets('renders the CSV import button', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ProjectController(),
        child: germanMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(child: LoadSection()),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('load-csv-import')), findsOneWidget);
  });

  testWidgets('mutating the hourly shape switches the hint to the summary line',
      (tester) async {
    final controller = ProjectController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: germanMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(child: LoadSection()),
          ),
        ),
      ),
    );
    // Default shape — hint is rendered, no summary line.
    expect(find.byKey(const Key('load-hourly-summary')), findsNothing);

    // Replace the shape with one that differs from the default. After
    // `notifyListeners`, the section should swap hint for summary.
    final shape = List<double>.filled(24, 0.0);
    shape[12] = 1.5;
    controller.draft.loadProfile.dailyKwh = 1.5;
    controller.draft.loadProfile.hourlyShape = shape;
    controller.touch();
    await tester.pump();

    expect(find.byKey(const Key('load-hourly-summary')), findsOneWidget);
  });
}
