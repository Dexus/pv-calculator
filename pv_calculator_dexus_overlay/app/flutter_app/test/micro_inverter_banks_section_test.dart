import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/micro_inverter_banks_section.dart';
import 'package:pv_engine/pv_engine.dart';

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

  testWidgets('switching to Hourly reveals 24 factor fields with default 1.0', (tester) async {
    final controller = ProjectController();
    controller.draft.microInverterBanks.add(MicroInverterBankDraft(
      id: 'bank-1',
      batteryId: controller.draft.batteries.first.id,
    ));
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
    // Open the kind picker and select Hourly.
    await tester.tap(find.byKey(const Key('bank-bank-1-schedule-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stündlich (24 Werte)').last);
    await tester.pumpAndSettle();

    expect(controller.draft.microInverterBanks.first.scheduleKind,
        BankScheduleKind.hourly);
    // 24 hourly cells with stable keys (no value suffix, so typing
    // doesn't replace the NumberField mid-input).
    for (var h = 0; h < 24; h++) {
      expect(find.byKey(ValueKey('bank-bank-1-hourly-$h')), findsOneWidget);
    }
    expect(controller.draft.microInverterBanks.first.hourlyFactors,
        everyElement(equals(1.0)));
  });

  testWidgets('hourly factors round-trip when bank loaded with HourlySchedule', (tester) async {
    final controller = ProjectController();
    final factors = List<double>.generate(24, (i) => i < 12 ? 0.0 : 1.0);
    final bank = MicroInverterBank(
      id: 'bank-1',
      batteryId: controller.draft.batteries.first.id,
      unitRatedPowerW: 800,
      schedule: HourlySchedule(factors),
    );
    controller.draft.microInverterBanks.add(MicroInverterBankDraft.fromBank(bank));

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

    expect(controller.draft.microInverterBanks.first.scheduleKind,
        BankScheduleKind.hourly);
    // 24 cells render with stable keys regardless of value.
    expect(find.byKey(const ValueKey('bank-bank-1-hourly-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('bank-bank-1-hourly-13')), findsOneWidget);
    // Underlying state preserves the loaded factors.
    expect(controller.draft.microInverterBanks.first.hourlyFactors[0], 0.0);
    expect(controller.draft.microInverterBanks.first.hourlyFactors[13], 1.0);

    // Reset button restores all 24 cells to 1.0.
    await tester.ensureVisible(find.byKey(const Key('bank-bank-1-hourly-reset')));
    await tester.tap(find.byKey(const Key('bank-bank-1-hourly-reset')));
    await tester.pumpAndSettle();
    expect(controller.draft.microInverterBanks.first.hourlyFactors,
        everyElement(equals(1.0)));
  });
}
