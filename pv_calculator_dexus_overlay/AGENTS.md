# AGENTS.md

## Projektziel

Baue `Dexus/pv-calculator` von einem vorhandenen HTML-Prototypen zu einer Flutter-App mit testbarer Pure-Dart-Simulations-Engine aus.

Die App soll PV-Anlagen simulieren mit mehreren PV-Arrays, mehreren Wechselrichtern, 800-W-Micro-Inverter-/Steckersolar-Szenarien, Batteriespeicher mit SOC-Carry-over, optionalem Pre-Run-Jahr, 24h-Lastprofilen, stündlicher und später 15-Minuten-Simulation sowie Import, Export, Abregelung und Tages-/Monats-/Jahresauswertung.

## Vorhandene Referenz

Die Datei `pv_calculator_pvgis_clientv4pgis.html` ist die fachliche Referenz für den aktuellen Funktionsumfang. Behandle sie als Prototyp, nicht als produktionsreife Architektur.

## Repo-Struktur

- `pv_calculator_pvgis_clientv4pgis.html`: bestehender Prototyp, nicht löschen.
- `packages/pv_engine/`: Pure-Dart-Domain- und Simulationslogik.
- `app/flutter_app/`: Flutter-UI.
- `docs/`: PRD, Architektur, Roadmap und technische Entscheidungen.
- `.github/workflows/`: CI für Dart/Flutter.

## Architekturregeln

- Domain-Logik zuerst in `packages/pv_engine` implementieren.
- Flutter-Widgets dürfen Simulationsergebnisse anzeigen und Eingaben sammeln, aber keine Dispatch- oder PV-Kernberechnungen enthalten.
- Batterie-Dispatch, Wechselrichterbegrenzung, 800-W-Micro-Inverter-Kappung, SOC-Carry-over und Export/Import müssen separat testbar sein.
- Externe Datenquellen wie PVGIS oder Wetter-APIs nur über Adapter-Schichten integrieren.
- Keine API-Keys, Tokens oder Secrets committen.
- Synthetische Einstrahlung klar als Demo-/Fallback-Modell kennzeichnen.
- Bestehende AGPL-3.0-Lizenz beachten.

## Build-, Test- und Lint-Kommandos

Engine:

```bash
cd packages/pv_engine
dart pub get
dart analyze
dart test
dart run bin/example.dart
```

Flutter-App:

```bash
cd app/flutter_app
flutter pub get
flutter analyze
flutter test
```

Falls Plattformordner fehlen:

```bash
cd app/flutter_app
flutter create --platforms=android,ios,web .
flutter pub get
```

## Qualitätsregeln

- Jede fachliche Änderung an der Simulation braucht mindestens einen Unit-Test in `packages/pv_engine/test`.
- Ergebnisfelder müssen Energieflüsse nachvollziehbar machen: PV AC, Last, Eigenverbrauch, Batterie-Ladung, Batterie-Entladung, SOC, Netzimport, Netzeinspeisung, Abregelung.
- Tests sollen Toleranzen verwenden, keine exakten Floating-Point-Vergleiche.
- Keine neue externe Runtime-Abhängigkeit ohne klaren Grund.
- Dokumentiere bekannte Modellgrenzen in `docs/` oder im jeweiligen Code-Kommentar.

## Erste empfohlene Aufgabe

1. Repository lesen und bestehende HTML-Referenz verstehen.
2. `packages/pv_engine` kompilierbar machen.
3. Unit-Tests für SOC-Grenzen, 800-W-Kappung und Export-Limit ausführen/ergänzen.
4. Flutter-App-Gerüst lauffähig machen.
5. Pull Request erstellen, der klar beschreibt, was implementiert und was noch Demo-Modell ist.
