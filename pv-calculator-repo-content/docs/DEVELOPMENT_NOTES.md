# Entwicklungsnotizen

## Bisherige Arbeit

- PRD und Architekturkonzept wurden als eigenstaendige Dokumente skizziert.
- Ein All-in-One-HTML-Quick-Example wurde erstellt.
- Die erste HTML-Version wurde durch eine v3-Fixed-Version ersetzt.
- Die korrigierte Version soll direkt beim Oeffnen simulieren, Fehler im UI anzeigen und einen Runtime-Smoke-Test bestanden haben.

## Wichtigste fachliche Punkte

- Mehrere PV-Arrays.
- Mehrere Wechselrichterrollen.
- 800-W-Micro-Inverter-Szenarien.
- Batterie mit SOC-Fortschreibung.
- Optionales Pre-Run-Jahr.
- 24h-Ausgangsprofile.
- Stuendliche und spaeter 15-Minuten-Simulation.
- Import/Export.
- Abregelung.
- Tages-/Jahresauswertung.
- CSV-/JSON-Export.
- Lokale Speicherung.

## Einordnung

Der Prototyp ist funktional, aber noch kein belastbarer technischer PV-Rechner. Fuer Produktionsqualitaet braucht es reale Wetter-/Irradiance-Daten, Geraetekennlinien, MPPT-/Stringmodellierung, Temperaturmodelle und Netzregeln.

## Repository-Ziel

Das GitHub-Repository wird die zentrale Ablage fuer Dokumente und Code. Chat-Artefakte sollen in versionierbare Dateien ueberfuehrt werden, damit spaetere Aenderungen nachvollziehbar bleiben.
