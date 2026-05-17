import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_engine/pv_engine.dart';

void main() {
  group('MicroInverterBankDraft.fromBank / build round-trip', () {
    test('AlwaysOnSchedule round-trips', () {
      const bank = MicroInverterBank(
        id: 'bank-1',
        batteryId: 'b1',
        unitRatedPowerW: 800,
        schedule: AlwaysOnSchedule(),
      );
      final rebuilt = MicroInverterBankDraft.fromBank(bank).build();
      expect(rebuilt.schedule, isA<AlwaysOnSchedule>());
    });

    test('TimeWindowSchedule round-trips through editable windows', () {
      const bank = MicroInverterBank(
        id: 'bank-1',
        batteryId: 'b1',
        unitRatedPowerW: 800,
        schedule: TimeWindowSchedule([
          TimeWindow(startHour: 18, endHour: 22, factor: 1.0),
          TimeWindow(startHour: 6, endHour: 9, factor: 0.5),
        ]),
      );
      final draft = MicroInverterBankDraft.fromBank(bank);
      expect(draft.windows, hasLength(2));
      final rebuilt = draft.build();
      final sched = rebuilt.schedule;
      expect(sched, isA<TimeWindowSchedule>());
      final windows = (sched as TimeWindowSchedule).windows;
      expect(windows[0].startHour, 18);
      expect(windows[0].endHour, 22);
      expect(windows[1].factor, 0.5);
    });

    test('HourlySchedule is preserved through round-trip (regression)', () {
      // Codex review caught: fromBank used to silently drop hourly
      // schedules and buildSchedule re-emitted AlwaysOn.
      final factors = List<double>.generate(24, (i) => i < 12 ? 0.0 : 1.0);
      final bank = MicroInverterBank(
        id: 'bank-1',
        batteryId: 'b1',
        unitRatedPowerW: 800,
        schedule: HourlySchedule(factors),
      );
      final rebuilt = MicroInverterBankDraft.fromBank(bank).build();
      expect(rebuilt.schedule, isA<HourlySchedule>());
      expect((rebuilt.schedule as HourlySchedule).factors, factors);
    });

    test('adding a window after loading an hourly schedule replaces it', () {
      final factors = List<double>.filled(24, 1.0);
      final bank = MicroInverterBank(
        id: 'bank-1',
        batteryId: 'b1',
        unitRatedPowerW: 800,
        schedule: HourlySchedule(factors),
      );
      final draft = MicroInverterBankDraft.fromBank(bank);
      draft.windows.add(TimeWindowDraft(startHour: 18, endHour: 22, factor: 1.0));
      final rebuilt = draft.build();
      expect(rebuilt.schedule, isA<TimeWindowSchedule>());
    });
  });
}
