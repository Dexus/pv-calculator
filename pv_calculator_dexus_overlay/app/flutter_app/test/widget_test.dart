import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/main.dart';
import 'package:pv_calculator_app/widgets/forms/arrays_section.dart';
import 'package:pv_calculator_app/widgets/forms/batteries_section.dart';
import 'package:pv_calculator_app/widgets/forms/editor_page.dart';
import 'package:pv_calculator_app/widgets/forms/inverters_section.dart';
import 'package:pv_calculator_app/widgets/forms/load_section.dart';
import 'package:pv_calculator_app/widgets/forms/project_section.dart';

void main() {
  testWidgets('mounts the editor page with all configuration sections', (tester) async {
    // Tall viewport so every section in the ListView is built and laid out.
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PvCalculatorApp());
    await tester.pumpAndSettle();

    expect(find.byType(EditorPage), findsOneWidget);
    expect(find.byType(ProjectSection), findsOneWidget);
    expect(find.byType(InvertersSection), findsOneWidget);
    expect(find.byType(ArraysSection), findsOneWidget);
    expect(find.byType(BatteriesSection), findsOneWidget);
    expect(find.byType(LoadSection), findsOneWidget);
  });
}
