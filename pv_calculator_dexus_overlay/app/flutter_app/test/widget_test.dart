import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/main.dart';

void main() {
  testWidgets('renders dashboard', (tester) async {
    await tester.pumpWidget(const PvCalculatorApp());
    expect(find.text('PV Calculator'), findsOneWidget);
    expect(find.text('Demo-Simulation'), findsOneWidget);
  });
}
