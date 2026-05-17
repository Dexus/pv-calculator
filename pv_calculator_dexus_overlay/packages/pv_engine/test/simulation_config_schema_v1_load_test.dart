import 'dart:convert';

import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SimulationConfig schema migration', () {
    test('loads a v1 JSON payload without throwing', () {
      final json = jsonEncode({
        'schemaVersion': 1,
        'arrays': [
          {
            'id': 'south-roof',
            'label': 'South roof',
            'peakKw': 5.0,
            'azimuthDeg': 180.0,
            'tiltDeg': 30.0,
            'inverterId': 'inv-1',
          }
        ],
        'inverters': [
          {
            'id': 'inv-1',
            'label': 'Hybrid',
            'maxAcKw': 5.0,
            'role': 'grid',
            'efficiency': 0.97,
          }
        ],
        'batteries': const [],
        'loadProfile': {'dailyKwh': 10.0},
        'startDayOfYear': 1,
        'days': 365,
        'timeStep': 'hourly',
        'preRunDays': 0,
        'latitudeDeg': 52.0,
        'longitudeDeg': 7.5,
      });
      final config = SimulationConfig.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      expect(config.arrays, hasLength(1));
      expect(config.inverters.single.maxAcKw, 5.0);
      expect(config.latitudeDeg, 52.0);
    });

    test('round-trips through toJson/fromJson preserving all fields', () {
      final original = SimulationConfig(
        arrays: const [
          PvArray(
            id: 'a1',
            label: 'A1',
            peakKw: 3.0,
            azimuthDeg: 180,
            tiltDeg: 25,
            inverterId: 'inv-1',
          ),
        ],
        inverters: const [
          Inverter(id: 'inv-1', label: 'Inv', maxAcKw: 5.0),
        ],
        loadProfile: const LoadProfile(dailyKwh: 8),
      );
      final encoded = jsonEncode(original.toJson());
      final decoded = SimulationConfig.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(decoded.arrays.single.peakKw, 3.0);
    });

    test('refuses an unknown future schemaVersion', () {
      final json = {
        'schemaVersion': 99,
        'arrays': const [],
        'inverters': const [],
        'loadProfile': {'dailyKwh': 0.0},
      };
      expect(
        () => SimulationConfig.fromJson(json),
        throwsArgumentError,
      );
    });
  });
}
