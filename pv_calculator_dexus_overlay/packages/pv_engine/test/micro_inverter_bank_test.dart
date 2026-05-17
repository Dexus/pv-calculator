import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('BankSchedule', () {
    test('AlwaysOnSchedule returns 1.0 for every hour', () {
      const s = AlwaysOnSchedule();
      for (var h = 0.0; h < 24.0; h += 0.5) {
        expect(s.factorAt(h), 1.0);
      }
    });

    test('HourlySchedule rejects wrong length and out-of-range', () {
      expect(() => HourlySchedule(const [0.5]).validate(), throwsArgumentError);
      expect(() => HourlySchedule(List<double>.filled(24, 1.5)).validate(), throwsArgumentError);
      expect(() => HourlySchedule(List<double>.filled(24, -0.1)).validate(), throwsArgumentError);
      HourlySchedule(List<double>.filled(24, 0.5)).validate();
    });

    test('HourlySchedule picks the right slot for a fractional hour', () {
      final s = HourlySchedule([for (var i = 0; i < 24; i++) i / 23.0]);
      expect(s.factorAt(0.0), closeTo(0.0, 1e-9));
      expect(s.factorAt(0.7), closeTo(0.0, 1e-9));
      expect(s.factorAt(12.5), closeTo(12 / 23.0, 1e-9));
      expect(s.factorAt(23.9), closeTo(1.0, 1e-9));
    });

    test('TimeWindowSchedule wraps midnight when start > end', () {
      const s = TimeWindowSchedule([
        TimeWindow(startHour: 22, endHour: 6),
      ]);
      expect(s.factorAt(23.0), 1.0);
      expect(s.factorAt(2.0), 1.0);
      expect(s.factorAt(6.0), 0.0);
      expect(s.factorAt(21.999), 0.0);
    });

    test('round-trips each schedule kind through JSON', () {
      final kinds = <BankSchedule>[
        const AlwaysOnSchedule(),
        HourlySchedule(List<double>.filled(24, 0.5)),
        const TimeWindowSchedule([
          TimeWindow(startHour: 18, endHour: 23),
          TimeWindow(startHour: 0, endHour: 6, factor: 0.5),
        ]),
      ];
      for (final s in kinds) {
        final json = s.toJson();
        final round = BankSchedule.fromJson(json);
        for (var h = 0.0; h < 24.0; h += 1.0) {
          expect(round.factorAt(h), closeTo(s.factorAt(h), 1e-9), reason: 'kind ${json['kind']} @ $h');
        }
      }
    });
  });

  group('MicroInverterBank', () {
    test('targetKwAt scales count × unit × schedule factor', () {
      const bank = MicroInverterBank(
        id: 'b1', batteryId: 'batt', count: 2, unitRatedPowerW: 800.0,
      );
      expect(bank.targetKwAt(12.0), closeTo(1.6, 1e-9));
    });

    test('validate rejects bad fields', () {
      expect(
        () => const MicroInverterBank(id: '', batteryId: 'b').validate(),
        throwsArgumentError,
      );
      expect(
        () => const MicroInverterBank(id: 'b', batteryId: '').validate(),
        throwsArgumentError,
      );
      expect(
        () => const MicroInverterBank(id: 'b', batteryId: 'x', count: -1).validate(),
        throwsArgumentError,
      );
      expect(
        () => const MicroInverterBank(id: 'b', batteryId: 'x', unitRatedPowerW: 0).validate(),
        throwsArgumentError,
      );
      expect(
        () => const MicroInverterBank(id: 'b', batteryId: 'x', minSocShutdown: -0.01).validate(),
        throwsArgumentError,
      );
      expect(
        () => const MicroInverterBank(id: 'b', batteryId: 'x', minSocShutdown: 1.01).validate(),
        throwsArgumentError,
      );
      expect(
        () => const MicroInverterBank(id: 'b', batteryId: 'x', inverterEfficiency: 0).validate(),
        throwsArgumentError,
      );
    });

    test('round-trips through JSON including the schedule', () {
      final bank = MicroInverterBank(
        id: 'pack-1',
        label: 'Garage',
        batteryId: 'b1',
        count: 1,
        unitRatedPowerW: 800,
        minSocShutdown: 0.1,
        inverterEfficiency: 0.92,
        schedule: const TimeWindowSchedule([TimeWindow(startHour: 18, endHour: 23)]),
      );
      final round = MicroInverterBank.fromJson(bank.toJson());
      expect(round.id, bank.id);
      expect(round.label, bank.label);
      expect(round.batteryId, bank.batteryId);
      expect(round.count, bank.count);
      expect(round.unitRatedPowerW, bank.unitRatedPowerW);
      expect(round.minSocShutdown, bank.minSocShutdown);
      expect(round.inverterEfficiency, bank.inverterEfficiency);
      expect(round.schedule.factorAt(20.0), 1.0);
      expect(round.schedule.factorAt(10.0), 0.0);
    });
  });
}
