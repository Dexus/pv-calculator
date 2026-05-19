import 'package:flutter/material.dart';

/// App-wide theme tokens.
///
/// Phase-8 a11y/design-system first pass (NFR-07): consistent tap-target
/// sizing (≥ 48×48 — WCAG 2.5.5), a visible focus ring on input fields
/// (WCAG 1.4.11), and rounded card surfaces. Deeper work (full 200%
/// scale support, Dynamic Colors, external UX audit) stays deferred —
/// see ROADMAP §Phase 8 → Verschoben.
///
/// The seed (`Colors.amber`) and `useMaterial3: true` flag are preserved
/// from the previous inline `_buildTheme` in `main.dart` so the existing
/// color palette stays unchanged.
ThemeData buildAppTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.amber,
    brightness: brightness,
  );
  final buttonPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: const OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(padding: buttonPadding),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(padding: buttonPadding),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(padding: buttonPadding),
    ),
  );
}
