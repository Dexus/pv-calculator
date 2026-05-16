# Roadmap

## Phase 1 – Repo-Codebasis

- `AGENTS.md` hinzufügen.
- Pure-Dart-Engine kompilierbar machen.
- Engine-Tests ausführen und ergänzen.
- Flutter-Projektgerüst prüfen.
- CI grün bekommen.

## Phase 2 – MVP-App ✓

- [x] Eingabemasken für PV-Arrays, Wechselrichter, Batterien (Mehrfach-Speicher) und Lastprofil.
- [x] Simulation starten und KPIs anzeigen.
- [x] Monats-Tabelle inkl. CSV-Export von Schritten und Monatswerten.
- [x] Projekt als JSON speichern/laden (lokale Liste über `shared_preferences`, plus Datei-Import/Export über `file_selector`).
- [x] Engine-API erweitert: `SimulationConfig.batteries` als Liste, schemaversionierte JSON-Serialisierung mit Legacy-Migration des einzelnen `battery`-Feldes.

## Phase 3 – Fachliche Genauigkeit ✓

- [x] PVGIS-/Wetterdaten-Adapter: `IrradianceSource`-Abstraktion, `SyntheticIrradianceSource` (Demo-Fallback), `HourlyWeatherSeries` (8760-Slots pro Array), `parsePvgisHourlyJson` für PVGIS-`seriescalc`-Dokumente, `PvgisHourlyData.toAveragedYear()` als TMY-Mittelwertbildung.
- [x] Temperatur-/Verlustmodelle: `NoctTemperatureModel` (Standard) und `FaimanTemperatureModel`. `PvArray.temperatureCoefficientPctPerC` (Default 0 für Rückwärtskompatibilität, z.B. -0.4 für kristallines Silizium) und `nominalOperatingCellTempC` (Default 45 °C).
- [x] MPPT-/String-nahe Wechselrichtermodellierung: `Inverter.maxDcInputKw` clippt DC-Energie vor der Wechselrichter-Effizienz und schreibt den Überschuss in `curtailedKwh`.
- [x] Referenzvergleiche: `reference_yield_test.dart` prüft 1-kWp-Süddach am 21.06. gegen einen 4–7 kWh-Korridor, plus 800-W-Microclipping- und Overcast-Tests. (Vollständige PVGIS-Live-Vergleiche bleiben Folgearbeit, weil CI keinen Netzzugriff hat.)
- [x] UI-Anbindung des PVGIS-JSON-Imports pro Modulfeld: `FileIo.importPvgisJson()`, `ConfigDraft.setArrayWeather/clearArrayWeather/renameArrayWeather`, neue `HourlyWeatherSeries(..., fallback: SyntheticIrradianceSource())`-Hybridquelle, damit Felder ohne Import auf das Demo-Modell zurückfallen. Importierte Reihen sind Session-Daten und werden bewusst nicht im Projekt-JSON persistiert.

## Phase 4 – Produktqualität

- Design, Validierung, Fehlermeldungen.
- CSV/JSON/PDF-Export.
- Release-Prozess und Dokumentation.
