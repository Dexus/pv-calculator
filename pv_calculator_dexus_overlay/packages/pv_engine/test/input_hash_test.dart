import 'dart:convert';

import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

SimulationConfig _baseConfig({
  List<BatteryConfig>? batteries,
  double dailyKwh = 12.0,
}) {
  return SimulationConfig(
    arrays: const [
      PvArray(
        id: 'a1',
        label: 'Roof',
        peakKw: 5.0,
        azimuthDeg: 180,
        tiltDeg: 30,
        inverterId: 'inv1',
      ),
    ],
    inverters: const [
      Inverter(id: 'inv1', label: 'Main', maxAcKw: 5.0),
    ],
    batteries: batteries ??
        const [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 10,
            maxChargeKw: 3,
            maxDischargeKw: 3,
          ),
        ],
    loadProfile: LoadProfile(dailyKwh: dailyKwh),
  );
}

void main() {
  group('canonicalJsonEncode', () {
    test('sorts map keys deterministically', () {
      final a = canonicalJsonEncode({'b': 1, 'a': 2, 'c': 3});
      final b = canonicalJsonEncode({'c': 3, 'a': 2, 'b': 1});
      expect(a, equals(b));
      expect(a, equals('{"a":2,"b":1,"c":3}'));
    });

    test('recurses into nested maps and lists', () {
      final canonical = canonicalJsonEncode({
        'z': [
          {'y': 1, 'x': 2},
        ],
        'a': {
          'q': 1,
          'p': 2,
        },
      });
      expect(canonical, equals('{"a":{"p":2,"q":1},"z":[{"x":2,"y":1}]}'));
    });
  });

  group('fnv1a64Hex', () {
    test('returns a stable 16-character lowercase hex string', () {
      final hash = fnv1a64Hex('hello');
      expect(hash, hasLength(16));
      expect(hash, matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('differs for inputs that differ by one byte', () {
      expect(fnv1a64Hex('hello'), isNot(fnv1a64Hex('hellO')));
    });

    test('empty string maps to the FNV-1a offset basis', () {
      expect(fnv1a64Hex(''), equals('cbf29ce484222325'));
    });
  });

  group('SimulationConfig.inputHash', () {
    test('is deterministic across re-encoding round trips', () {
      final cfg = _baseConfig();
      final fromJson = SimulationConfig.fromJson(cfg.toJson());
      expect(cfg.inputHash, equals(fromJson.inputHash));
    });

    test('changes when a meaningful input changes', () {
      final low = _baseConfig(dailyKwh: 8.0).inputHash;
      final high = _baseConfig(dailyKwh: 12.0).inputHash;
      expect(low, isNot(high));
    });

    test('changes when battery list order changes', () {
      const a = BatteryConfig(
        id: 'b1',
        capacityKwh: 10,
        maxChargeKw: 3,
        maxDischargeKw: 3,
      );
      const b = BatteryConfig(
        id: 'b2',
        capacityKwh: 20,
        maxChargeKw: 5,
        maxDischargeKw: 5,
      );
      final forward = _baseConfig(batteries: const [a, b]).inputHash;
      final reversed = _baseConfig(batteries: const [b, a]).inputHash;
      expect(forward, isNot(reversed));
    });

    test('survives a JSON encode → decode → re-encode loop', () {
      final cfg = _baseConfig();
      final first = cfg.inputHash;
      final encoded = jsonEncode(cfg.toJson());
      final decoded =
          SimulationConfig.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
      final second = decoded.inputHash;
      expect(first, equals(second));
    });
  });

  test('kEngineVersion is a non-empty semver-ish string', () {
    expect(kEngineVersion, isNotEmpty);
    expect(kEngineVersion, matches(RegExp(r'^\d+\.\d+\.\d+')));
  });
}
