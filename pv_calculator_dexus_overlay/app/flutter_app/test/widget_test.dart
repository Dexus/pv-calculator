import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/main.dart';
import 'package:pv_calculator_app/widgets/project_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('mounts the project list landing page on first launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PvCalculatorApp());
    await tester.pumpAndSettle();

    expect(find.byType(ProjectListPage), findsOneWidget);
    expect(find.text('PV Calculator — Projekte'), findsOneWidget);
    expect(find.text('Noch keine Projekte gespeichert.'), findsOneWidget);
  });
}
