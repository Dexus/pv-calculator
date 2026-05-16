# Architektur – PV Calculator

## Prinzip

Domain first: Die Simulationslogik liegt in `packages/pv_engine` und bleibt unabhängig von Flutter testbar. Die Flutter-App sammelt Eingaben, zeigt Ergebnisse und speichert Projekte.

```text
Flutter UI
  ↓
Application State / View Models
  ↓
packages/pv_engine
  ├─ Domain Models
  ├─ Synthetic Solar Fallback
  ├─ Inverter Limiting
  ├─ Battery Dispatch
  └─ Simulation Summary
  ↓
Data Adapters / Persistence / APIs
```

## Module

- `packages/pv_engine`: PV-Arrays, Wechselrichter, **Liste von Batterien**, Lastprofil, `SimulationConfig`, `PvSimulator`, Ergebniszusammenfassung, `SummaryAggregator` (Monatsbuckets), `stepsCsv`/`monthlyCsv` (CSV-Export). JSON-Serialisierung (`toJson`/`fromJson`) auf allen Domain-Typen — keine externen Runtime-Abhängigkeiten.
- `app/flutter_app`: `ProjectController` (ChangeNotifier) + `ConfigDraft` als mutierbare Arbeitskopie der unveränderlichen Engine-Typen. Eingabeformulare (`widgets/forms/`), Ergebnisansicht mit KPI-Karten und Monats-Tabelle (`widgets/results/`), Projekt-Listing (`widgets/project_list_page.dart`).
- `docs`: Anforderungen, Architektur, Roadmap, technische Entscheidungen.

## Persistenz

Zwei nebeneinanderliegende Wege:

- `lib/persistence/project_store.dart` — `shared_preferences` als Projektliste mit Index-Schlüssel `pv_project_index` und Einträgen `pv_project:<name>`. Funktioniert auf Web (localStorage), Desktop und Mobile gleichermaßen.
- `lib/persistence/file_io.dart` — `file_selector` für JSON-/CSV-Datei-Export und JSON-Import. Auf Web löst `getSaveLocation`+`XFile.saveTo` einen Browser-Download aus (kein Dateipfad); auf nativen Plattformen erscheint der OS-Dialog.

Legacy-Migration: `SimulationConfig.fromJson` akzeptiert auch die alte 0.1-Form mit einzelnem `"battery"`-Feld und überführt sie in eine `batteries`-Liste mit synthetischer ID `battery-1`.

## Externe Datenquellen

PVGIS, Wetterdaten, reale Gerätekennlinien und Lastprofilimporte sollen später als Adapter ergänzt werden. Die Engine darf nicht direkt von UI oder API-Implementierungen abhängen.

## Teststrategie

- Engine-Unit-Tests: Dispatch (inkl. Mehrfach-Batterie-Reihenfolge), SOC-Grenzen, 800-W-Microkappung, Export-Limit, Lastprofil, JSON-Roundtrip pro Typ, Monats-Bucket-Summen, CSV-Format.
- Widget-Tests: Editor-Validierung (Run-Button disabled bei invalider Konfiguration), Run-Flow → Ergebnisseite, Projektliste rendert leer korrekt.
- Persistence-Tests: `shared_preferences` mit `setMockInitialValues({})`, Save/List/Load/Delete und Sonderfälle.
- Regressionstests mit Beispielkonfigurationen.

## Manueller Multi-Plattform-Smoke-Build

`.github/workflows/smoke.yml` (nur `workflow_dispatch`, schont das Free-Tier-Minutenkontingent) baut den Flutter-Client für Web, Linux, Android, macOS, iOS und Windows und führt das Engine-Beispiel als Ende-zu-Ende-Smoke aus. Triggern über GitHub → Actions → „Multi-platform smoke build" → „Run workflow".
