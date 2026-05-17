__Product Requirements Document  
__Flutter App: PV Calculator mit Multi\-Array, Speicher und 24h\-Micro\-Inverter\-Szenarien

*Version: 0\.1 | Stand: 15\. Mai 2026 | Sprache: Deutsch*

Arbeitsname: PV Calculator X\. Ziel ist eine mobile, offline\-first nutzbare Flutter\-App, die klassische PV\-Ertragsrechner um ein explizites Energiefluss\- und Speicher\-Modell erweitert\. Der Schwerpunkt liegt auf mehreren PV\-Arrays, mehreren Wechselrichtern, Batteriespeicher, SOC\-Carry\-Over ueber Jahresgrenzen und optionalen 24h\-Ausgangsprofilen fuer kleine Wechselrichter bzw\. Micro\-Inverter\-Klassen\.

# Inhaltsverzeichnis

- 1\. Executive Summary
- 2\. Recherche\- und Marktbild
- 3\. Zielgruppen und Kernprobleme
- 4\. Produktumfang und User Stories
- 5\. Funktionale Anforderungen
- 6\. Simulationsanforderungen
- 7\. Nicht\-funktionale Anforderungen
- 8\. MVP, Pro\-Ausbau und Akzeptanzkriterien
- 9\. Risiken und offene Punkte
- 10\. Quellen und Recherchebasis

# 1\. Executive Summary

Klassische PV\-Rechner liefern meist Standort\-, Modul\-, Neigungs\-, Azimut\-, Verlust\- und Jahresertragswerte\. Fuer Prosumer\- und Balkonkraftwerk\-Szenarien reicht das nicht mehr aus: Nutzer wollen mehrere Dach\-/Balkonrichtungen kombinieren, einen gemeinsamen Speicher laden und aus diesem Speicher konstante oder zeitgesteuerte AC\-Leistung bereitstellen\. Genau diese Topologie soll die App abbilden\.

- MVP: stundenbasierte Jahressimulation mit 8760 Zeitschritten, mehreren PV\-Arrays, einem Speicher, Verbrauchsprofil, Netzimport/\-export und mehreren AC\-Ausgaengen\.
- Pro\-Funktion: 15\-Minuten\-Aufloesung, Szenariovergleich, Bibliotheken fuer Module/Inverter/Speicher, Berichts\-Export und zyklische SOC\-Konvergenz\.
- Zentrales Differenzierungsmerkmal: optionaler Vorlauf eines vollen Jahres, damit die eigentliche Jahresauswertung nicht kuenstlich bei leerem Speicher startet\.
- Kritischer Hinweis: Ein realer Micro\-Inverter darf nicht automatisch als batteriespeisefaehig angenommen werden\. Die App modelliert Energiefluesse und muss technische/legalen Warnungen anzeigen\.

# 2\. Recherche\- und Marktbild

Typische PV\-Rechner starten mit Standortdaten, Einstrahlung, installierter Leistung, Ausrichtung, Neigung und Systemverlusten\. Global Solar Atlas bietet z\. B\. Karten fuer Solarressourcen, einen vereinfachten PV\-Rechner, Reports und Download\-Funktionen \[S1\]\. PVGIS\-artige Werkzeuge arbeiten ebenfalls standortbasiert und liefern Ausgaben wie Jahresertrag, Einstrahlung, Tilt/Azimut und Verlustannahmen \[S2\]\.

Fuer detailliertere Modellierung ist die pvlib\-Modellkette relevant: Einstrahlungsdaten, Sonnenstand, Transposition auf die Modulebene, Verschattung/Verschmutzung, Zelltemperatur, DC\-Leistung, MPPT, Wechselrichter und AC\-Verluste \[S3\]\. Forschung zu PV\+Speicher betrachtet ueblicherweise Last\- und Erzeugungsdaten, iteriert PV\- und Speichergrenzen und bewertet Netzimport, Kosten oder Autarkie \[S4\]\. SOC\-Management ist bei PV\+Speicher kein Nebenthema, sondern Grundlage fuer Regelstrategien wie Eigenverbrauchsmaximierung, Ramp\-Rate\-Begrenzung oder forecast\-basiertes Laden \[S5\]\.

Der deutsche 800\-W\-Kontext ist fuer die App wichtig, weil Steckersolargeräte/Balkonkraftwerke seit der regulatorischen Vereinfachung die Micro\-Inverter\-Klasse in den Massenmarkt gebracht haben\. Die App soll deshalb 800\-W\-Wechselrichter als vordefinierte, aber konfigurierbare Ausgangsklasse anbieten \[S6\]\.

## 2\.1 Wettbewerbs\- und Funktionsmuster

- Einfache Solarrechner: Fokus auf kWp, Jahresertrag, Amortisation, CO2 und Stromkostenersparnis\.
- Standortbasierte PV\-Rechner: Karten\-/API\-Daten, Tilt/Azimut, Modultechnologie, Systemverluste, monatliche und jaehrliche Ertraege\.
- Installateurs\-/Planungstools: elektrische String\-/Inverter\-Auslegung, Dachflaechen, Komponentenbibliotheken, Angebots\- und Report\-Funktionen\.
- Energiesystem\-Simulatoren: Lastprofil, Speicher, Dispatch, Tarife, Netzimport/\-export, manchmal Optimierung oder MILP\-Modelle\.
- Luecke fuer dieses Produkt: mehrere kleine AC\-Ausgaenge aus einem Speicher, 24h\-Einspeisung, explizite SOC\-Vorberechnung und leicht bedienbare Mobile\-UX\.

# 3\. Zielgruppen und Kernprobleme

__Persona__

__Problem__

__Produktantwort__

DIY\-/Balkonkraftwerk\-Nutzer

Will wissen, ob mehrere Module/Ausrichtungen plus Speicher eine Grundlast ueber Nacht decken koennen\.

Niedrige Einstiegshuerde, 800\-W\-Szenarien, klare Warnungen\.

Linux\-/IT\-affine Prosumer

Will eigene CSV\-Daten, Leistungskurven und Automationslogik testen\.

Import/Export, reproduzierbare Simulation, JSON/CSV\.

PV\-Berater/Installateur

Will Varianten schnell vergleichen und Kunden einen Bericht geben\.

Szenariovergleich, Komponentenbibliothek, PDF/DOCX/CSV\-Export\.

Energie\-Optimierer

Will Speicher, Netzimport, Eigenverbrauch, Autarkie und Dauerleistung optimieren\.

SOC\-Modelle, 15\-Minuten\-Aufloesung, KPIs und Charts\.

# 4\. Produktumfang und User Stories

## 4\.1 Kernnutzen

- Mehrere PV\-Arrays mit individuellen Parametern modellieren: Leistung, Modulanzahl, Neigung, Azimut, Verluste, MPPT\-Zuordnung\.
- Mehrere Wechselrichter modellieren: klassischer PV\-Wechselrichter, Batterie\-Wechselrichter, Micro\-Inverter\-Bank, fixe 800\-W\-Klasse\.
- Batteriespeicher mit Kapazitaet, SOC\-Grenzen, Lade\-/Entladeleistung, Wirkungsgraden, Standby\-Verlusten und Alterungsparametern berechnen\.
- Jahres\-Simulation mit optionalem Vorlaufjahr: Ergebnisjahr startet mit realistischem SOC statt pauschal 0 % oder 50 %\.
- 24h\-Profile abbilden: konstante Einspeisung, Grundlastabdeckung, Zeitfenster, Prioritaeten und Notabschaltung bei niedrigem SOC\.
- Ergebnisse als Energiefluesse statt nur als Summen darstellen: PV direkt genutzt, PV in Speicher, Batterie zu Last/Micro\-Inverter, Netzimport, Netzeinspeisung\.

## 4\.2 User Stories

- Als Nutzer will ich Ost\-, Sued\- und West\-Arrays getrennt erfassen, damit die App Morgen\-, Mittag\- und Abendproduktion realistisch kombiniert\.
- Als Nutzer will ich eine Batterie mit Start\-SOC und Vorlaufjahr simulieren, damit die Januarwerte nicht durch einen kuenstlich leeren Speicher verfälscht werden\.
- Als Nutzer will ich zwei bis vier 800\-W\-Ausgaenge konfigurieren, damit ich sehe, wie lange eine 24h\-Einspeisung aus dem Speicher tragfähig ist\.
- Als Nutzer will ich sehen, wann der Speicher leerlaeuft oder voll ist, damit ich Batteriegröße und Ausgangsleistung optimieren kann\.
- Als Berater will ich Varianten duplizieren und vergleichen, damit ich unterschiedliche Speichergrößen, Ausrichtungen und Ausgangsleistungen bewerten kann\.
- Als Power\-User will ich Verbrauchs\- und Wetterdaten als CSV importieren, damit reale Messwerte statt generischer Profile verwendet werden koennen\.

# 5\. Funktionale Anforderungen

__ID__

__Bereich__

__Anforderung__

__Prioritaet__

FR\-01

Projektverwaltung

Projekte, Standorte und Szenarien anlegen, duplizieren, archivieren und exportieren\.

MVP

FR\-02

Standort/Wetter

Standort per Koordinaten, Adresse oder manuell; Wetter\-/Einstrahlungsdaten per Import oder Provider\.

MVP

FR\-03

PV\-Arrays

Beliebig viele Arrays mit kWp, Modulanzahl, Tilt, Azimut, Verlusten, Degradation und MPPT\-Zuordnung\.

MVP

FR\-04

Komponentenbibliothek

Module, Wechselrichter, Speicher und Profile lokal pflegen; spaeter Cloud\-Sync optional\.

Pro

FR\-05

Wechselrichter

PV\-, Batterie\- und Micro\-Inverter mit Leistungsgrenzen, Wirkungsgradkurven und Nacht\-/Standby\-Verbrauch\.

MVP

FR\-06

800\-W\-Vorlagen

Vordefinierte 800\-W\-Ausgangsklasse fuer Steckersolar\-/Micro\-Inverter\-Szenarien, frei editierbar\.

MVP

FR\-07

Batterie

Kapazitaet, nutzbare Kapazitaet, min/max SOC, Lade\-/Entladeleistung, Wirkungsgrade, Standby\-Verluste\.

MVP

FR\-08

Topologie

Konfiguration, welche Arrays welche DC\-/AC\-Busse, Batterie und Inverter speisen\.

MVP

FR\-09

Dispatch\-Regeln

Prioritaeten: Direktverbrauch, Batterie laden, Micro\-Inverter versorgen, Netzexport, Netzimport\.

MVP

FR\-10

24h\-Ausgang

Konstante oder zeitgesteuerte AC\-Ausgabe aus dem Speicher; SOC\-basierte Abschaltung\.

MVP

FR\-11

Pre\-Run Jahr

Optional ein volles Jahr vorrechnen; End\-SOC wird Start\-SOC des Ergebnisjahres\.

MVP

FR\-12

Simulation

Stundenbasierte Simulation; 15\-Minuten\-Modus als Pro\-Feature\.

MVP/Pro

FR\-13

Ergebnisse

Charts und Tabellen fuer PV\-Ertrag, SOC, Speicherzyklen, Netzimport/\-export, Autarkie, Eigenverbrauch\.

MVP

FR\-14

Szenariovergleich

Mehrere Varianten nebeneinander: Speichergröße, Array\-Mix, Ausgangsleistung, Lastprofil\.

Pro

FR\-15

Export

CSV/JSON fuer Daten; PDF/DOCX\-Bericht spaeter; Projektdatei fuer Austausch\.

MVP/Pro

FR\-16

Validierung

Warnungen bei unplausiblen Parametern, Energieverletzungen, illegalen/unsicheren Hardwareannahmen\.

MVP

FR\-17

Lokalisierung

Deutsch zuerst, Einheiten metrisch; Englisch als spaetere Sprache\.

MVP/Pro

# 6\. Simulationsanforderungen

## 6\.1 Zeitschritte

- MVP: 1 Stunde, 8760 Schritte pro Normaljahr bzw\. 8784 bei Schaltjahr\.
- Pro: 15 Minuten, 35040 Schritte pro Normaljahr\. Das ist wichtig fuer Micro\-Inverter, Grundlastprofile und schnellere Batteriezyklen\.
- Alle Energiewerte werden intern in Wh/kWh und alle Leistungen in W/kW mit klarer Typisierung berechnet\.
- Die Ergebnisdarstellung aggregiert Tages\-, Monats\- und Jahreswerte, speichert aber die Roh\-Zeitreihe fuer Export und Debugging\.

## 6\.2 Speicher\-SOC und Pre\-Run

SOC beschreibt den Ladezustand einer Batterie relativ zur Kapazitaet \[S7\]\. Die App darf deshalb nie nur mit Prozentwerten arbeiten, sondern muss die reale Energie in kWh fuehren und daraus den SOC ableiten\.

- Start\-SOC: manuell in Prozent/kWh, aus vorherigem Szenario, oder aus Pre\-Run\.
- Pre\-Run einfach: Simuliere Jahr N\-1 mit gewaehltem Start\-SOC; End\-SOC wird Start\-SOC fuer das angezeigte Jahr N\.
- Pre\-Run zyklisch: Wiederhole dasselbe Jahr, bis die Differenz zwischen Start\- und End\-SOC unter einem Schwellwert liegt, z\. B\. 0,5 % der nutzbaren Kapazitaet\.
- Ergebnisreport muss anzeigen, ob Pre\-Run aktiv war und welchen Start\-SOC das Ergebnisjahr bekommen hat\.
- SOC\-Grenzen: minSOC und maxSOC werden hart eingehalten; Lade\-/Entladeleistung wird bei Grenzannaeherung begrenzt\.

## 6\.3 Energiefluss\- und Dispatch\-Modell

1. PV\-Ertrag je Array fuer den aktuellen Zeitschritt berechnen\.
2. PV\-Leistung ueber MPPT\-/Invertergrenzen und Wirkungsgrade begrenzen\.
3. Direktverbrauch aus PV priorisieren, falls Lastprofil vorhanden ist\.
4. Ueberschuss in Batterie laden, begrenzt durch Ladeleistung, Wirkungsgrad und maxSOC\.
5. Konfigurierte 24h\-Ausgaenge aus PV/Ueberschuss oder Batterie versorgen, begrenzt durch Entladeleistung, Wirkungsgrad und minSOC\.
6. Rest als Netzexport ausweisen oder abregeln, je nach Szenario\.
7. Defizit als Netzimport ausweisen oder als nicht gedeckte Last markieren\.

Wichtig: Die App muss Energiepfade getrennt bilanzieren\. Nur so lassen sich spaeter sinnvolle KPIs fuer Eigenverbrauch, Autarkie, Speicherverluste und Micro\-Inverter\-Laufzeit berechnen\.

## 6\.4 Hardware\- und Sicherheitsannahmen

- Micro\-Inverter aus Batteriespeicher ist als abstraktes Modell zu behandeln, nicht als Bauanleitung\.
- Die App muss warnen, wenn ein normaler PV\-Micro\-Inverter als batteriespeisefaehig konfiguriert wird\. Viele Geraete erwarten PV\-Modulkennlinien, MPP\-Verhalten, DC\-Spannungsfenster und Schutzfunktionen\.
- Bei steckerfertigen Systemen sind landesspezifische Grenzen, Anmeldung, Netz\- und Anlagenschutz sowie Speicherregistrierung zu beachten \[S6\]\.
- Die Simulation ersetzt keine Elektrofachplanung und keine Zertifizierung\.

# 7\. Nicht\-funktionale Anforderungen

__ID__

__Kategorie__

__Anforderung__

NFR\-01

Performance

8760er Simulation mit 3 Arrays, 1 Speicher, 4 Ausgaengen auf Mittelklasse\-Smartphone in unter 5 Sekunden\.

NFR\-02

Genauigkeit

Energiebilanzfehler pro Jahr unter 0,1 %; keine negativen SOC\- oder Kapazitaetsueberschreitungen\.

NFR\-03

Offline\-first

Projektbearbeitung und Simulation lokal ohne Internet; Wetterprovider nur optional\.

NFR\-04

Datenschutz

Projekte bleiben lokal; Cloud/Sync nur explizit opt\-in\.

NFR\-05

Reproduzierbarkeit

Simulationsergebnis muss aus Projektdatei, App\-Version und Engine\-Version reproduzierbar sein\.

NFR\-06

UX

Technische Tiefe fuer Power\-User, aber Wizard fuer schnelle Standardszenarien\.

NFR\-07

Barrierefreiheit

Kontrast, skalierbare Schrift, VoiceOver/TalkBack labels und tastbare Charts mit Datentabellen\.

NFR\-08

Wartbarkeit

Domain\- und Simulationskern ohne Flutter\-Abhaengigkeit, voll unit\-testbar\.

# 8\. MVP, Pro\-Ausbau und Akzeptanzkriterien

## 8\.1 MVP\-Scope

- Projekt/Wizard: Standort, Wetterdaten manuell oder CSV, Arrays, Speicher, Lastprofil, Ausgaenge\.
- Stundenbasierte Simulation mit Pre\-Run\-Jahr\.
- Charts: Tages\-/Monats\-PV, SOC\-Verlauf, Netzimport/\-export, Laufzeit der 24h\-Ausgaenge\.
- Szenario duplizieren und Varianten vergleichen als einfache Liste\.
- Export: CSV\-Zeitreihe und JSON\-Projektdatei\.
- Warnsystem fuer Hardware\-/Regelverletzungen\.

## 8\.2 Pro\-/Ausbau\-Scope

- 15\-Minuten\-Aufloesung und mehrjaehrige Simulation mit Degradation\.
- Komponentenbibliotheken und eigene Wirkungsgradkurven\.
- Tarifmodell, Einspeiseverguetung, dynamische Strompreise\.
- Optimierer: Speichergröße, Ausgangsleistung, Array\-Mix und Start\-SOC automatisch variieren\.
- Berichts\-Export als PDF/DOCX und optional Cloud\-Backup\.
- Import realer Messdaten aus Smartmeter/Home Assistant/CSV\.

## 8\.3 Akzeptanzkriterien

- Ein Projekt mit 3 Arrays, 1 Batterie, 4 x 800\-W\-Ausgaengen und Lastprofil laesst sich ohne Absturz simulieren\.
- SOC bleibt in jedem Zeitschritt innerhalb minSOC/maxSOC\.
- Wenn Pre\-Run aktiv ist, weicht der Start\-SOC des Ergebnisjahres vom Default ab und wird im Report dokumentiert\.
- Bei leerem Speicher werden 24h\-Ausgaenge korrekt reduziert oder abgeschaltet\.
- CSV\-Export enthaelt Zeitstempel, Array\-Ertraege, Speicherladung/\-entladung, SOC, Netzimport/\-export und Ausgangsleistung je Inverter\.
- Aenderung eines Parameters erzeugt ein neues reproduzierbares Ergebnis mit Engine\-Version\.

# 9\. Risiken und offene Punkte

__ID__

__Risiko__

__Beschreibung__

__Mitigation__

R\-01

Hardwareannahmen

Normale PV\-Micro\-Inverter koennen nicht beliebig aus Batterien gespeist werden\.

Deutliche Warnungen, abstraktes Modell, keine Bauanleitung\.

R\-02

Datenqualitaet

Wetter\-/Einstrahlungsdaten koennen lokal stark abweichen\.

Datenquelle anzeigen, CSV/Messdatenimport erlauben\.

R\-03

Regulierung

800\-W\-Regeln und Speicheranmeldung unterscheiden sich nach Land und koennen sich aendern\.

Landesprofile versionieren, keine Rechtsberatung\.

R\-04

Komplexitaet

Topologie\-Editor kann Nutzer ueberfordern\.

Wizard plus Expertenmodus\.

R\-05

Performance

15\-Minuten\- und Optimierungslaeufe koennen mobil teuer werden\.

Isolates, Caching, progressive Ergebnisse, spaeter Backend optional\.

## 9\.1 Offene Produktfragen

- Soll die App primaer DIY/Balkonkraftwerk oder auch professionelle Dachanlagen abdecken?
- Welche Wetterdatenquelle ist fuer MVP gesetzt: CSV zuerst, PVGIS/Global Solar Atlas API, oder eigener Backend\-Proxy?
- Wie detailliert sollen Wirkungsgradkurven der Wechselrichter modelliert werden?
- Soll der 24h\-Ausgang als netzparallel, inselartig oder rein rechnerischer Lastpfad modelliert werden?
- Welche Exportformate sind fuer die erste Version Pflicht: CSV/JSON oder schon PDF?

# Quellen und Recherchebasis

Die Quellen dienen als Recherchebasis für Funktionsumfang und Modellierungsansätze\. PV Calculator Pro selbst konnte in dieser Recherche nicht zuverlässig über eine offizielle Quelle verifiziert werden; die Produktanforderungen orientieren sich daher an der Funktionsklasse typischer PV\-Rechner und an den unten genannten Modellierungsquellen\.

__ID__

__Quelle__

__Relevanz__

__URL__

S1

Global Solar Atlas

Online map\-based application for solar resource and PV power potential; includes simplified PV calculator, reporting and downloads\.

[https://en\.wikipedia\.org/wiki/Global\_Solar\_Atlas](https://en.wikipedia.org/wiki/Global_Solar_Atlas)

S2

PVGIS example overview

PVGIS is used for location\-based PV yield estimation with inputs such as installed kWp, losses, tilt and azimuth\.

[https://en\.wikipedia\.org/wiki/Photovoltaic\_system](https://en.wikipedia.org/wiki/Photovoltaic_system)

S3

pvlib python

Open source PV simulation library; modeling chain covers irradiance, solar position, transposition, shading/soiling, cell temperature, DC power, MPPT, inverter and AC losses\.

[https://en\.wikipedia\.org/wiki/Pvlib\_python](https://en.wikipedia.org/wiki/Pvlib_python)

S4

Optimal sizing of solar PV and lithium battery storage

Example of sizing PV and storage using demand and generation data, iterative sizing and grid import / cost metrics\.

[https://arxiv\.org/abs/2306\.03581](https://arxiv.org/abs/2306.03581)

S5

PV self\-consumption and ramp\-rate control with battery

Shows EMS variants and the importance of maintaining SOC range for PV\+battery control\.

[https://arxiv\.org/abs/2012\.11955](https://arxiv.org/abs/2012.11955)

S6

Balkonkraftwerk / Steckersolargerät

German context for plug\-in PV systems, 800 W inverter class and registration notes including storage data\.

[https://de\.wikipedia\.org/wiki/Balkonkraftwerk](https://de.wikipedia.org/wiki/Balkonkraftwerk)

S7

State of charge

SOC is the remaining capacity of a battery relative to its capacity, commonly expressed as a percentage\.

[https://en\.wikipedia\.org/wiki/State\_of\_charge](https://en.wikipedia.org/wiki/State_of_charge)

S8

Quasi\-dynamic load and battery sizing

MILP\-based sizing/scheduling model including battery charge/discharge constraints and load scheduling\.

[https://arxiv\.org/abs/1607\.07362](https://arxiv.org/abs/1607.07362)

