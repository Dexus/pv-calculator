# PV Calculator

Dieses Repository enthält den vorhandenen HTML/PVGIS-Prototypen und wird schrittweise zu einer Flutter-App mit testbarer Pure-Dart-Simulations-Engine ausgebaut.

## Ausgangspunkt

- `pv_calculator_pvgis_clientv4pgis.html`: vorhandener HTML-Prototyp mit PVGIS-Import, PV+Speicher und 800-W-Wechselrichter-Simulation.
- `packages/pv_engine`: neue Pure-Dart-Simulations-Engine als Grundlage für Tests und spätere Flutter-Nutzung.
- `app/flutter_app`: minimales Flutter-Gerüst mit Demo-KPIs.
- `AGENTS.md`: Projektregeln für Codex.
- `docs/`: PRD, Architektur, Roadmap und konkrete Codex-Aufgaben.

## Entwicklungsstrategie

Die bestehende HTML-Datei bleibt als fachliche Referenz erhalten. Die eigentliche Produktentwicklung wird getrennt in:

1. `packages/pv_engine` – Pure-Dart-Domain-Logik und Simulation.
2. `app/flutter_app` – Flutter-Oberfläche, Eingaben, Auswertung und Persistenz.

Die UI darf keine Kernberechnungen enthalten. Simulation, Batterie-Dispatch, Wechselrichterbegrenzung, 800-W-Micro-Inverter-Kappung, SOC-Carry-over und Export/Import müssen im Engine-Paket testbar bleiben.

## Engine prüfen

```bash
cd packages/pv_engine
dart pub get
dart analyze
dart test
dart run bin/example.dart
```

## Flutter-App prüfen

```bash
cd app/flutter_app
flutter pub get
flutter analyze
flutter test
flutter run
```

Falls Flutter-Plattformordner fehlen:

```bash
cd app/flutter_app
flutter create --platforms=android,ios,web .
flutter pub get
flutter run
```

## Erster Codex-Prompt

```text
Lies AGENTS.md, docs/PRD.md, docs/ARCHITECTURE.md und pv_calculator_pvgis_clientv4pgis.html. Prüfe packages/pv_engine und app/flutter_app. Führe dart pub get, dart analyze, dart test sowie flutter pub get, flutter analyze und flutter test aus. Behebe Compile-, Analyzer- und Testfehler minimalinvasiv. Verschiebe keine Simulationslogik in die Flutter-UI. Erstelle danach einen Pull Request mit einem stabilen ersten Entwicklungsstand.
```

## Modellhinweis

Die neue Engine nutzt zunächst ein synthetisches Einstrahlungsmodell. Sie ist für Architektur, Dispatch-Logik und UI-Entwicklung gedacht, aber noch kein validierter technischer PV-Ertragsrechner. Für Produktionsqualität müssen PVGIS-/Irradiance-Daten, Temperaturmodelle, reale Wechselrichterkennlinien, MPPT-Stränge, Verschattung und Netzregeln ergänzt werden.
