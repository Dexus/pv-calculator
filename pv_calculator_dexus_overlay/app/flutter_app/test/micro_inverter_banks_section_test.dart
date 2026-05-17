import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/micro_inverter_banks_section.dart';

import '_test_localization.dart';

void main() {
  testWidgets('starts empty and shows the empty state message once expanded', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ProjectController(),
        child: germanMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(child: MicroInverterBanksSection()),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    // Subtitle says "Keine Bänke konfiguriert" plus the body message — both render now.
    expect(find.textContaining('Keine Bänke konfiguriert'), findsWidgets);
  });

  testWidgets('tapping Add inserts a bank pre-filled with the demo battery id', (tester) async {
    final controller = ProjectController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: germanMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(child: MicroInverterBanksSection()),
          ),
        ),
      ),
    );
    // Section starts collapsed when no banks exist.
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-bank-button')));
    await tester.pumpAndSettle();
    expect(controller.draft.microInverterBanks, hasLength(1));
    expect(controller.draft.microInverterBanks.first.batteryId,
        equals(controller.draft.batteries.first.id),
        reason: 'should default to the first available battery');
  });
}
