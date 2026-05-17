import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/dispatch_policy_section.dart';

import '_test_localization.dart';

void main() {
  testWidgets('switching to BatteryReserve reveals the reserve-fraction field', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ProjectController(),
        child: germanMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(child: DispatchPolicySection()),
          ),
        ),
      ),
    );

    // Default policy is SelfConsumptionFirst — the reserve field must
    // not exist yet.
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dispatch-policy-reserve-fraction')), findsNothing);

    // Open the dropdown and pick "Speicherreserve".
    await tester.tap(find.byKey(const Key('dispatch-policy-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speicherreserve').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dispatch-policy-reserve-fraction')), findsOneWidget);
  });

  testWidgets('GridAssist reveals the import-allowed toggle', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ProjectController(),
        child: germanMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(child: DispatchPolicySection()),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dispatch-policy-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Netz-Assist').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dispatch-policy-grid-import')), findsOneWidget);
  });

  testWidgets('draft.dispatchPolicy reflects the dropdown choice', (tester) async {
    final controller = ProjectController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: germanMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(child: DispatchPolicySection()),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dispatch-policy-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('24h-Konstanteinspeisung').last);
    await tester.pumpAndSettle();

    expect(controller.draft.dispatchPolicy.kind, DispatchPolicyKind.constantFeed24h);
  });
}
