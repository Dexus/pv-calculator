import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('transposeToPoa (isotropic)', () {
    test('flat horizontal returns the horizontal global', () {
      final h = const HorizontalIrradianceSample(
        globalHorizontalWPerM2: 600,
        diffuseHorizontalWPerM2: 200,
        ambientTempC: 20,
      );
      final out = transposeToPoa(
        h: h,
        tiltDeg: 0,
        azimuthDeg: 180,
        latitudeDeg: 52.0,
        dayOfYear: 172, // summer solstice noon
        hourOfDay: 12.0,
      );
      // On a flat surface the ground term vanishes and the diffuse stays
      // 100 %, so POA must equal GHI within float noise.
      expect(out.poaWPerM2, closeTo(h.globalHorizontalWPerM2, 1e-6));
      expect(out.ambientTempC, equals(20));
    });

    test('south-facing 30 deg tilt at 52 N noon midsummer beats horizontal', () {
      final h = const HorizontalIrradianceSample(
        globalHorizontalWPerM2: 700,
        diffuseHorizontalWPerM2: 200,
        ambientTempC: 22,
      );
      final out = transposeToPoa(
        h: h,
        tiltDeg: 30,
        azimuthDeg: 180,
        latitudeDeg: 52.0,
        dayOfYear: 172,
        hourOfDay: 12.0,
      );
      // A 30-deg tilt facing the sun must collect at least as much as
      // horizontal at solar noon on the summer solstice — the geometric
      // gain on beam easily outweighs the small diffuse loss.
      expect(out.poaWPerM2, greaterThan(h.globalHorizontalWPerM2));
      // Sanity ceiling: no transposition should claim more than ~30 % above
      // the horizontal global at these mild conditions.
      expect(out.poaWPerM2, lessThan(h.globalHorizontalWPerM2 * 1.3));
    });

    test('north-facing 90 deg wall sees only diffuse + ground reflected', () {
      final h = const HorizontalIrradianceSample(
        globalHorizontalWPerM2: 800,
        diffuseHorizontalWPerM2: 250,
        ambientTempC: 18,
      );
      final out = transposeToPoa(
        h: h,
        tiltDeg: 90,
        azimuthDeg: 0, // facing north
        latitudeDeg: 52.0,
        dayOfYear: 172,
        hourOfDay: 12.0,
      );
      // No direct beam onto a north-facing vertical wall at solar noon on
      // the summer solstice (sun is roughly south). All POA must come from
      // the (halved) diffuse dome plus ground reflection.
      final expectedDiffuse = h.diffuseHorizontalWPerM2 * 0.5;
      final expectedGround = h.globalHorizontalWPerM2 * 0.2 * 0.5;
      expect(out.poaWPerM2, closeTo(expectedDiffuse + expectedGround, 1.0));
    });

    test('night returns zero POA without throwing', () {
      final h = const HorizontalIrradianceSample(
        globalHorizontalWPerM2: 0,
        diffuseHorizontalWPerM2: 0,
        ambientTempC: 5,
      );
      final out = transposeToPoa(
        h: h,
        tiltDeg: 30,
        azimuthDeg: 180,
        latitudeDeg: 52.0,
        dayOfYear: 355,
        hourOfDay: 23.5,
      );
      expect(out.poaWPerM2, equals(0));
      expect(out.ambientTempC, equals(5));
    });

    test('east-facing tilt collects more morning than evening', () {
      final h = const HorizontalIrradianceSample(
        globalHorizontalWPerM2: 400,
        diffuseHorizontalWPerM2: 120,
        ambientTempC: 15,
      );
      final morning = transposeToPoa(
        h: h,
        tiltDeg: 30,
        azimuthDeg: 90, // east
        latitudeDeg: 52.0,
        dayOfYear: 80,
        hourOfDay: 8.0,
      );
      final evening = transposeToPoa(
        h: h,
        tiltDeg: 30,
        azimuthDeg: 90, // east
        latitudeDeg: 52.0,
        dayOfYear: 80,
        hourOfDay: 17.0,
      );
      // Beam projection drops off when the sun moves behind the module.
      expect(morning.poaWPerM2, greaterThan(evening.poaWPerM2));
    });
  });
}
