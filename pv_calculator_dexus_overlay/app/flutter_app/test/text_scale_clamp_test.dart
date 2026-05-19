import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke-tests the text-scale clamp inserted by
/// `PvCalculatorApp.builder` in `lib/main.dart`. The function is a
/// private top-level so the test inlines an equivalent builder — both
/// must stay in sync (any change to the clamp window in `main.dart`
/// also goes here).
void main() {
  testWidgets('app-wide text-scale clamp caps the system scale at 1.6×',
      (tester) async {
    double? observedScale;

    Widget clampingBuilder(BuildContext context, Widget? child) {
      final clamped = MediaQuery.textScalerOf(context).clamp(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.6,
      );
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: clamped),
        child: child ?? const SizedBox.shrink(),
      );
    }

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
        child: MaterialApp(
          builder: clampingBuilder,
          home: Builder(builder: (context) {
            observedScale = MediaQuery.textScalerOf(context).scale(10) / 10;
            return const SizedBox.shrink();
          }),
        ),
      ),
    );

    expect(observedScale, closeTo(1.6, 1e-9));
  });

  testWidgets('clamp leaves an unscaled (1×) value untouched',
      (tester) async {
    double? observedScale;

    Widget clampingBuilder(BuildContext context, Widget? child) {
      final clamped = MediaQuery.textScalerOf(context).clamp(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.6,
      );
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: clamped),
        child: child ?? const SizedBox.shrink(),
      );
    }

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.0)),
        child: MaterialApp(
          builder: clampingBuilder,
          home: Builder(builder: (context) {
            observedScale = MediaQuery.textScalerOf(context).scale(10) / 10;
            return const SizedBox.shrink();
          }),
        ),
      ),
    );

    expect(observedScale, closeTo(1.0, 1e-9));
  });
}
