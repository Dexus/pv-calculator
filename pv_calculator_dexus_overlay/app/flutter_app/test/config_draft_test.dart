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

    test('switching scheduleKind selects which editor state is built', () {
      // Editor state for both kinds lives side-by-side; switching the
      // scheduleKind flips which one buildSchedule() returns without
      // discarding the other.
      final factors = List<double>.filled(24, 0.7);
      final bank = MicroInverterBank(
        id: 'bank-1',
        batteryId: 'b1',
        unitRatedPowerW: 800,
        schedule: HourlySchedule(factors),
      );
      final draft = MicroInverterBankDraft.fromBank(bank);
      expect(draft.scheduleKind, BankScheduleKind.hourly);
      draft.windows.add(TimeWindowDraft(startHour: 18, endHour: 22, factor: 1.0));
      draft.scheduleKind = BankScheduleKind.timeWindows;
      expect(draft.build().schedule, isA<TimeWindowSchedule>());
      draft.scheduleKind = BankScheduleKind.hourly;
      expect(draft.build().schedule, isA<HourlySchedule>());
      // Hourly factors preserved through the round-trip via scheduleKind.
      expect((draft.build().schedule as HourlySchedule).factors, factors);
    });
  });

  group('Phase-5 pre-run fields', () {
    test('defaults match engine defaults', () {
      final draft = ConfigDraft();
      expect(draft.preRunMode, PreRunMode.singleWarmUp);
      expect(draft.convergenceToleranceFraction, 0.005);
      expect(draft.maxConvergenceIterations, 10);
    });

    test('build() forwards pre-run fields to SimulationConfig', () {
      final draft = ConfigDraft.demo()
        ..preRunMode = PreRunMode.cyclicConvergence
        ..preRunDays = 0
        ..days = 365
        ..convergenceToleranceFraction = 0.002
        ..maxConvergenceIterations = 6;
      final config = draft.build();
      expect(config.preRunMode, PreRunMode.cyclicConvergence);
      expect(config.convergenceToleranceFraction, 0.002);
      expect(config.maxConvergenceIterations, 6);
    });

    test('fromConfig() round-trips pre-run fields', () {
      final original = SimulationConfig(
        arrays: ConfigDraft.demo().build().arrays,
        inverters: ConfigDraft.demo().build().inverters,
        batteries: ConfigDraft.demo().build().batteries,
        loadProfile: ConfigDraft.demo().build().loadProfile,
        days: 365,
        preRunMode: PreRunMode.manual,
        convergenceToleranceFraction: 0.01,
        maxConvergenceIterations: 3,
      );
      final draft = ConfigDraft.fromConfig(original);
      expect(draft.preRunMode, PreRunMode.manual);
      expect(draft.convergenceToleranceFraction, 0.01);
      expect(draft.maxConvergenceIterations, 3);
    });
  });
}
