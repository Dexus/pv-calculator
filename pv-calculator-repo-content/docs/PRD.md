# PRD: PV Calculator Flutter App

## 1. Zielbild

Der PV Calculator soll private und semiprofessionelle PV-Szenarien vergleichbar machen: mehrere PV-Flaechen, mehrere Wechselrichterrollen, Batteriespeicher, 800-W-Micro-Inverter-Szenarien, Lastprofile und Exportauswertungen. Das Produkt startet als Flutter-App mit lokaler Simulation und soll spaeter bei Bedarf um externe Wetter-/PV-Datenquellen erweitert werden.

## 2. Problem

Viele PV-Rechner sind entweder zu grob, nur auf eine Standardanlage zugeschnitten oder nicht transparent genug. Unser Rechner soll typische Sonderfaelle abbilden:

- mehrere Dach-/Modulflaechen mit unterschiedlicher Ausrichtung,
- Kombination aus grossem Wechselrichter, Micro-Inverter und Batterieausgang,
- Speicher mit SOC-Fortschreibung ueber Tage, Monate und optionales Pre-Run-Jahr,
- 24h-Ausgangsprofile und Verbraucherlasten,
- Vergleich von Eigenverbrauch, Netzbezug, Einspeisung und Abregelung.

## 3. Zielgruppen

- Hausbesitzer, die PV-Groessen und Speicher grob abschaetzen wollen.
- Nutzer von Balkonkraftwerk-/800-W-Szenarien.
- Installateure oder Berater, die schnelle Vorvergleiche erstellen wollen.
- Entwicklerteam, das eine saubere Grundlage fuer eine spaetere Produktions-App braucht.

## 4. MVP-Scope

### 4.1 Projektkonfiguration

- Projektname und Standortdaten als optionale Eingaben.
- Anlagenprofil mit einem oder mehreren PV-Arrays.
- Lastprofil als 24h-Standardprofil oder importierte Daten.
- Speicherprofil inklusive Kapazitaet, maximaler Lade-/Entladeleistung und Wirkungsgrad.

### 4.2 PV-Arrays

Jedes PV-Array soll enthalten:

- Name/ID,
- Peak-Leistung in kWp,
- Neigung,
- Azimut,
- optionaler Verlustfaktor,
- optionaler zugewiesener Wechselrichter.

### 4.3 Wechselrichter

Unterstuetzte Rollen:

- Hauptwechselrichter fuer klassische PV-Einspeisung,
- 800-W-Micro-Inverter fuer Steckersolar-/Balkonkraftwerk-Szenarien,
- Batterieausgang oder Hybrid-Wechselrichter fuer Speicherentladung.

### 4.4 Batterie und SOC

- SOC wird ueber Simulationsschritte fortgeschrieben.
- Optionales Pre-Run-Jahr stabilisiert den Start-SOC fuer Jahressimulationen.
- Lade-/Entladeleistung und Wirkungsgrad werden beruecksichtigt.
- Batterie kann Eigenverbrauch optimieren; spaeter optional auch 24h-Ausgangsprofile bedienen.

### 4.5 Simulation

MVP-Zeitaufloesung:

- stuendlich als Standard,
- 15-Minuten-Aufloesung als geplante Erweiterung.

MVP-Ausgaben:

- PV-Erzeugung,
- direkt genutzte Energie,
- Batterieladung,
- Batterieentladung,
- Netzbezug,
- Einspeisung,
- Abregelung,
- SOC-Verlauf,
- Tages-/Monats-/Jahres-KPIs.

### 4.6 Export

- CSV-Export fuer Zeitreihen.
- JSON-Export fuer Projektkonfiguration und Simulationsergebnis.
- Spaeter optional PDF-/Report-Export.

## 5. Nicht-Ziele im MVP

- Keine verbindliche Ertragsgarantie.
- Keine Elektroplanung oder Normenpruefung.
- Keine vollstaendige Verschattungsanalyse.
- Keine reale Geraetedatenbank im ersten Schritt.
- Keine Finanz-/Foerdermittelberatung als Hauptfunktion.

## 6. Akzeptanzkriterien fuer den MVP

- Nutzer koennen mindestens drei PV-Arrays anlegen.
- Nutzer koennen mindestens drei Wechselrichterrollen konfigurieren.
- Ein Speicher mit SOC-Fortschreibung wird in der Simulation sichtbar.
- Eine Jahressimulation mit synthetischer Einstrahlung laeuft ohne Fehler.
- CSV- und JSON-Export liefern nachvollziehbare Daten.
- Der HTML-Prototyp bleibt als Referenz erhalten.
- Der Flutter-Code enthaelt testbare Domain-Logik ausserhalb der UI.

## 7. Qualitaetskriterien

- Domain-Logik ist von Flutter-Widgets getrennt.
- Simulationen sind deterministisch testbar.
- Alle Annahmen werden sichtbar dokumentiert.
- Externe Datenquellen werden spaeter ueber Adapter angebunden.
- Projektdateien bleiben versionierbar und diff-freundlich.
