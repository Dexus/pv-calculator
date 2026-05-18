# Architektur – PV Calculator

Verdichtete Overlay-Sicht. Kanonische Quelle inkl. vollständiger Energiefluss-Pipeline, Modulgrenzen, Datenmodell, Persistenz und Teststrategie: [`../../docs/Architekturkonzept_PV_Calculator_Flutter_App.md`](../../docs/Architekturkonzept_PV_Calculator_Flutter_App.md). SOC-Pre-Run-Methoden in §6, Per-Inverter-AC-Cap in §5.3 dort.

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

- `packages/pv_engine`: PV-Arrays, Wechselrichter, **Liste von Batterien**, Lastprofil, `SimulationConfig`, `PvSimulator`, Ergebniszusammenfassung, `SummaryAggregator` (Monatsbuckets inkl. €-Cashflow), `stepsCsv`/`monthlyCsv` (CSV-Export inkl. €-Spalten). JSON-Serialisierung (`toJson`/`fromJson`) auf allen Domain-Typen — keine externen Runtime-Abhängigkeiten.
- `packages/component_catalog`: Pure-Dart-Katalog von PV-Komponenten (Module, Wechselrichter, Batterien) zum Vorbefüllen der Eingabeformulare. Definiert `CatalogEntry`-Hierarchie, `CatalogSource`-Erweiterungspunkt, `MergedCatalog`-Komposition mit User-Overrides und einen Seed-JSON-Parser. Hat keine Engine- oder Flutter-Abhängigkeit; ein lokaler `CatalogInverterRole`-Enum spiegelt `pv_engine.InverterRole` 1:1 und wird im App-Layer abgebildet. Mitgelieferter Seed-Katalog (`assets/components_seed_v1.json`). Flutter-spezifische Adapter (`BundledSeedCatalogSource`, `SqliteUserCatalogSource`) und das `CatalogRepository` leben in der App unter `lib/catalog/`.
- `app/flutter_app`: `ProjectController` (ChangeNotifier) + `ConfigDraft` als mutierbare Arbeitskopie der unveränderlichen Engine-Typen. Eingabeformulare (`widgets/forms/`) inkl. Picker „Aus Bibliothek wählen" gegen `CatalogRepository`. Ergebnisansicht mit KPI-Karten und Monats-Tabelle (`widgets/results/`), Projekt-Listing (`widgets/project_list_page.dart`). Geocoding-Adapter (`services/geocoding.dart`) bindet OpenStreetMap Nominatim explizit hinter einem `GeocodingService`-Interface ein — keine Auto-Suche bei Tastendruck, fester `User-Agent`, 1 s Mindestabstand zwischen Anfragen (Usage-Policy).
- `docs`: Anforderungen, Architektur, Roadmap, technische Entscheidungen.

## Persistenz

Phase 7: relationaler `package:sqlite3`-Store als kanonische Projekt-/Szenario-DB plus zwei flankierende Wege:

- `lib/persistence/{database,schema,project_repository,scenario_repository,simulation_run_repository}.dart` — vier Tabellen (`projects`, `sites`, `scenarios`, `simulation_runs`) plus `app_meta(key, value)` für Versionierung und einmalige Migrationsmarker. Reines SQL, keine Codegen-Stufe. Auf Native (mobile/desktop) wird sqlite3 über `sqlite3_flutter_libs` als Bibliothek eingebunden; auf Web ist der Loader auf `package:sqlite3`-WASM mit OPFS/IndexedDB-Fallback vorbereitet (Asset-Wiring steht noch aus → ROADMAP §Phase 7 Verschoben).
- `lib/persistence/sp_migration.dart` — einmaliger Importpfad: liest die Legacy-`shared_preferences`-Einträge (`pv_project_index` + `pv_project:<name>`) und erzeugt pro Eintrag ein Projekt + Default-Szenario im neuen Schema. Idempotent über den `app_meta('sp_migrated_v1')`-Marker; die SP-Keys bleiben als Read-only-Fallback erhalten.
- `lib/persistence/project_store.dart` — Legacy `shared_preferences`-Adapter. Wird **nicht mehr** für Neueinträge verwendet, dient nur noch der SP-Migration als Lesepfad.
- `lib/persistence/file_io.dart` — `file_selector` für JSON-/CSV-Datei-Export und JSON-Import. Export schreibt ab Phase 7 in einem Envelope `{engineVersion, inputHash, config}` (PRD NFR-05); `parseImportedConfig` akzeptiert beide Formen, der Legacy-Bare-Config-Form fehlt der Hash, der wird beim Re-Import frisch berechnet.

Legacy-Migration: `SimulationConfig.fromJson` akzeptiert auch die alte 0.1-Form mit einzelnem `"battery"`-Feld und überführt sie in eine `batteries`-Liste mit synthetischer ID `battery-1`.

## Reproduzierbarkeit

Engine exportiert `kEngineVersion` (synchron mit `packages/pv_engine/pubspec.yaml`) und eine Extension `SimulationConfig.inputHash` (kanonisches JSON → 64-Bit FNV-1a, hex). Beide Werte werden in `scenarios.engine_version` / `scenarios.input_hash` und in jedem `simulation_runs`-Datensatz mitgeschrieben, ebenso im Export-Envelope. `ScenarioComparisonController` nutzt den Hash als Cache-Key: solange er stabil bleibt, wird der zuletzt gespeicherte `summary_json` wieder verwendet, statt die Engine erneut anzuwerfen.

## Externe Datenquellen

Die Engine definiert eine `IrradianceSource`-Abstraktion (`packages/pv_engine/lib/src/weather.dart`):

- `SyntheticIrradianceSource` — Demo-Fallback (sin/Jahreszeit/Orientierung), liefert konstant 25 °C Ambient — keine reale Vorhersage.
- `HourlyWeatherSeries` — 365×24 Stunden pro Array-ID, vorgehalten im Speicher.
- `parsePvgisHourlyJson` — reiner Dart-Parser für PVGIS-`seriescalc`-JSON. `PvgisHourlyData.toAveragedYear()` faltet mehrjährige Daten auf ein 8760-TMY zusammen.

HTTP-Aufrufe gegen PVGIS gehören NICHT in die Engine (keine Runtime-Deps). Die Flutter-App oder ein Kommandozeilen-Tool kann PVGIS abfragen und das JSON via `parsePvgisHourlyJson` einspeisen.

Temperaturmodell: `NoctTemperatureModel` (Default) oder `FaimanTemperatureModel`, beide als pure Strategien ohne State.

MPPT-/String-Clipping: `Inverter.maxDcInputKw` cappt die aggregierte DC-Energie pro Wechselrichter vor der AC-Konversion. Reale Gerätekennlinien bleiben Folgearbeit.

Per-Inverter-AC-Cap (Phase 4, Architektur-Doc §5.3): `BatteryCouplingSpec.inverterId` koppelt eine Batterie optional an einen expliziten Batterie-Wechselrichter. Ist das Feld gesetzt, verwendet `EnergyRouter` dessen `effectiveMaxAcKw` als gemeinsame AC-Obergrenze für Direkt-Discharge und alle Banks dieser Batterie — entsprechend `min(targetPowerW, battery.maxDischargeW, inverterLimitW)`. Ohne Feld fällt der Router auf `BatteryConfig.maxDischargeKw` als AC-Cap zurück, womit Pre-Phase-4-Projekte ihre Ergebnisse unverändert behalten.

SOC-Pre-Run (Phase 5, Architektur-Doc §6 und PRD §6.2): `SimulationConfig.preRunMode` wählt zwischen drei Strategien, ohne den Step-Dispatch zu ändern. **`PreRunMode.manual`** überspringt jeden Vorlauf und startet die Berichtsperiode direkt am `BatteryConfig.initialSocKwh` (oder 50 % als Default). **`PreRunMode.singleWarmUp`** (Default für Legacy-JSON) iteriert das bisherige `dayIndex ∈ [-preRunDays, days)`-Schema; Schritte mit `dayIndex < 0` propagieren den SOC, werden aber nicht in `SimulationResult.steps` geschrieben — Architektur §6 Schluss­satz „Der Pre-Run wird nicht in Jahres-KPIs eingerechnet" gilt unverändert. **`PreRunMode.cyclicConvergence`** wiederholt ein volles 365-Tage-Jahr in einem äußeren Loop, prüft nach jedem Zyklus pro Batterie `|startSoc - endSoc| ≤ convergenceToleranceFraction × (capacity − minSoc)` (Default 0,5 %) und bricht entweder bei Konvergenz oder nach `maxConvergenceIterations` ab; nur der finale Zyklus landet in den Ergebnissen. `SimulationSummary` ergänzt `preRunMode`, `preRunActive`, `startSocsUsedKwh`, `convergenceIterations`, `converged` für den im PRD geforderten Report. Die Engine kennt kein Pro-Konzept — cyclic convergence ist immer zulässig; UI-Gating erfolgt im Flutter-Layer per `--dart-define=PRO_FEATURES=true` (im Pages-Workflow aktiv, lokal/CI Standard aus). „Previous-Year Weather" aus Architektur §6 ist auf Phase 10 verschoben (Roadmap §Phase 5 → Verschoben).

## Teststrategie

- Engine-Unit-Tests: Dispatch (inkl. Mehrfach-Batterie-Reihenfolge), SOC-Grenzen, 800-W-Microkappung, Export-Limit, Lastprofil, JSON-Roundtrip pro Typ, Monats-Bucket-Summen, CSV-Format.
- Widget-Tests: Editor-Validierung (Run-Button disabled bei invalider Konfiguration), Run-Flow → Ergebnisseite, Projektliste rendert leer korrekt.
- Persistence-Tests: `shared_preferences` mit `setMockInitialValues({})`, Save/List/Load/Delete und Sonderfälle.
- Regressionstests mit Beispielkonfigurationen.

## Manueller Multi-Plattform-Smoke-Build

`.github/workflows/smoke.yml` (nur `workflow_dispatch`, schont das Free-Tier-Minutenkontingent) baut den Flutter-Client für Web, Linux, Android, macOS, iOS und Windows und führt das Engine-Beispiel als Ende-zu-Ende-Smoke aus. Triggern über GitHub → Actions → „Multi-platform smoke build" → „Run workflow".
