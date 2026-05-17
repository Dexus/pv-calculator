// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get commonAdd => 'Hinzufügen';

  @override
  String get commonRemove => 'Entfernen';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonSearch => 'Suchen';

  @override
  String get validationRequired => 'Pflichtfeld';

  @override
  String get validationMustBeNumber => 'Bitte eine Zahl eingeben';

  @override
  String validationAtLeast(String value) {
    return 'Mindestens $value';
  }

  @override
  String validationAtMost(String value) {
    return 'Höchstens $value';
  }

  @override
  String get drawerSubtitle => 'Demo · synthetisches Modell';

  @override
  String get drawerProjects => 'Projekte';

  @override
  String get drawerSettings => 'Einstellungen';

  @override
  String get drawerAbout => 'Über';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsAppearance => 'Erscheinungsbild';

  @override
  String get settingsThemeSystem => 'Systemvorgabe folgen';

  @override
  String get settingsThemeSystemDesc => 'Wechselt mit der Geräteeinstellung.';

  @override
  String get settingsThemeLight => 'Hell';

  @override
  String get settingsThemeDark => 'Dunkel';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageSystem => 'Systemsprache verwenden';

  @override
  String get settingsLanguageSystemDesc => 'Folgt der Sprache des Geräts.';

  @override
  String get settingsAboutApp => 'Über die App';

  @override
  String get settingsAboutBody =>
      'Demo-Anwendung zur PV-Auslegung mit Batteriespeicher und 800-W-Micro-Wechselrichter. Das aktuelle Strahlungsmodell ist synthetisch und stellt keine validierte Ertragsprognose dar.';

  @override
  String get settingsAdvanced => 'Erweitert';

  @override
  String get settingsExpertMode => 'Expertenmodus';

  @override
  String get settingsExpertModeDesc =>
      'Blendet Topologie-Editor, Mikro-Wechselrichter-Bänke und alternative Dispatch-Strategien im Auswertung-Tab ein.';

  @override
  String get projectListTitle => 'PV Calculator — Projekte';

  @override
  String get projectListEmpty => 'Noch keine Projekte gespeichert.';

  @override
  String get projectListEmptyHint =>
      'Lege ein neues Projekt an oder importiere ein gespeichertes JSON.';

  @override
  String get projectListCreateButton => 'Neues Projekt erstellen';

  @override
  String get projectListImportTooltip => 'Importieren';

  @override
  String get projectListNewTooltip => 'Neues Projekt';

  @override
  String get projectListExportTooltip => 'Exportieren';

  @override
  String get projectListDeleteTooltip => 'Löschen';

  @override
  String get projectListNewDefaultName => 'Neues Projekt';

  @override
  String projectListLoadFailed(String name) {
    return 'Projekt \"$name\" konnte nicht geladen werden.';
  }

  @override
  String projectListImported(String name) {
    return 'Importiert: $name';
  }

  @override
  String projectListImportFailed(String error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String projectListDownloaded(String filename) {
    return 'Heruntergeladen: $filename';
  }

  @override
  String projectListExported(String filename) {
    return 'Exportiert: $filename';
  }

  @override
  String get projectListExportCancelled => 'Export abgebrochen';

  @override
  String projectListExportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get projectListConflictTitle => 'Projekt existiert bereits';

  @override
  String projectListConflictBody(String name) {
    return '\"$name\" ist bereits gespeichert. Soll der Import diese Version überschreiben oder unter einem neuen Namen abgelegt werden?';
  }

  @override
  String get projectListConflictRename => 'Umbenennen';

  @override
  String get projectListConflictOverwrite => 'Überschreiben';

  @override
  String get projectListDeleteTitle => 'Projekt löschen?';

  @override
  String projectListDeleteBody(String name) {
    return '\"$name\" wird unwiderruflich gelöscht.';
  }

  @override
  String projectListSaveFailed(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get editorRun => 'Simulation starten';

  @override
  String get editorValidationTitle => 'Konfiguration unvollständig';

  @override
  String get editorRunErrorTitle => 'Simulation fehlgeschlagen';

  @override
  String get editorOrphanedTitle => 'PVGIS-Importe ohne passendes Modulfeld';

  @override
  String get editorOrphanedBody =>
      'Die folgenden importierten Wetterreihen verweisen auf gelöschte oder umbenannte Modulfelder und werden von der Simulation nicht genutzt. Über „Vergessen“ kannst du sie freigeben.';

  @override
  String get editorOrphanedForget => 'Vergessen';

  @override
  String get editorWeatherSynthetic =>
      'Hinweis: Diese Simulation nutzt ein synthetisches Demo-Strahlungsmodell und ersetzt keine PVGIS-Validierung. Du kannst pro Modulfeld eine PVGIS-Stündliche-Daten-JSON importieren, um reale Einstrahlung zu nutzen.';

  @override
  String get editorWeatherSession =>
      ' PVGIS-Importe gelten nur für diese Sitzung; beim erneuten Öffnen eines gespeicherten Projekts müssen sie neu importiert werden.';

  @override
  String editorWeatherAll(int total, String session) {
    return 'Wetterquelle: PVGIS-Daten für alle $total Modulfelder importiert. TMY-Mittelwerte über die in der Datei enthaltenen Jahre.$session';
  }

  @override
  String editorWeatherMixed(int withCount, int total, String session) {
    return 'Wetterquelle gemischt: $withCount von $total Modulfeldern nutzen importierte PVGIS-Daten, die übrigen fallen auf das synthetische Demo-Modell zurück.$session';
  }

  @override
  String get projectSectionTitle => 'Projekt';

  @override
  String get projectName => 'Projektname';

  @override
  String get projectLatitude => 'Breitengrad';

  @override
  String get projectLongitude => 'Längengrad';

  @override
  String get projectStartDay => 'Start-Tag im Jahr';

  @override
  String get projectSimulationDays => 'Simulationstage';

  @override
  String get projectPreRunDays => 'Vorlauf-Tage';

  @override
  String get projectPreRunHelp =>
      'Anzahl Vorlauftage für den Modus „Einfacher Vorlauf“. Wird nur ausgewertet, wenn dieser Modus aktiv ist; die Vorlauf-Schritte erscheinen nicht in den Ergebnissen.';

  @override
  String get projectPreRunMode => 'SOC-Vorlauf';

  @override
  String get projectPreRunModeManual => 'Manueller Start-SOC';

  @override
  String get projectPreRunModeSingle => 'Einfacher Vorlauf';

  @override
  String get projectPreRunModeCyclic => 'Zyklische Konvergenz';

  @override
  String get projectPreRunModeCyclicPro => 'Zyklische Konvergenz (Pro)';

  @override
  String get projectConvergenceTolerance => 'Konvergenz-Toleranz';

  @override
  String get projectConvergenceToleranceHelp =>
      'Maximaler |Start − End|-SOC nach einem Zyklus, in % der nutzbaren Kapazität. PRD §6.2 empfiehlt 0,5 %.';

  @override
  String get projectMaxConvergenceIterations => 'Max. Iterationen';

  @override
  String get projectExportLimit => 'Einspeise-Limit';

  @override
  String get projectTimeStep => 'Zeitschritt';

  @override
  String get projectTimeStepHourly => 'Stündlich';

  @override
  String get projectTimeStepQuarter => 'Viertelstündlich';

  @override
  String get projectPvgisApiTitle => 'PVGIS-API';

  @override
  String get projectPvgisApiHelp =>
      'Zeitfenster und Strahlungsdatenbank für „Von PVGIS-API laden“. PVGIS-SARAH3 deckt typischerweise 2005–2023 ab; je breiter das Fenster, desto stabiler werden TMY-Mittelwerte.';

  @override
  String get projectPvgisStartYear => 'PVGIS Startjahr';

  @override
  String get projectPvgisEndYear => 'PVGIS Endjahr';

  @override
  String get projectRadDatabase => 'Strahlungsdatenbank';

  @override
  String get projectRadDatabaseAuto => 'PVGIS Auto';

  @override
  String get projectAddressSearch => 'Adresse suchen (OpenStreetMap)';

  @override
  String get projectAddressHint => 'z.B. Marktplatz 1, Frankfurt';

  @override
  String get projectAddressNoResults => 'Keine Treffer gefunden.';

  @override
  String get fieldId => 'ID';

  @override
  String get fieldLabel => 'Bezeichnung';

  @override
  String get arraysTitle => 'PV-Module';

  @override
  String get arraysEmpty => 'Mindestens ein Modulfeld ist erforderlich.';

  @override
  String arraysDefaultLabel(int n) {
    return 'Modulfeld $n';
  }

  @override
  String arraysHeading(int n) {
    return 'Modulfeld $n';
  }

  @override
  String get arraysFieldPeak => 'Spitzenleistung';

  @override
  String get arraysFieldAzimuth => 'Azimut';

  @override
  String get arraysFieldTilt => 'Neigung';

  @override
  String get arraysFieldLosses => 'Verluste';

  @override
  String get arraysFieldShading => 'Verschattung';

  @override
  String get arraysFieldTempCoef => 'Temperaturkoeff.';

  @override
  String get arraysFieldTempCoefHelp =>
      'Leistungsverlust pro °C Zelltemperatur über 25 °C. Kristallines Silizium ≈ −0,4 %/°C; 0 deaktiviert die Temperatur-Derating.';

  @override
  String get arraysFieldNoct => 'NOCT';

  @override
  String get arraysFieldNoctHelp =>
      'Nominal Operating Cell Temperature: Zelltemperatur bei 800 W/m², 20 °C Luft, 1 m/s Wind. Typisch 45 °C.';

  @override
  String get arraysFieldInverter => 'Wechselrichter';

  @override
  String get arraysFieldInverterRequired => 'Wechselrichter auswählen';

  @override
  String get pvgisIdRequired => 'Bitte zuerst eine Modulfeld-ID vergeben.';

  @override
  String pvgisImported(String id, int count) {
    return 'PVGIS-Daten für \"$id\" importiert ($count Werte).';
  }

  @override
  String pvgisImportFailed(String error) {
    return 'PVGIS-Import fehlgeschlagen: $error';
  }

  @override
  String get pvgisArrayNotFound => 'Modulfeld nicht gefunden.';

  @override
  String pvgisInvalidRequest(String error) {
    return 'PVGIS-Abfrage ungültig: $error';
  }

  @override
  String pvgisApiLoaded(String id, int count) {
    return 'PVGIS-API-Daten für \"$id\" geladen ($count Werte).';
  }

  @override
  String pvgisApiFailed(String error) {
    return 'PVGIS-API-Abfrage fehlgeschlagen: $error';
  }

  @override
  String get pvgisStatusSynthetic => 'Wetterquelle: synthetisches Demo-Modell';

  @override
  String get pvgisStatusLoaded => 'PVGIS-Daten geladen';

  @override
  String pvgisMetadata(
    String source,
    int count,
    String years,
    String lat,
    String lon,
    String orientation,
  ) {
    return '$source · $count Stunden · Jahre $years · PVGIS-Lage $lat°/$lon°$orientation';
  }

  @override
  String get pvgisSessionNote =>
      'Hinweis: PVGIS-Importe gelten nur für diese Sitzung — sie werden nicht im Projekt-JSON gespeichert.';

  @override
  String pvgisOrientationWarning(String issues) {
    return 'PVGIS-Ausrichtung weicht ab ($issues). Die importierten POA-Werte gelten für die PVGIS-Ausrichtung, nicht für die hier eingestellte.';
  }

  @override
  String pvgisOrientationTilt(String value) {
    return 'Neigung $value°';
  }

  @override
  String pvgisOrientationAzimuth(String value) {
    return 'Azimut $value°';
  }

  @override
  String pvgisTiltMismatch(String imported, String configured) {
    return 'Neigung $imported° vs $configured°';
  }

  @override
  String pvgisAzimuthMismatch(String imported, String configured) {
    return 'Azimut $imported° vs $configured°';
  }

  @override
  String get pvgisReloadApi => 'API neu laden';

  @override
  String get pvgisLoadFromApi => 'Von PVGIS-API laden';

  @override
  String get pvgisImportJson => 'JSON importieren';

  @override
  String get invertersTitle => 'Wechselrichter';

  @override
  String get invertersEmpty =>
      'Mindestens ein Wechselrichter ist erforderlich.';

  @override
  String invertersDefaultLabel(int n) {
    return 'Wechselrichter $n';
  }

  @override
  String invertersHeading(int n) {
    return 'Wechselrichter $n';
  }

  @override
  String get invertersFieldMaxAc => 'Max. AC-Leistung';

  @override
  String get invertersFieldEfficiency => 'Wirkungsgrad';

  @override
  String get invertersFieldMaxDc => 'Max. DC-Eingang';

  @override
  String get invertersFieldMaxDcHelp =>
      'Optionale DC-Eingangsgrenze (MPPT). DC-Leistung darüber wird vor dem Wechselrichter geclippt und als Abregelung erfasst. Leer lassen, wenn der Wechselrichter nicht überdimensioniert ist.';

  @override
  String get invertersFieldRole => 'Rolle';

  @override
  String get invertersRoleGrid => 'Netz';

  @override
  String get invertersRoleMicro => '800-W-Micro';

  @override
  String get invertersRoleBattery => 'Batteriegekoppelt';

  @override
  String get invertersRoleMicroHelp =>
      '800-W-Stecker-Solar: AC-Ausgang wird hart auf 0,8 kW gekappt, unabhängig von der eingestellten Max. AC-Leistung.';

  @override
  String get invertersRoleBatteryHelp =>
      'Wechselrichter ist DC-seitig mit einer Batterie gekoppelt; Erfassung wie ein Netz-Wechselrichter, aber semantisch markiert.';

  @override
  String get invertersRoleGridHelp =>
      'Standard-Netz-Wechselrichter ohne harte AC-Hürde.';

  @override
  String get batteriesTitle => 'Batteriespeicher';

  @override
  String get batteriesEmpty => 'Kein Batteriespeicher konfiguriert (optional).';

  @override
  String batteriesDefaultLabel(int n) {
    return 'Speicher $n';
  }

  @override
  String batteriesHeading(int n) {
    return 'Speicher $n';
  }

  @override
  String get batteriesFieldCapacity => 'Kapazität';

  @override
  String get batteriesFieldChargePower => 'Max. Ladeleistung';

  @override
  String get batteriesFieldDischargePower => 'Max. Entladeleistung';

  @override
  String get batteriesFieldRoundtrip => 'Roundtrip-Wirkungsgrad';

  @override
  String get batteriesFieldRoundtripHelp =>
      'Lade- × Entladewirkungsgrad. Typisch 0,9 für Lithium-Speicher, ≈ 0,75 für Blei-Speicher.';

  @override
  String get batteriesFieldMinSoc => 'Min. SOC';

  @override
  String get batteriesCustomInitial => 'Start-SOC manuell setzen';

  @override
  String get batteriesFieldStartSoc => 'Start-SOC';

  @override
  String get loadTitle => 'Lastprofil';

  @override
  String get loadFieldDaily => 'Tagesverbrauch';

  @override
  String get loadHourlyHint =>
      'Stundenform: deutsches Haushalts-Standardprofil (24 Werte). Eine manuelle Anpassung der Stundenform ist für eine spätere Version vorgesehen.';

  @override
  String resultsTitle(String name) {
    return 'Ergebnis — $name';
  }

  @override
  String get resultsEmpty => 'Keine Simulation ausgeführt.';

  @override
  String get resultsBack => 'Zurück zur Konfiguration';

  @override
  String get resultsAnnualKpis => 'Jahreskennzahlen';

  @override
  String get resultsKpiPvAc => 'PV AC';

  @override
  String get resultsKpiLoad => 'Last';

  @override
  String get resultsKpiSelfConsumption => 'Eigenverbrauch';

  @override
  String get resultsKpiGridImport => 'Netzimport';

  @override
  String get resultsKpiGridExport => 'Netzeinspeisung';

  @override
  String get resultsKpiCurtailDc => 'Abregelung DC (MPPT)';

  @override
  String get resultsKpiCurtailAc => 'Abregelung AC (WR-Limit)';

  @override
  String get resultsKpiCurtailExport => 'Abregelung Einspeisung';

  @override
  String get resultsKpiBatteryCharge => 'Batt-Ladung';

  @override
  String get resultsKpiBatteryDischarge => 'Batt-Entladung';

  @override
  String get resultsKpiAutarky => 'Autarkie';

  @override
  String get resultsKpiSelfConsumptionRate => 'EV-Quote';

  @override
  String get resultsBatterySection => 'Batterien (End-SOC)';

  @override
  String resultsBatteryLabel(int n) {
    return 'Speicher $n';
  }

  @override
  String get resultsPreRunSection => 'SOC-Vorlauf';

  @override
  String get resultsPreRunMode => 'Modus';

  @override
  String get resultsPreRunIterations => 'Iterationen';

  @override
  String get resultsPreRunConverged => 'Konvergiert';

  @override
  String get resultsPreRunConvergedYes => 'Ja';

  @override
  String get resultsPreRunConvergedNo => 'Nein';

  @override
  String resultsPreRunStartSoc(int n) {
    return 'Start-SOC Speicher $n';
  }

  @override
  String get resultsMonthly => 'Monatliche Bilanz';

  @override
  String get resultsCsvSteps => 'CSV-Export Schritte';

  @override
  String get resultsCsvMonthly => 'CSV-Export Monat';

  @override
  String resultsCsvPending(int size) {
    return 'CSV bereit ($size Zeichen). Export folgt im Persistence-Layer.';
  }

  @override
  String resultsExported(String filename) {
    return 'Exportiert: $filename';
  }

  @override
  String resultsExportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get resultsSyntheticNote =>
      'Hinweis: synthetisches Demo-Strahlungsmodell — keine validierte Ertragsprognose.';

  @override
  String get monthlyColMonth => 'Monat';

  @override
  String get monthlyColPvAc => 'PV AC (kWh)';

  @override
  String get monthlyColLoad => 'Last (kWh)';

  @override
  String get monthlyColSelfConsumption => 'EV (kWh)';

  @override
  String get monthlyColBatteryCharge => 'Bat-Lad. (kWh)';

  @override
  String get monthlyColBatteryDischarge => 'Bat-Entl. (kWh)';

  @override
  String get monthlyColImport => 'Import (kWh)';

  @override
  String get monthlyColExport => 'Export (kWh)';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mär';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'Mai';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Okt';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dez';

  @override
  String get geocodingTimeout => 'Zeitüberschreitung bei der Adresssuche.';

  @override
  String geocodingNetworkError(String error) {
    return 'Netzwerkfehler: $error';
  }

  @override
  String get geocodingRateLimit =>
      'Nominatim hat das Limit erreicht (429). Bitte einen Moment warten.';

  @override
  String geocodingBadStatus(int code) {
    return 'Nominatim antwortete mit Status $code.';
  }

  @override
  String get geocodingInvalidJson =>
      'Antwort von Nominatim ist kein gültiges JSON.';

  @override
  String get geocodingInvalidFormat =>
      'Unerwartetes Antwortformat von Nominatim.';

  @override
  String pvgisApiInvalidRequest(String error) {
    return 'Ungültige PVGIS-Anfrage: $error';
  }

  @override
  String get pvgisApiTimeout => 'Zeitüberschreitung bei PVGIS-Abfrage.';

  @override
  String pvgisApiNetworkError(String error) {
    return 'Netzwerkfehler bei PVGIS-Abfrage: $error';
  }

  @override
  String pvgisApiBadStatus(int code, String message) {
    return 'PVGIS antwortete mit Status $code. $message';
  }

  @override
  String pvgisApiParseFailed(String error) {
    return 'PVGIS-Antwort konnte nicht gelesen werden: $error';
  }

  @override
  String get demoArrayLabel => 'Süddach';

  @override
  String get demoInverterLabel => 'Hauptwechselrichter';

  @override
  String get demoBatteryLabel => 'Hauptspeicher';

  @override
  String get tabProjects => 'Projekte';

  @override
  String get tabIrradiance => 'Einstrahlung';

  @override
  String get tabArrays => 'PV-Arrays';

  @override
  String get tabResults => 'Auswertung';

  @override
  String get irradianceTitle => 'Standort & Einstrahlung';

  @override
  String get irradianceMapHint =>
      'Karte verschieben, um den Standort zu setzen. Pin = Projektkoordinaten.';

  @override
  String get irradianceYearLabel => 'Zeitraum';

  @override
  String get irradianceLoadButton => 'Lade Daten';

  @override
  String get irradianceLoadingHint => 'Strahlungsdaten werden geladen …';

  @override
  String get irradianceEmpty =>
      'Standort wählen und „Lade Daten“ drücken, um die jährliche Globalstrahlung zu laden.';

  @override
  String get irradianceErrorTitle => 'PVGIS-Abfrage fehlgeschlagen';

  @override
  String get irradianceChartTitle => 'Globalstrahlung [ kW/m² ]';

  @override
  String get irradianceSeriesTotal => 'Gesamte';

  @override
  String get irradianceSeriesDiffuse => 'Diffuse';

  @override
  String irradianceAnnualSum(String value) {
    return 'Abs $value kWh/m²';
  }

  @override
  String irradianceAverage(String value) {
    return 'Ø $value W/m²';
  }

  @override
  String get irradianceCacheHit => 'aus Cache geladen';

  @override
  String get irradianceCacheMiss => 'frisch von PVGIS';

  @override
  String get azimuthCompassTitle => 'Azimut auswählen';

  @override
  String get azimuthCompassHint =>
      'Tippen, um den Azimut für das ausgewählte PV-Array zu setzen.';

  @override
  String get azimuthApply => 'Übernehmen';

  @override
  String get azimuthCancel => 'Abbrechen';

  @override
  String get resultsRun => 'Simulation starten';

  @override
  String get resultsRunMissingData =>
      'Bitte zuerst Strahlungsdaten und mindestens ein PV-Array eintragen.';

  @override
  String get resultsErrorTitle => 'Simulation fehlgeschlagen';

  @override
  String get arraysTabHint =>
      'Kein PVGIS-Aufruf pro Array — alle Module beziehen ihre POA-Werte aus den im Tab „Einstrahlung“ geladenen Standortdaten.';

  @override
  String get arraysSelectForCompass => 'Für Kompass-Auswahl markiert';

  @override
  String get dispatchPolicyTitle => 'Dispatch-Strategie';

  @override
  String get dispatchPolicyKindLabel => 'Strategie';

  @override
  String get dispatchPolicySelfConsumption => 'Eigenverbrauch zuerst';

  @override
  String get dispatchPolicySelfConsumptionDesc =>
      'PV deckt zuerst die Last, Überschuss lädt die Speicher, danach Einspeisung. Standardverhalten und identisch zur alten Engine.';

  @override
  String get dispatchPolicyReserve => 'Speicherreserve';

  @override
  String get dispatchPolicyReserveDesc =>
      'Wie Eigenverbrauch, aber die Speicher werden nur bis zum Reserveziel geladen. PV-Überschuss wird früher eingespeist statt vollständig zwischengespeichert.';

  @override
  String get dispatchPolicyReserveSoc => 'Reserveziel';

  @override
  String get dispatchPolicyReserveSocHelp =>
      'Bruchteil der Speicherkapazität (0..1), bis zu dem PV-Überschuss geladen wird. 0,5 = nur bis zur Hälfte laden.';

  @override
  String get dispatchPolicyConstantFeed => '24h-Konstanteinspeisung';

  @override
  String get dispatchPolicyConstantFeedDesc =>
      'Micro-Inverter-Bänke speisen rund um die Uhr mit ihrer Sollleistung, solange der Speicher über dem Abschalt-SOC liegt.';

  @override
  String get dispatchPolicyTimeWindow => 'Zeitfenster-Einspeisung';

  @override
  String get dispatchPolicyTimeWindowDesc =>
      'Micro-Inverter-Bänke speisen nur innerhalb der in jedem Bank konfigurierten Zeitfenster.';

  @override
  String get dispatchPolicyGridAssist => 'Netz-Assist';

  @override
  String get dispatchPolicyGridAssistDesc =>
      'Wie Eigenverbrauch, aber Netzimport kann blockiert werden — nicht gedeckte Last erscheint als „unversorgte Last“.';

  @override
  String get dispatchPolicyGridImportLabel => 'Netzimport zulassen';

  @override
  String get dispatchPolicyGridImportHelp =>
      'Aus = Inselbetrieb. Nicht gedeckte Last wird als „unversorgte Last“ statt als Netzimport bilanziert.';

  @override
  String get dispatchPolicyBankHint =>
      'Tipp: Diese Strategie ist nur sinnvoll mit mindestens einem Micro-Inverter-Bank.';

  @override
  String get microInverterBanksTitle =>
      'Micro-Inverter-Bänke (Batterieausgang)';

  @override
  String microInverterBanksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Bänke',
      one: '1 Bank',
      zero: 'Keine Bänke konfiguriert',
    );
    return '$_temp0';
  }

  @override
  String get microInverterBanksEmpty =>
      'Keine Bänke konfiguriert. Über „Hinzufügen“ einen batteriegekoppelten AC-Ausgang anlegen.';

  @override
  String microInverterBanksHeading(int n) {
    return 'Bank $n';
  }

  @override
  String microInverterBanksDefaultLabel(int n) {
    return 'Bank $n';
  }

  @override
  String get microInverterBanksWarnPvDevice =>
      'Hinweis: Reguläre PV-Micro-Inverter erwarten Modulkennlinien; ein Batterieausgang braucht ein vom Hersteller dafür freigegebenes Gerät. Die Simulation ersetzt keine Elektrofachplanung.';

  @override
  String get microInverterBankBattery => 'Quell-Speicher';

  @override
  String get microInverterBankCount => 'Anzahl';

  @override
  String get microInverterBankUnitW => 'Leistung je Einheit';

  @override
  String get microInverterBankShutdown => 'Abschalt-SOC';

  @override
  String get microInverterBankShutdownHelp =>
      'Bruchteil der Speicherkapazität (0..1), unter dem die Bank nicht mehr einspeist. 0 = nie abschalten.';

  @override
  String get microInverterBankEfficiency => 'Wirkungsgrad';

  @override
  String get microInverterBankSchedule => 'Zeitplan';

  @override
  String get microInverterBankScheduleKind => 'Zeitplan-Typ';

  @override
  String get microInverterBankScheduleAlwaysOn => 'Dauerbetrieb';

  @override
  String get microInverterBankScheduleTimeWindows => 'Zeitfenster';

  @override
  String get microInverterBankScheduleHourly => 'Stündlich (24 Werte)';

  @override
  String get microInverterBankAddWindow => 'Zeitfenster';

  @override
  String get microInverterBankAlwaysOn =>
      'Dauerbetrieb: rund um die Uhr aktiv (gemäß Dispatch-Strategie).';

  @override
  String get microInverterBankWindowStart => 'Start (h)';

  @override
  String get microInverterBankWindowEnd => 'Ende (h)';

  @override
  String get microInverterBankWindowFactor => 'Faktor';

  @override
  String microInverterBankHourlyHour(int hour) {
    return '$hour:00';
  }

  @override
  String get microInverterBankHourlyHelp =>
      'Faktor je Stunde (0..1). 1.0 = volle Sollleistung, 0.0 = aus. Wirkt auf die Bank-Sollleistung, nicht direkt auf SOC.';

  @override
  String get microInverterBankHourlyReset => 'Alles auf 1.0';

  @override
  String get resultsKpiMicroDelivered => 'Micro-Inverter geliefert';

  @override
  String get resultsKpiMicroShortfall => 'Micro-Inverter Fehlbetrag';

  @override
  String get resultsKpiUnservedLoad => 'Unversorgte Last';

  @override
  String microInverterBanksWarnSharedPvInverter(String inverterId) {
    return 'Achtung: Wechselrichter „$inverterId“ ist als „800-W-Micro-Inverter“ mit angeschlossenen PV-Modulen konfiguriert. Reguläre PV-Micro-Inverter dürfen nicht aus einem Speicher gespeist werden — der Batterieausgang braucht ein eigenes, vom Hersteller dafür freigegebenes Gerät.';
  }

  @override
  String get bankRuntimeSectionTitle => '24h-Ausgang — Laufzeit pro Tag';

  @override
  String get bankRuntimeLegendFull => 'Voll gedeckt (Soll erreicht)';

  @override
  String get bankRuntimeLegendPartial => 'Teilweise (Soll unterschritten)';

  @override
  String get bankRuntimeLegendShortfall =>
      'Fehlbetrag (geplante Stunden ohne Lieferung)';

  @override
  String bankRuntimeStatCoverage(String pct) {
    return 'Abdeckung: $pct %';
  }

  @override
  String bankRuntimeStatAvgHours(String hours) {
    return 'Ø $hours h/Tag aktiv';
  }

  @override
  String bankRuntimeStatDelivered(String kwh) {
    return 'Geliefert: $kwh kWh';
  }

  @override
  String bankRuntimeStatShortfall(String kwh) {
    return 'Fehlbetrag: $kwh kWh';
  }

  @override
  String get topologyTitle => 'Topologie';

  @override
  String get topologyEnable => 'Explizite Topologie verwenden';

  @override
  String get topologyAutoGeneratedInfo =>
      'Aus: Engine baut die Standardtopologie aus Arrays, Wechselrichtern und Batterien automatisch.';

  @override
  String get topologyDcBusesTitle => 'DC-Busse';

  @override
  String get topologyAcBusesTitle => 'AC-Busse';

  @override
  String get topologyMpptTitle => 'MPPT-Knoten';

  @override
  String get topologyMpptEmpty =>
      'Keine MPPTs konfiguriert. Über „Aus aktueller Konfiguration übernehmen“ aus den Wechselrichtern ableiten.';

  @override
  String get topologyEdgesTitle => 'Kanten';

  @override
  String get topologyCouplingsTitle => 'Batterie-Kopplungen';

  @override
  String get topologyCouplingsEmpty => 'Keine Batterien konfiguriert.';

  @override
  String get topologyAddDcBus => 'DC-Bus';

  @override
  String get topologyAddAcBus => 'AC-Bus';

  @override
  String get topologyAddEdge => 'Kante';

  @override
  String get topologyEdgeFrom => 'Von';

  @override
  String get topologyEdgeTo => 'Nach';

  @override
  String get topologyEdgeEfficiency => 'Wirkungsgrad';

  @override
  String get topologyEdgeMaxPowerKw => 'Max. Leistung';

  @override
  String get topologyEdgeStandbyW => 'Standby';

  @override
  String get topologyCouplingAc => 'AC';

  @override
  String get topologyCouplingDc => 'DC';

  @override
  String get topologyCouplingDcBus => 'DC-Bus';

  @override
  String get topologyCouplingInverter => 'Batterie-Wechselrichter';

  @override
  String get topologyCouplingInverterNone => '— keiner —';

  @override
  String get topologyCouplingInverterHelp =>
      'Optional: Wechselrichter, der die AC-Ausgangsleistung der Batterie begrenzt (Architektur §5.3). Leer = `BatteryConfig.maxDischargeKw` ist die AC-Grenze.';

  @override
  String get topologySeedFromLegacy => 'Aus aktueller Konfiguration übernehmen';

  @override
  String projectsTabCompareButton(int count) {
    return 'Vergleichen ($count)';
  }

  @override
  String projectsTabScenarioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Szenarien',
      one: '1 Szenario',
      zero: 'Keine Szenarien',
    );
    return '$_temp0';
  }

  @override
  String get projectsTabEmptyScenarios =>
      'Noch kein Szenario in diesem Projekt.';

  @override
  String get projectsTabPopupNewScenario => 'Neues Szenario';

  @override
  String get projectsTabPopupRename => 'Umbenennen';

  @override
  String get projectsTabPopupDeleteProject => 'Projekt löschen';

  @override
  String get projectsTabDuplicateTooltip => 'Duplizieren';

  @override
  String get projectsTabRenameTooltip => 'Umbenennen';

  @override
  String get projectsTabExportTooltip => 'Exportieren';

  @override
  String get projectsTabDeleteTooltip => 'Löschen';

  @override
  String get projectsTabRenameProjectTitle => 'Projekt umbenennen';

  @override
  String get projectsTabRenameScenarioTitle => 'Szenario umbenennen';

  @override
  String get projectsTabNewScenarioTitle => 'Neues Szenario';

  @override
  String get projectsTabDeleteScenarioTitle => 'Szenario löschen?';

  @override
  String projectsTabDeleteScenarioBody(String name) {
    return 'Wirklich \"$name\" löschen?';
  }

  @override
  String get projectsTabDialogSave => 'Speichern';

  @override
  String get projectsTabDialogCreate => 'Anlegen';

  @override
  String get projectsTabSuggestedScenarioName => 'Szenario';

  @override
  String get compareTitle => 'Szenariovergleich';

  @override
  String get comparePreparing => 'Wird vorbereitet…';

  @override
  String get compareEmptyHint =>
      'Wähle mindestens zwei Szenarien aus dem Projekte-Tab.';

  @override
  String get compareKpisCard => 'KPIs';

  @override
  String get compareChartCard => 'Energiebilanz im Vergleich';

  @override
  String get compareTableScenario => 'Szenario';

  @override
  String get compareTablePvAcKwh => 'PV AC (kWh)';

  @override
  String get compareTableSelfConsumption => 'Eigenverbrauch %';

  @override
  String get compareTableAutarky => 'Autarkie %';

  @override
  String get compareTableGridImport => 'Netzbezug (kWh)';

  @override
  String get compareTableGridExport => 'Einspeisung (kWh)';

  @override
  String get compareTableMicroInverter => 'Mikro-WR (kWh)';

  @override
  String get compareTableCurtailedAc => 'Abregelung AC (kWh)';

  @override
  String get compareTableSource => 'Quelle';

  @override
  String get compareTableSourceCache => 'Cache';

  @override
  String get compareTableSourceFresh => 'Neu';

  @override
  String get compareChartPvAc => 'PV AC';

  @override
  String get compareChartSelfConsumption => 'Eigenverbr.';

  @override
  String get compareChartGridImport => 'Netzbezug';

  @override
  String get compareChartGridExport => 'Einspeisung';

  @override
  String get resultsEnableExpertHint => 'Erweiterte Einstellungen aktivieren';

  @override
  String get resultsEnableExpertHintDesc =>
      'Topologie, Mikro-Wechselrichter-Bänke und Dispatch-Strategien sind im Expertenmodus verfügbar.';

  @override
  String get resultsAdvancedScenarioBanner =>
      'Dieses Szenario nutzt erweiterte Funktionen (Topologie, Mikro-Wechselrichter-Bänke oder ein abweichendes Dispatch). Aktiviere den Expertenmodus, um sie zu sehen und zu bearbeiten.';

  @override
  String get wizardTitle => 'Neues Projekt anlegen';

  @override
  String get wizardStepSite => 'Standort';

  @override
  String get wizardStepArray => 'PV-Modulfeld';

  @override
  String get wizardStepBattery => 'Speicher';

  @override
  String get wizardStepLoad => 'Lastprofil';

  @override
  String get wizardStepSummary => 'Zusammenfassung';

  @override
  String get wizardProjectName => 'Projektname';

  @override
  String get wizardLatitude => 'Breitengrad';

  @override
  String get wizardLongitude => 'Längengrad';

  @override
  String get wizardArrayPeak => 'Spitzenleistung';

  @override
  String get wizardArrayAzimuth => 'Azimut (0 = Nord, 180 = Süd)';

  @override
  String get wizardArrayTilt => 'Neigung';

  @override
  String get wizardAddBattery => 'Speicher hinzufügen';

  @override
  String get wizardBatteryCapacity => 'Kapazität';

  @override
  String get wizardBatteryChargeRate => 'Max. Ladeleistung';

  @override
  String get wizardBatteryDischargeRate => 'Max. Entladeleistung';

  @override
  String get wizardLoadDaily => 'Tagesverbrauch';

  @override
  String get wizardSummaryIntro =>
      'Diese Werte werden für das neue Projekt übernommen. Du kannst sie später jederzeit im Editor anpassen und Einstrahlungsdaten laden.';

  @override
  String get wizardSummaryName => 'Projekt';

  @override
  String get wizardSummarySite => 'Standort';

  @override
  String wizardSummaryArray(String peak, String azimuth, String tilt) {
    return 'PV: $peak kWp, $azimuth°/$tilt°';
  }

  @override
  String get wizardSummaryBatteryNone => 'Kein Speicher';

  @override
  String wizardSummaryBattery(
    String capacity,
    String charge,
    String discharge,
  ) {
    return 'Speicher: $capacity kWh ($charge/$discharge kW)';
  }

  @override
  String wizardSummaryLoad(String kwh) {
    return 'Last: $kwh kWh/Tag';
  }

  @override
  String get wizardCancel => 'Abbrechen';

  @override
  String get wizardBack => 'Zurück';

  @override
  String get wizardContinue => 'Weiter';

  @override
  String get wizardFinish => 'Projekt anlegen';

  @override
  String get warningsSectionTitle => 'Hinweise zur Konfiguration';

  @override
  String warningInverterOversized(String inverter, String ratio) {
    return 'Wechselrichter „$inverter\" ist mit DC/AC-Verhältnis $ratio überdimensioniert — chronische Abregelung am Tag wahrscheinlich.';
  }

  @override
  String warningBankExceedsDischarge(
    String bank,
    String bankKw,
    String dischargeKw,
  ) {
    return 'Bank „$bank\" zieht $bankKw kW, der Speicher kann aber nur $dischargeKw kW liefern — dauerhafter Shortfall.';
  }

  @override
  String warningBatteryMinSocHigh(String battery, String pct) {
    return 'Speicher „$battery\" reserviert $pct% der Kapazität als minSOC — nutzbare Energie stark reduziert.';
  }

  @override
  String get hintIrradianceMissing =>
      'Noch keine Einstrahlungsdaten geladen. Die Simulation läuft mit dem synthetischen Demo-Modell — Lade Daten über den Einstrahlung-Tab für reale Werte.';
}
