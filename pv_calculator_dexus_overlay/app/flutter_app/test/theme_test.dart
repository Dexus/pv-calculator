import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/theme.dart';

void main() {
  group('buildAppTheme', () {
    test('uses Material 3 with the amber-seeded ColorScheme', () {
      final theme = buildAppTheme(Brightness.light);
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.light);

      final dark = buildAppTheme(Brightness.dark);
      expect(dark.colorScheme.brightness, Brightness.dark);
    });

    test('IconButtonTheme enforces a 48×48 minimum tap target', () {
      final theme = buildAppTheme(Brightness.light);
      final style = theme.iconButtonTheme.style;
      expect(style, isNotNull);
      final minSize =
          style!.minimumSize?.resolve(const <WidgetState>{});
      expect(minSize, const Size(48, 48));
      expect(style.tapTargetSize, MaterialTapTargetSize.padded);
    });

    test('InputDecorationTheme provides a filled surface and a 2 px '
        'focused border for WCAG 1.4.11 non-text contrast', () {
      final theme = buildAppTheme(Brightness.light);
      final input = theme.inputDecorationTheme;
      expect(input.filled, isTrue);
      expect(input.fillColor, theme.colorScheme.surfaceContainerHighest);
      final focused = input.focusedBorder;
      expect(focused, isA<OutlineInputBorder>());
      expect((focused as OutlineInputBorder).borderSide.width, 2.0);
    });

    test('CardTheme uses a single-elevation rounded surface', () {
      final theme = buildAppTheme(Brightness.light);
      expect(theme.cardTheme.elevation, 1);
      final shape = theme.cardTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
    });

    test('Filled/Outlined/Text button themes apply a 16×12 padding', () {
      final theme = buildAppTheme(Brightness.light);
      const expected = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      final filled =
          theme.filledButtonTheme.style?.padding?.resolve(const <WidgetState>{});
      final outlined = theme.outlinedButtonTheme.style?.padding
          ?.resolve(const <WidgetState>{});
      final text =
          theme.textButtonTheme.style?.padding?.resolve(const <WidgetState>{});
      expect(filled, expected);
      expect(outlined, expected);
      expect(text, expected);
    });
  });
}
