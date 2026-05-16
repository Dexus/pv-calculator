import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SimulationConfig.validate', () {
    test('rejects out-of-range days, preRunDays, startDayOfYear, latitudeDeg', () {
      expect(() => _config(days: 0).validate(), throwsArgumentError);
      expect(() => _config(days: 366).validate(), throwsArgumentError);
      expect(() => _config(preRunDays: -1).validate(), throwsArgumentError);
      expect(() => _config(preRunDays: 366).validate(), throwsArgumentError);
      expect(() => _config(startDayOfYear: 0).validate(), throwsArgumentError);
      expect(() => _config(startDayOfYear: 366).validate(), throwsArgumentError);
      expect(() => _config(latitudeDeg: -91).validate(), throwsArgumentError);
      expect(() => _config(latitudeDeg: 91).validate(), throwsArgumentError);
    });

    test('accepts the boundary values inclusively', () {
      _config(days: 1, preRunDays: 0, startDayOfYear: 1, latitudeDeg: -90).validate();
      _config(days: 365, preRunDays: 365, startDayOfYear: 365, latitudeDeg: 90).validate();
    });

    test('PvArray and Inverter reject whitespace-only ids', () {
      expect(
        () => const PvArray(id: '  ', label: 'X', peakKw: 1, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i').validate(),
        throwsArgumentError,
      );
      expect(
        () => const Inverter(id: '  ', label: 'X', maxAcKw: 1).validate(),
        throwsArgumentError,
      );
    });

    test('PvArray.fromJson and Inverter.fromJson trim ids on decode', () {
      final array = PvArray.fromJson({
        'id': '  roof  ', 'label': 'Roof', 'peakKw': 1.0,
        'azimuthDeg': 180.0, 'tiltDeg': 35.0, 'inverterId': '  main  ',
        'lossFactor': 0.14, 'shadingFactor': 0.0,
      });
      expect(array.id, 'roof');
      expect(array.inverterId, 'main');

      final inverter = Inverter.fromJson({
        'id': '  main  ', 'label': 'Main', 'maxAcKw': 5.0,
        'role': 'grid', 'efficiency': 0.965,
      });
      expect(inverter.id, 'main');
    });
  });
}

SimulationConfig _config({
  int days = 1,
  int preRunDays = 0,
  int startDayOfYear = 1,
  double latitudeDeg = 50.0,
}) =>
    SimulationConfig(
      arrays: const [
        PvArray(id: 'r', label: 'R', peakKw: 1.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
      ],
      inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 1.0)],
      loadProfile: const LoadProfile(dailyKwh: 1),
      days: days,
      preRunDays: preRunDays,
      startDayOfYear: startDayOfYear,
      latitudeDeg: latitudeDeg,
    );
