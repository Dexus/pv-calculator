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
- `app/flutter_app`: `ProjectController` (ChangeNotifier) + `ConfigDraft` als mutierbare Arbeitskopie der unveränderlichen Engine-Typen. Eingabeformulare (`widgets/forms/`), Ergebnisansicht mit KPI-Karten und Monats-Tabelle (`widgets/results/`), Projekt-Listing (`widgets/project_list_page.dart`). Geocoding-Adapter (`services/geocoding.dart`) bindet OpenStreetMap Nominatim explizit hinter einem `GeocodingService`-Interface ein — keine Auto-Suche bei Tastendruck, fester `User-Agent`, 1 s Mindestabstand zwischen Anfragen (Usage-Policy).
- `docs`: Anforderungen, Architektur, Roadmap, technische Entscheidungen.

## Persistenz

Zwei nebeneinanderliegende Wege:

- `lib/persistence/project_store.dart` — `shared_preferences` als Projektliste mit Index-Schlüssel `pv_project_index` und Einträgen `pv_project:<name>`. Funktioniert auf Web (localStorage), Desktop und Mobile gleichermaßen.
- `lib/persistence/file_io.dart` — `file_selector` für JSON-/CSV-Datei-Export und JSON-Import. Auf Web löst `getSaveLocation`+`XFile.saveTo` einen Browser-Download aus (kein Dateipfad); auf nativen Plattformen erscheint der OS-Dialog.

Legacy-Migration: `SimulationConfig.fromJson` akzeptiert auch die alte 0.1-Form mit einzelnem `"battery"`-Feld und überführt sie in eine `batteries`-Liste mit synthetischer ID `battery-1`.

## Externe Datenquellen

Die Engine definiert eine `IrradianceSource`-Abstraktion (`packages/pv_engine/lib/src/weather.dart`):

- `SyntheticIrradianceSource` — Demo-Fallback (sin/Jahreszeit/Orientierung), liefert konstant 25 °C Ambient — keine reale Vorhersage.
- `HourlyWeatherSeries` — 365×24 Stunden pro Array-ID, vorgehalten im Speicher.
- `parsePvgisHourlyJson` — reiner Dart-Parser für PVGIS-`seriescalc`-JSON. `PvgisHourlyData.toAveragedYear()` faltet mehrjährige Daten auf ein 8760-TMY zusammen.

HTTP-Aufrufe gegen PVGIS gehören NICHT in die Engine (keine Runtime-Deps). Die Flutter-App oder ein Kommandozeilen-Tool kann PVGIS abfragen und das JSON via `parsePvgisHourlyJson` einspeisen.

Temperaturmodell: `NoctTemperatureModel` (Default) oder `FaimanTemperatureModel`, beide als pure Strategien ohne State.

MPPT-/String-Clipping: `Inverter.maxDcInputKw` cappt die aggregierte DC-Energie pro Wechselrichter vor der AC-Konversion. Reale Gerätekennlinien bleiben Folgearbeit.

Per-Inverter-AC-Cap (Phase 4, Architektur-Doc §5.3): `BatteryCouplingSpec.inverterId` koppelt eine Batterie optional an einen expliziten Batterie-Wechselrichter. Ist das Feld gesetzt, verwendet `EnergyRouter` dessen `effectiveMaxAcKw` als gemeinsame AC-Obergrenze für Direkt-Discharge und alle Banks dieser Batterie — entsprechend `min(targetPowerW, battery.maxDischargeW, inverterLimitW)`. Ohne Feld fällt der Router auf `BatteryConfig.maxDischargeKw` als AC-Cap zurück, womit Pre-Phase-4-Projekte ihre Ergebnisse unverändert behalten.

## Teststrategie

- Engine-Unit-Tests: Dispatch (inkl. Mehrfach-Batterie-Reihenfolge), SOC-Grenzen, 800-W-Microkappung, Export-Limit, Lastprofil, JSON-Roundtrip pro Typ, Monats-Bucket-Summen, CSV-Format.
- Widget-Tests: Editor-Validierung (Run-Button disabled bei invalider Konfiguration), Run-Flow → Ergebnisseite, Projektliste rendert leer korrekt.
- Persistence-Tests: `shared_preferences` mit `setMockInitialValues({})`, Save/List/Load/Delete und Sonderfälle.
- Regressionstests mit Beispielkonfigurationen.

## Manueller Multi-Plattform-Smoke-Build

`.github/workflows/smoke.yml` (nur `workflow_dispatch`, schont das Free-Tier-Minutenkontingent) baut den Flutter-Client für Web, Linux, Android, macOS, iOS und Windows und führt das Engine-Beispiel als Ende-zu-Ende-Smoke aus. Triggern über GitHub → Actions → „Multi-platform smoke build" → „Run workflow".
