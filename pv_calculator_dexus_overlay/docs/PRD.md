# PRD – PV Calculator

Verdichtete MVP-Sicht. Kanonische Quelle inkl. funktionaler Anforderungen (FR-…), Akzeptanzkriterien, NFRs und User Stories: [`../../docs/PRD_PV_Calculator_Flutter_App.md`](../../docs/PRD_PV_Calculator_Flutter_App.md). SOC-/Pre-Run-Detail in §6.2 dort.

## Ziel

PV Calculator soll eine Flutter-App werden, die PV-Anlagen mit mehreren Arrays, Wechselrichtern und Batteriespeichern konfigurierbar simuliert.

## MVP-Funktionen

- Mehrere PV-Arrays mit kWp, Azimut, Neigung, Verlusten und Verschattung.
- Mehrere Wechselrichter mit AC-Grenze und Wirkungsgrad.
- 800-W-Micro-Inverter-/Steckersolar-Szenarien.
- Batteriespeicher mit Kapazität, Lade-/Entladeleistung, Wirkungsgrad, Mindest-SOC und SOC-Carry-over.
- Optionaler Pre-Run zur Stabilisierung des Start-SOC.
- 24h-Lastprofil und später Lastprofil-Import.
- Stündliche Simulation, später 15-Minuten-Auflösung.
- Tages-, Monats- und Jahresauswertung.
- Export als CSV/JSON.
- Lokales Speichern/Laden von Projekten.

## Nicht-Ziele der ersten Version

- Keine verbindliche technische Ertragsprognose.
- Keine Netzanschlussberatung.
- Keine Herstellergarantie für Gerätekennlinien.
- Keine API-Keys im Client-Code.
