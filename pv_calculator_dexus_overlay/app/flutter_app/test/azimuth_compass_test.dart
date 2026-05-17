import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pv_calculator_app/widgets/azimuth_compass.dart';

void main() {
  testWidgets('tap on the west edge sets azimuth ≈ 270°', (tester) async {
    double? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: AzimuthCompass(
            azimuthDeg: 0,
            onChanged: (v) => captured = v,
            size: 200,
          ),
        ),
      ),
    ));

    // Centre of the dial is at the centre of the 200×200 box. The
    // tap-down handler converts touch position into engine azimuth
    // (0 = N, 90 = E, 180 = S, 270 = W). A tap due west of centre
    // should produce 270°.
    final compassCenter = tester.getCenter(find.byType(AzimuthCompass));
    await tester.tapAt(compassCenter + const Offset(-60, 0));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!, closeTo(270.0, 0.5));

    // Tap due north (top of the dial).
    await tester.tapAt(compassCenter + const Offset(0, -60));
    await tester.pump();
    expect(captured!, closeTo(0.0, 0.5));
  });
}
