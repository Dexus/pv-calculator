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

## Phase 3 – Fachliche Genauigkeit

- PVGIS-/Wetterdaten-Adapter.
- Temperatur- und Verlustmodelle.
- MPPT-/String-nahe Wechselrichtermodellierung.
- Referenzvergleiche gegen bekannte Tools oder Messdaten.

## Phase 4 – Produktqualität

- Design, Validierung, Fehlermeldungen.
- CSV/JSON/PDF-Export.
- Release-Prozess und Dokumentation.
