# PV Calculator

Dieses Repository ist die zentrale Ablage fuer die Entwicklung des PV Calculator: Dokumente, Prototypen, App-Code, Tests und spaeter Build-/Release-Artefakte werden hier versioniert.

## Aktueller Zweck

- Projektwissen nicht mehr nur im Chat oder in Einzeldateien halten.
- PRD, Architektur und Entwicklungsnotizen als Markdown versionierbar machen.
- Den HTML-Prototyp als schnelle Referenz sichern.
- Ein erstes Flutter/Dart-Codegeruest fuer Domain-Modelle und Simulation vorbereiten.

## Repository-Struktur

```text
.
├── README.md
├── docs/
│   ├── PRD.md
│   ├── ARCHITECTURE.md
│   ├── DEVELOPMENT_NOTES.md
│   ├── ROADMAP.md
│   ├── RESEARCH_NOTES.md
│   └── GITHUB_WORKFLOW.md
├── prototypes/
│   └── pv_calculator_quick_example.html
├── app/
│   ├── pubspec.yaml
│   ├── analysis_options.yaml
│   ├── lib/
│   │   ├── main.dart
│   │   ├── domain/
│   │   │   └── models.dart
│   │   └── services/
│   │       └── pv_simulation_service.dart
│   └── test/
│       └── pv_simulation_service_test.dart
└── scripts/
    └── commit_to_repo.sh
```

## Status

Dieses Paket ist als erster strukturierter Repository-Import gedacht. Der HTML-Prototyp ist funktional, die Flutter-App ist ein bewusst schlankes Startgeruest. Die Simulationslogik ist noch nicht als belastbarer technischer PV-Rechner zu betrachten, sondern als Grundlage fuer die weitere Implementierung.

## Quick Start

### HTML-Prototyp lokal oeffnen

```bash
open prototypes/pv_calculator_quick_example.html
```

oder die Datei im Browser per Doppelklick oeffnen.

### Flutter-Code vorbereiten

```bash
cd app
flutter pub get
flutter test
flutter run
```

## Lizenz

Das Repository ist mit der GNU Affero General Public License v3.0 lizenziert. Bei spaeterem Betrieb als Web-/Backend-Service muss die Quellcode-Bereitstellung gemaess AGPL-Anforderungen beachtet werden.
