import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/main.dart';

void main() {
  testWidgets('renders project editor scaffold', (tester) async {
    await tester.pumpWidget(const PvCalculatorApp());
    await tester.pumpAndSettle();
    expect(find.text('PV Calculator'), findsOneWidget);
    expect(find.text('Projekt'), findsOneWidget);
    expect(find.text('Projektname'), findsOneWidget);
  });
}
