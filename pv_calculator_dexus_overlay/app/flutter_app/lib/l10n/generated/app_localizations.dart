import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @commonAdd.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get commonAdd;

  /// No description provided for @commonRemove.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get commonRemove;

  /// No description provided for @commonCancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get commonCancel;

  /// No description provided for @commonOk.
  ///
  /// In de, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonDelete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get commonDelete;

  /// No description provided for @commonSearch.
  ///
  /// In de, this message translates to:
  /// **'Suchen'**
  String get commonSearch;

  /// No description provided for @validationRequired.
  ///
  /// In de, this message translates to:
  /// **'Pflichtfeld'**
  String get validationRequired;

  /// No description provided for @validationMustBeNumber.
  ///
  /// In de, this message translates to:
  /// **'Bitte eine Zahl eingeben'**
  String get validationMustBeNumber;

  /// No description provided for @validationAtLeast.
  ///
  /// In de, this message translates to:
  /// **'Mindestens {value}'**
  String validationAtLeast(String value);

  /// No description provided for @validationAtMost.
  ///
  /// In de, this message translates to:
  /// **'Höchstens {value}'**
  String validationAtMost(String value);

  /// No description provided for @drawerSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Demo · synthetisches Modell'**
  String get drawerSubtitle;

  /// No description provided for @drawerProjects.
  ///
  /// In de, this message translates to:
  /// **'Projekte'**
  String get drawerProjects;

  /// No description provided for @drawerSettings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get drawerSettings;

  /// No description provided for @drawerAbout.
  ///
  /// In de, this message translates to:
  /// **'Über'**
  String get drawerAbout;

  /// No description provided for @settingsTitle.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In de, this message translates to:
  /// **'Erscheinungsbild'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In de, this message translates to:
  /// **'Systemvorgabe folgen'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeSystemDesc.
  ///
  /// In de, this message translates to:
  /// **'Wechselt mit der Geräteeinstellung.'**
  String get settingsThemeSystemDesc;

  /// No description provided for @settingsThemeLight.
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In de, this message translates to:
  /// **'Systemsprache verwenden'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageSystemDesc.
  ///
  /// In de, this message translates to:
  /// **'Folgt der Sprache des Geräts.'**
  String get settingsLanguageSystemDesc;

  /// No description provided for @settingsAboutApp.
  ///
  /// In de, this message translates to:
  /// **'Über die App'**
  String get settingsAboutApp;

  /// No description provided for @settingsAboutBody.
  ///
  /// In de, this message translates to:
  /// **'Demo-Anwendung zur PV-Auslegung mit Batteriespeicher und 800-W-Micro-Wechselrichter. Das aktuelle Strahlungsmodell ist synthetisch und stellt keine validierte Ertragsprognose dar.'**
  String get settingsAboutBody;

  /// No description provided for @settingsAdvanced.
  ///
  /// In de, this message translates to:
  /// **'Erweitert'**
  String get settingsAdvanced;

  /// No description provided for @settingsExpertMode.
  ///
  /// In de, this message translates to:
  /// **'Expertenmodus'**
  String get settingsExpertMode;

  /// No description provided for @settingsExpertModeDesc.
  ///
  /// In de, this message translates to:
  /// **'Blendet Topologie-Editor, Mikro-Wechselrichter-Bänke und alternative Dispatch-Strategien im Auswertung-Tab ein.'**
  String get settingsExpertModeDesc;

  /// No description provided for @projectListTitle.
  ///
  /// In de, this message translates to:
  /// **'PV Calculator — Projekte'**
  String get projectListTitle;

  /// No description provided for @projectListEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Projekte gespeichert.'**
  String get projectListEmpty;

  /// No description provided for @projectListEmptyHint.
  ///
  /// In de, this message translates to:
  /// **'Lege ein neues Projekt an oder importiere ein gespeichertes JSON.'**
  String get projectListEmptyHint;

  /// No description provided for @projectListCreateButton.
  ///
  /// In de, this message translates to:
  /// **'Neues Projekt erstellen'**
  String get projectListCreateButton;

  /// No description provided for @projectListImportTooltip.
  ///
  /// In de, this message translates to:
  /// **'Importieren'**
  String get projectListImportTooltip;

  /// No description provided for @projectListNewTooltip.
  ///
  /// In de, this message translates to:
  /// **'Neues Projekt'**
  String get projectListNewTooltip;

  /// No description provided for @projectListExportTooltip.
  ///
  /// In de, this message translates to:
  /// **'Exportieren'**
  String get projectListExportTooltip;

  /// No description provided for @projectListDeleteTooltip.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get projectListDeleteTooltip;

  /// No description provided for @projectListNewDefaultName.
  ///
  /// In de, this message translates to:
  /// **'Neues Projekt'**
  String get projectListNewDefaultName;

  /// No description provided for @projectListLoadFailed.
  ///
  /// In de, this message translates to:
  /// **'Projekt \"{name}\" konnte nicht geladen werden.'**
  String projectListLoadFailed(String name);

  /// No description provided for @projectListImported.
  ///
  /// In de, this message translates to:
  /// **'Importiert: {name}'**
  String projectListImported(String name);

  /// No description provided for @projectListImportFailed.
  ///
  /// In de, this message translates to:
  /// **'Import fehlgeschlagen: {error}'**
  String projectListImportFailed(String error);

  /// No description provided for @projectListDownloaded.
  ///
  /// In de, this message translates to:
  /// **'Heruntergeladen: {filename}'**
  String projectListDownloaded(String filename);

  /// No description provided for @projectListExported.
  ///
  /// In de, this message translates to:
  /// **'Exportiert: {filename}'**
  String projectListExported(String filename);

  /// No description provided for @projectListExportCancelled.
  ///
  /// In de, this message translates to:
  /// **'Export abgebrochen'**
  String get projectListExportCancelled;

  /// No description provided for @projectListExportFailed.
  ///
  /// In de, this message translates to:
  /// **'Export fehlgeschlagen: {error}'**
  String projectListExportFailed(String error);

  /// No description provided for @projectListConflictTitle.
  ///
  /// In de, this message translates to:
  /// **'Projekt existiert bereits'**
  String get projectListConflictTitle;

  /// No description provided for @projectListConflictBody.
  ///
  /// In de, this message translates to:
  /// **'\"{name}\" ist bereits gespeichert. Soll der Import diese Version überschreiben oder unter einem neuen Namen abgelegt werden?'**
  String projectListConflictBody(String name);

  /// No description provided for @projectListConflictRename.
  ///
  /// In de, this message translates to:
  /// **'Umbenennen'**
  String get projectListConflictRename;

  /// No description provided for @projectListConflictOverwrite.
  ///
  /// In de, this message translates to:
  /// **'Überschreiben'**
  String get projectListConflictOverwrite;

  /// No description provided for @projectListDeleteTitle.
  ///
  /// In de, this message translates to:
  /// **'Projekt löschen?'**
  String get projectListDeleteTitle;

  /// No description provided for @projectListDeleteBody.
  ///
  /// In de, this message translates to:
  /// **'\"{name}\" wird unwiderruflich gelöscht.'**
  String projectListDeleteBody(String name);

  /// No description provided for @projectListSaveFailed.
  ///
  /// In de, this message translates to:
  /// **'Speichern fehlgeschlagen: {error}'**
  String projectListSaveFailed(String error);

  /// No description provided for @editorRun.
  ///
  /// In de, this message translates to:
  /// **'Simulation starten'**
  String get editorRun;

  /// No description provided for @editorValidationTitle.
  ///
  /// In de, this message translates to:
  /// **'Konfiguration unvollständig'**
  String get editorValidationTitle;

  /// No description provided for @editorRunErrorTitle.
  ///
  /// In de, this message translates to:
  /// **'Simulation fehlgeschlagen'**
  String get editorRunErrorTitle;

  /// No description provided for @editorOrphanedTitle.
  ///
  /// In de, this message translates to:
  /// **'PVGIS-Importe ohne passendes Modulfeld'**
  String get editorOrphanedTitle;

  /// No description provided for @editorOrphanedBody.
  ///
  /// In de, this message translates to:
  /// **'Die folgenden importierten Wetterreihen verweisen auf gelöschte oder umbenannte Modulfelder und werden von der Simulation nicht genutzt. Über „Vergessen“ kannst du sie freigeben.'**
  String get editorOrphanedBody;

  /// No description provided for @editorOrphanedForget.
  ///
  /// In de, this message translates to:
  /// **'Vergessen'**
  String get editorOrphanedForget;

  /// No description provided for @editorWeatherSynthetic.
  ///
  /// In de, this message translates to:
  /// **'Hinweis: Diese Simulation nutzt ein synthetisches Demo-Strahlungsmodell und ersetzt keine PVGIS-Validierung. Du kannst pro Modulfeld eine PVGIS-Stündliche-Daten-JSON importieren, um reale Einstrahlung zu nutzen.'**
  String get editorWeatherSynthetic;

  /// No description provided for @editorWeatherSession.
  ///
  /// In de, this message translates to:
  /// **' PVGIS-Importe gelten nur für diese Sitzung; beim erneuten Öffnen eines gespeicherten Projekts müssen sie neu importiert werden.'**
  String get editorWeatherSession;

  /// No description provided for @editorWeatherAll.
  ///
  /// In de, this message translates to:
  /// **'Wetterquelle: PVGIS-Daten für alle {total} Modulfelder importiert. TMY-Mittelwerte über die in der Datei enthaltenen Jahre.{session}'**
  String editorWeatherAll(int total, String session);

  /// No description provided for @editorWeatherMixed.
  ///
  /// In de, this message translates to:
  /// **'Wetterquelle gemischt: {withCount} von {total} Modulfeldern nutzen importierte PVGIS-Daten, die übrigen fallen auf das synthetische Demo-Modell zurück.{session}'**
  String editorWeatherMixed(int withCount, int total, String session);

  /// No description provided for @projectSectionTitle.
  ///
  /// In de, this message translates to:
  /// **'Projekt'**
  String get projectSectionTitle;

  /// No description provided for @projectName.
  ///
  /// In de, this message translates to:
  /// **'Projektname'**
  String get projectName;

  /// No description provided for @projectLatitude.
  ///
  /// In de, this message translates to:
  /// **'Breitengrad'**
  String get projectLatitude;

  /// No description provided for @projectLongitude.
  ///
  /// In de, this message translates to:
  /// **'Längengrad'**
  String get projectLongitude;

  /// No description provided for @projectStartDay.
  ///
  /// In de, this message translates to:
  /// **'Start-Tag im Jahr'**
  String get projectStartDay;

  /// No description provided for @projectSimulationDays.
  ///
  /// In de, this message translates to:
  /// **'Simulationstage'**
  String get projectSimulationDays;

  /// No description provided for @projectPreRunDays.
  ///
  /// In de, this message translates to:
  /// **'Vorlauf-Tage'**
  String get projectPreRunDays;

  /// No description provided for @projectPreRunHelp.
  ///
  /// In de, this message translates to:
  /// **'Anzahl Vorlauftage für den Modus „Einfacher Vorlauf“. Wird nur ausgewertet, wenn dieser Modus aktiv ist; die Vorlauf-Schritte erscheinen nicht in den Ergebnissen.'**
  String get projectPreRunHelp;

  /// No description provided for @projectPreRunMode.
  ///
  /// In de, this message translates to:
  /// **'SOC-Vorlauf'**
  String get projectPreRunMode;

  /// No description provided for @projectPreRunModeManual.
  ///
  /// In de, this message translates to:
  /// **'Manueller Start-SOC'**
  String get projectPreRunModeManual;

  /// No description provided for @projectPreRunModeSingle.
  ///
  /// In de, this message translates to:
  /// **'Einfacher Vorlauf'**
  String get projectPreRunModeSingle;

  /// No description provided for @projectPreRunModeCyclic.
  ///
  /// In de, this message translates to:
  /// **'Zyklische Konvergenz'**
  String get projectPreRunModeCyclic;

  /// No description provided for @projectPreRunModeCyclicPro.
  ///
  /// In de, this message translates to:
  /// **'Zyklische Konvergenz (Pro)'**
  String get projectPreRunModeCyclicPro;

  /// No description provided for @projectConvergenceTolerance.
  ///
  /// In de, this message translates to:
  /// **'Konvergenz-Toleranz'**
  String get projectConvergenceTolerance;

  /// No description provided for @projectConvergenceToleranceHelp.
  ///
  /// In de, this message translates to:
  /// **'Maximaler |Start − End|-SOC nach einem Zyklus, in % der nutzbaren Kapazität. PRD §6.2 empfiehlt 0,5 %.'**
  String get projectConvergenceToleranceHelp;

  /// No description provided for @projectMaxConvergenceIterations.
  ///
  /// In de, this message translates to:
  /// **'Max. Iterationen'**
  String get projectMaxConvergenceIterations;

  /// No description provided for @projectExportLimit.
  ///
  /// In de, this message translates to:
  /// **'Einspeise-Limit'**
  String get projectExportLimit;

  /// No description provided for @projectSimulationYears.
  ///
  /// In de, this message translates to:
  /// **'Simulationsjahre'**
  String get projectSimulationYears;

  /// No description provided for @projectSimulationYearsHelp.
  ///
  /// In de, this message translates to:
  /// **'Anzahl aufeinanderfolgender Jahre, die simuliert werden. Bei > 1 wird die Modulleistung pro Jahr um den Degradationsfaktor verringert; der SOC wird zwischen den Jahren übernommen.'**
  String get projectSimulationYearsHelp;

  /// No description provided for @pvArrayDegradation.
  ///
  /// In de, this message translates to:
  /// **'Degradation'**
  String get pvArrayDegradation;

  /// No description provided for @pvArrayDegradationHelp.
  ///
  /// In de, this message translates to:
  /// **'Jährlicher Leistungsabbau in %/Jahr. Typisch 0,4–0,7 für kristallines Silizium. Nur wirksam bei Simulationsjahre > 1.'**
  String get pvArrayDegradationHelp;

  /// No description provided for @tariffSectionTitle.
  ///
  /// In de, this message translates to:
  /// **'Strompreise'**
  String get tariffSectionTitle;

  /// No description provided for @tariffEnabled.
  ///
  /// In de, this message translates to:
  /// **'Wirtschaftlichkeit berechnen'**
  String get tariffEnabled;

  /// No description provided for @tariffEnabledHelp.
  ///
  /// In de, this message translates to:
  /// **'Berechnet Kosten und Einnahmen aus Bezug und Einspeisung anhand der eingegebenen Strompreise.'**
  String get tariffEnabledHelp;

  /// No description provided for @tariffImportLabel.
  ///
  /// In de, this message translates to:
  /// **'Bezugspreis'**
  String get tariffImportLabel;

  /// No description provided for @tariffExportLabel.
  ///
  /// In de, this message translates to:
  /// **'Einspeisevergütung'**
  String get tariffExportLabel;

  /// No description provided for @tariffTouTitle.
  ///
  /// In de, this message translates to:
  /// **'Zeitabhängige Tarife'**
  String get tariffTouTitle;

  /// No description provided for @tariffTouHelp.
  ///
  /// In de, this message translates to:
  /// **'24 Stunden-Slots für variable Bezugs-/Einspeisepreise. Pro-Feature.'**
  String get tariffTouHelp;

  /// No description provided for @tariffTouImportHeader.
  ///
  /// In de, this message translates to:
  /// **'Bezugspreise je Stunde (EUR/kWh)'**
  String get tariffTouImportHeader;

  /// No description provided for @tariffTouExportHeader.
  ///
  /// In de, this message translates to:
  /// **'Einspeisevergütung je Stunde (EUR/kWh)'**
  String get tariffTouExportHeader;

  /// No description provided for @resultsKpiImportCost.
  ///
  /// In de, this message translates to:
  /// **'Bezugskosten'**
  String get resultsKpiImportCost;

  /// No description provided for @resultsKpiExportRevenue.
  ///
  /// In de, this message translates to:
  /// **'Einspeise-Erlös'**
  String get resultsKpiExportRevenue;

  /// No description provided for @resultsKpiNetCost.
  ///
  /// In de, this message translates to:
  /// **'Netto-Stromkosten'**
  String get resultsKpiNetCost;

  /// No description provided for @resultsPdfReport.
  ///
  /// In de, this message translates to:
  /// **'Bericht exportieren (PDF)'**
  String get resultsPdfReport;

  /// No description provided for @resultsPdfReportProTooltip.
  ///
  /// In de, this message translates to:
  /// **'PDF-Berichte sind eine Pro-Funktion.'**
  String get resultsPdfReportProTooltip;

  /// No description provided for @pdfAppTitle.
  ///
  /// In de, this message translates to:
  /// **'PV Calculator'**
  String get pdfAppTitle;

  /// No description provided for @pdfGeneratedAt.
  ///
  /// In de, this message translates to:
  /// **'Erstellt {timestamp}  -  Engine {engineVersion}'**
  String pdfGeneratedAt(String timestamp, String engineVersion);

  /// No description provided for @pdfSectionPerYear.
  ///
  /// In de, this message translates to:
  /// **'Jahresweise Aufschlüsselung'**
  String get pdfSectionPerYear;

  /// No description provided for @pdfSectionMonthly.
  ///
  /// In de, this message translates to:
  /// **'Monatswerte'**
  String get pdfSectionMonthly;

  /// No description provided for @pdfSectionMonthlyFinalYear.
  ///
  /// In de, this message translates to:
  /// **'Monatswerte (nur letztes Jahr)'**
  String get pdfSectionMonthlyFinalYear;

  /// No description provided for @pdfSectionMonthlyCashflow.
  ///
  /// In de, this message translates to:
  /// **'Monatlicher Cashflow'**
  String get pdfSectionMonthlyCashflow;

  /// No description provided for @pdfSectionMonthlyCashflowFinalYear.
  ///
  /// In de, this message translates to:
  /// **'Monatlicher Cashflow (nur letztes Jahr)'**
  String get pdfSectionMonthlyCashflowFinalYear;

  /// No description provided for @pdfSectionArrays.
  ///
  /// In de, this message translates to:
  /// **'PV-Module'**
  String get pdfSectionArrays;

  /// No description provided for @pdfSectionBanks.
  ///
  /// In de, this message translates to:
  /// **'Micro-Wechselrichter-Bänke'**
  String get pdfSectionBanks;

  /// No description provided for @pdfSectionWarnings.
  ///
  /// In de, this message translates to:
  /// **'Warnungen'**
  String get pdfSectionWarnings;

  /// No description provided for @pdfColMetric.
  ///
  /// In de, this message translates to:
  /// **'Kennzahl'**
  String get pdfColMetric;

  /// No description provided for @pdfColValue.
  ///
  /// In de, this message translates to:
  /// **'Wert'**
  String get pdfColValue;

  /// No description provided for @pdfColYear.
  ///
  /// In de, this message translates to:
  /// **'Jahr'**
  String get pdfColYear;

  /// No description provided for @pdfColSelfShort.
  ///
  /// In de, this message translates to:
  /// **'Eigenverbr.'**
  String get pdfColSelfShort;

  /// No description provided for @pdfColMonth.
  ///
  /// In de, this message translates to:
  /// **'Monat'**
  String get pdfColMonth;

  /// No description provided for @pdfColSelfTight.
  ///
  /// In de, this message translates to:
  /// **'Eigen.'**
  String get pdfColSelfTight;

  /// No description provided for @pdfColCharge.
  ///
  /// In de, this message translates to:
  /// **'Ladung'**
  String get pdfColCharge;

  /// No description provided for @pdfColDischarge.
  ///
  /// In de, this message translates to:
  /// **'Entl.'**
  String get pdfColDischarge;

  /// No description provided for @pdfColImport.
  ///
  /// In de, this message translates to:
  /// **'Bezug'**
  String get pdfColImport;

  /// No description provided for @pdfColExport.
  ///
  /// In de, this message translates to:
  /// **'Einsp.'**
  String get pdfColExport;

  /// No description provided for @pdfColId.
  ///
  /// In de, this message translates to:
  /// **'ID'**
  String get pdfColId;

  /// No description provided for @pdfColLabel.
  ///
  /// In de, this message translates to:
  /// **'Bezeichnung'**
  String get pdfColLabel;

  /// No description provided for @pdfColPeakKw.
  ///
  /// In de, this message translates to:
  /// **'Peak kW'**
  String get pdfColPeakKw;

  /// No description provided for @pdfColAzimuth.
  ///
  /// In de, this message translates to:
  /// **'Azim.'**
  String get pdfColAzimuth;

  /// No description provided for @pdfColTilt.
  ///
  /// In de, this message translates to:
  /// **'Neig.'**
  String get pdfColTilt;

  /// No description provided for @pdfColInverter.
  ///
  /// In de, this message translates to:
  /// **'WR'**
  String get pdfColInverter;

  /// No description provided for @pdfColDegradation.
  ///
  /// In de, this message translates to:
  /// **'Degr. %/a'**
  String get pdfColDegradation;

  /// No description provided for @pdfColTargetKwh.
  ///
  /// In de, this message translates to:
  /// **'Soll kWh'**
  String get pdfColTargetKwh;

  /// No description provided for @pdfColDeliveredKwh.
  ///
  /// In de, this message translates to:
  /// **'Geliefert kWh'**
  String get pdfColDeliveredKwh;

  /// No description provided for @pdfColShortfallKwh.
  ///
  /// In de, this message translates to:
  /// **'Fehlbetrag kWh'**
  String get pdfColShortfallKwh;

  /// No description provided for @pdfColCoverage.
  ///
  /// In de, this message translates to:
  /// **'Abdeckung %'**
  String get pdfColCoverage;

  /// No description provided for @pdfFooterSynthetic.
  ///
  /// In de, this message translates to:
  /// **'Hinweis: Dieser Bericht wurde mit dem synthetischen Demo-Einstrahlungsmodell erstellt. Die Zahlen sind illustrativ und keine geprüfte Ertragsprognose.'**
  String get pdfFooterSynthetic;

  /// No description provided for @pdfFooterAgpl.
  ///
  /// In de, this message translates to:
  /// **'Erstellt mit PV Calculator (AGPL-3.0)  -  Engine {engineVersion}'**
  String pdfFooterAgpl(String engineVersion);

  /// No description provided for @projectTimeStep.
  ///
  /// In de, this message translates to:
  /// **'Zeitschritt'**
  String get projectTimeStep;

  /// No description provided for @projectTimeStepHourly.
  ///
  /// In de, this message translates to:
  /// **'Stündlich'**
  String get projectTimeStepHourly;

  /// No description provided for @projectTimeStepQuarter.
  ///
  /// In de, this message translates to:
  /// **'Viertelstündlich'**
  String get projectTimeStepQuarter;

  /// No description provided for @projectPvgisApiTitle.
  ///
  /// In de, this message translates to:
  /// **'PVGIS-API'**
  String get projectPvgisApiTitle;

  /// No description provided for @projectPvgisApiHelp.
  ///
  /// In de, this message translates to:
  /// **'Zeitfenster und Strahlungsdatenbank für „Von PVGIS-API laden“. PVGIS-SARAH3 deckt typischerweise 2005–2023 ab; je breiter das Fenster, desto stabiler werden TMY-Mittelwerte.'**
  String get projectPvgisApiHelp;

  /// No description provided for @projectPvgisStartYear.
  ///
  /// In de, this message translates to:
  /// **'PVGIS Startjahr'**
  String get projectPvgisStartYear;

  /// No description provided for @projectPvgisEndYear.
  ///
  /// In de, this message translates to:
  /// **'PVGIS Endjahr'**
  String get projectPvgisEndYear;

  /// No description provided for @projectRadDatabase.
  ///
  /// In de, this message translates to:
  /// **'Strahlungsdatenbank'**
  String get projectRadDatabase;

  /// No description provided for @projectRadDatabaseAuto.
  ///
  /// In de, this message translates to:
  /// **'PVGIS Auto'**
  String get projectRadDatabaseAuto;

  /// No description provided for @projectAddressSearch.
  ///
  /// In de, this message translates to:
  /// **'Adresse suchen (OpenStreetMap)'**
  String get projectAddressSearch;

  /// No description provided for @projectAddressHint.
  ///
  /// In de, this message translates to:
  /// **'z.B. Marktplatz 1, Frankfurt'**
  String get projectAddressHint;

  /// No description provided for @projectAddressNoResults.
  ///
  /// In de, this message translates to:
  /// **'Keine Treffer gefunden.'**
  String get projectAddressNoResults;

  /// No description provided for @fieldId.
  ///
  /// In de, this message translates to:
  /// **'ID'**
  String get fieldId;

  /// No description provided for @fieldLabel.
  ///
  /// In de, this message translates to:
  /// **'Bezeichnung'**
  String get fieldLabel;

  /// No description provided for @arraysTitle.
  ///
  /// In de, this message translates to:
  /// **'PV-Module'**
  String get arraysTitle;

  /// No description provided for @arraysEmpty.
  ///
  /// In de, this message translates to:
  /// **'Mindestens ein Modulfeld ist erforderlich.'**
  String get arraysEmpty;

  /// No description provided for @arraysDefaultLabel.
  ///
  /// In de, this message translates to:
  /// **'Modulfeld {n}'**
  String arraysDefaultLabel(int n);

  /// No description provided for @arraysHeading.
  ///
  /// In de, this message translates to:
  /// **'Modulfeld {n}'**
  String arraysHeading(int n);

  /// No description provided for @arraysFieldPeak.
  ///
  /// In de, this message translates to:
  /// **'Spitzenleistung'**
  String get arraysFieldPeak;

  /// No description provided for @arraysFieldAzimuth.
  ///
  /// In de, this message translates to:
  /// **'Azimut'**
  String get arraysFieldAzimuth;

  /// No description provided for @arraysFieldTilt.
  ///
  /// In de, this message translates to:
  /// **'Neigung'**
  String get arraysFieldTilt;

  /// No description provided for @arraysFieldLosses.
  ///
  /// In de, this message translates to:
  /// **'Verluste'**
  String get arraysFieldLosses;

  /// No description provided for @arraysFieldShading.
  ///
  /// In de, this message translates to:
  /// **'Verschattung'**
  String get arraysFieldShading;

  /// No description provided for @arraysFieldTempCoef.
  ///
  /// In de, this message translates to:
  /// **'Temperaturkoeff.'**
  String get arraysFieldTempCoef;

  /// No description provided for @arraysFieldTempCoefHelp.
  ///
  /// In de, this message translates to:
  /// **'Leistungsverlust pro °C Zelltemperatur über 25 °C. Kristallines Silizium ≈ −0,4 %/°C; 0 deaktiviert die Temperatur-Derating.'**
  String get arraysFieldTempCoefHelp;

  /// No description provided for @arraysFieldNoct.
  ///
  /// In de, this message translates to:
  /// **'NOCT'**
  String get arraysFieldNoct;

  /// No description provided for @arraysFieldNoctHelp.
  ///
  /// In de, this message translates to:
  /// **'Nominal Operating Cell Temperature: Zelltemperatur bei 800 W/m², 20 °C Luft, 1 m/s Wind. Typisch 45 °C.'**
  String get arraysFieldNoctHelp;

  /// No description provided for @arraysFieldInverter.
  ///
  /// In de, this message translates to:
  /// **'Wechselrichter'**
  String get arraysFieldInverter;

  /// No description provided for @arraysFieldInverterRequired.
  ///
  /// In de, this message translates to:
  /// **'Wechselrichter auswählen'**
  String get arraysFieldInverterRequired;

  /// No description provided for @pvgisIdRequired.
  ///
  /// In de, this message translates to:
  /// **'Bitte zuerst eine Modulfeld-ID vergeben.'**
  String get pvgisIdRequired;

  /// No description provided for @pvgisImported.
  ///
  /// In de, this message translates to:
  /// **'PVGIS-Daten für \"{id}\" importiert ({count} Werte).'**
  String pvgisImported(String id, int count);

  /// No description provided for @pvgisImportFailed.
  ///
  /// In de, this message translates to:
  /// **'PVGIS-Import fehlgeschlagen: {error}'**
  String pvgisImportFailed(String error);

  /// No description provided for @pvgisArrayNotFound.
  ///
  /// In de, this message translates to:
  /// **'Modulfeld nicht gefunden.'**
  String get pvgisArrayNotFound;

  /// No description provided for @pvgisInvalidRequest.
  ///
  /// In de, this message translates to:
  /// **'PVGIS-Abfrage ungültig: {error}'**
  String pvgisInvalidRequest(String error);

  /// No description provided for @pvgisApiLoaded.
  ///
  /// In de, this message translates to:
  /// **'PVGIS-API-Daten für \"{id}\" geladen ({count} Werte).'**
  String pvgisApiLoaded(String id, int count);

  /// No description provided for @pvgisApiFailed.
  ///
  /// In de, this message translates to:
  /// **'PVGIS-API-Abfrage fehlgeschlagen: {error}'**
  String pvgisApiFailed(String error);

  /// No description provided for @pvgisStatusSynthetic.
  ///
  /// In de, this message translates to:
  /// **'Wetterquelle: synthetisches Demo-Modell'**
  String get pvgisStatusSynthetic;

  /// No description provided for @pvgisStatusLoaded.
  ///
  /// In de, this message translates to:
  /// **'PVGIS-Daten geladen'**
  String get pvgisStatusLoaded;

  /// No description provided for @pvgisMetadata.
  ///
  /// In de, this message translates to:
  /// **'{source} · {count} Stunden · Jahre {years} · PVGIS-Lage {lat}°/{lon}°{orientation}'**
  String pvgisMetadata(
    String source,
    int count,
    String years,
    String lat,
    String lon,
    String orientation,
  );

  /// No description provided for @pvgisSessionNote.
  ///
  /// In de, this message translates to:
  /// **'Hinweis: PVGIS-Importe gelten nur für diese Sitzung — sie werden nicht im Projekt-JSON gespeichert.'**
  String get pvgisSessionNote;

  /// No description provided for @pvgisOrientationWarning.
  ///
  /// In de, this message translates to:
  /// **'PVGIS-Ausrichtung weicht ab ({issues}). Die importierten POA-Werte gelten für die PVGIS-Ausrichtung, nicht für die hier eingestellte.'**
  String pvgisOrientationWarning(String issues);

  /// No description provided for @pvgisOrientationTilt.
  ///
  /// In de, this message translates to:
  /// **'Neigung {value}°'**
  String pvgisOrientationTilt(String value);

  /// No description provided for @pvgisOrientationAzimuth.
  ///
  /// In de, this message translates to:
  /// **'Azimut {value}°'**
  String pvgisOrientationAzimuth(String value);

  /// No description provided for @pvgisTiltMismatch.
  ///
  /// In de, this message translates to:
  /// **'Neigung {imported}° vs {configured}°'**
  String pvgisTiltMismatch(String imported, String configured);

  /// No description provided for @pvgisAzimuthMismatch.
  ///
  /// In de, this message translates to:
  /// **'Azimut {imported}° vs {configured}°'**
  String pvgisAzimuthMismatch(String imported, String configured);

  /// No description provided for @pvgisReloadApi.
  ///
  /// In de, this message translates to:
  /// **'API neu laden'**
  String get pvgisReloadApi;

  /// No description provided for @pvgisLoadFromApi.
  ///
  /// In de, this message translates to:
  /// **'Von PVGIS-API laden'**
  String get pvgisLoadFromApi;

  /// No description provided for @pvgisImportJson.
  ///
  /// In de, this message translates to:
  /// **'JSON importieren'**
  String get pvgisImportJson;

  /// No description provided for @invertersTitle.
  ///
  /// In de, this message translates to:
  /// **'Wechselrichter'**
  String get invertersTitle;

  /// No description provided for @invertersEmpty.
  ///
  /// In de, this message translates to:
  /// **'Mindestens ein Wechselrichter ist erforderlich.'**
  String get invertersEmpty;

  /// No description provided for @invertersDefaultLabel.
  ///
  /// In de, this message translates to:
  /// **'Wechselrichter {n}'**
  String invertersDefaultLabel(int n);

  /// No description provided for @invertersHeading.
  ///
  /// In de, this message translates to:
  /// **'Wechselrichter {n}'**
  String invertersHeading(int n);

  /// No description provided for @invertersFieldMaxAc.
  ///
  /// In de, this message translates to:
  /// **'Max. AC-Leistung'**
  String get invertersFieldMaxAc;

  /// No description provided for @invertersFieldEfficiency.
  ///
  /// In de, this message translates to:
  /// **'Wirkungsgrad'**
  String get invertersFieldEfficiency;

  /// No description provided for @invertersFieldMaxDc.
  ///
  /// In de, this message translates to:
  /// **'Max. DC-Eingang'**
  String get invertersFieldMaxDc;

  /// No description provided for @invertersFieldMaxDcHelp.
  ///
  /// In de, this message translates to:
  /// **'Optionale DC-Eingangsgrenze (MPPT). DC-Leistung darüber wird vor dem Wechselrichter geclippt und als Abregelung erfasst. Leer lassen, wenn der Wechselrichter nicht überdimensioniert ist.'**
  String get invertersFieldMaxDcHelp;

  /// No description provided for @invertersFieldRole.
  ///
  /// In de, this message translates to:
  /// **'Rolle'**
  String get invertersFieldRole;

  /// No description provided for @invertersRoleGrid.
  ///
  /// In de, this message translates to:
  /// **'Netz'**
  String get invertersRoleGrid;

  /// No description provided for @invertersRoleMicro.
  ///
  /// In de, this message translates to:
  /// **'800-W-Micro'**
  String get invertersRoleMicro;

  /// No description provided for @invertersRoleBattery.
  ///
  /// In de, this message translates to:
  /// **'Batteriegekoppelt'**
  String get invertersRoleBattery;

  /// No description provided for @invertersRoleMicroHelp.
  ///
  /// In de, this message translates to:
  /// **'800-W-Stecker-Solar: AC-Ausgang wird hart auf 0,8 kW gekappt, unabhängig von der eingestellten Max. AC-Leistung.'**
  String get invertersRoleMicroHelp;

  /// No description provided for @invertersRoleBatteryHelp.
  ///
  /// In de, this message translates to:
  /// **'Wechselrichter ist DC-seitig mit einer Batterie gekoppelt; Erfassung wie ein Netz-Wechselrichter, aber semantisch markiert.'**
  String get invertersRoleBatteryHelp;

  /// No description provided for @invertersRoleGridHelp.
  ///
  /// In de, this message translates to:
  /// **'Standard-Netz-Wechselrichter ohne harte AC-Hürde.'**
  String get invertersRoleGridHelp;

  /// No description provided for @batteriesTitle.
  ///
  /// In de, this message translates to:
  /// **'Batteriespeicher'**
  String get batteriesTitle;

  /// No description provided for @batteriesEmpty.
  ///
  /// In de, this message translates to:
  /// **'Kein Batteriespeicher konfiguriert (optional).'**
  String get batteriesEmpty;

  /// No description provided for @batteriesDefaultLabel.
  ///
  /// In de, this message translates to:
  /// **'Speicher {n}'**
  String batteriesDefaultLabel(int n);

  /// No description provided for @batteriesHeading.
  ///
  /// In de, this message translates to:
  /// **'Speicher {n}'**
  String batteriesHeading(int n);

  /// No description provided for @batteriesFieldCapacity.
  ///
  /// In de, this message translates to:
  /// **'Kapazität'**
  String get batteriesFieldCapacity;

  /// No description provided for @batteriesFieldChargePower.
  ///
  /// In de, this message translates to:
  /// **'Max. Ladeleistung'**
  String get batteriesFieldChargePower;

  /// No description provided for @batteriesFieldDischargePower.
  ///
  /// In de, this message translates to:
  /// **'Max. Entladeleistung'**
  String get batteriesFieldDischargePower;

  /// No description provided for @batteriesFieldRoundtrip.
  ///
  /// In de, this message translates to:
  /// **'Roundtrip-Wirkungsgrad'**
  String get batteriesFieldRoundtrip;

  /// No description provided for @batteriesFieldRoundtripHelp.
  ///
  /// In de, this message translates to:
  /// **'Lade- × Entladewirkungsgrad. Typisch 0,9 für Lithium-Speicher, ≈ 0,75 für Blei-Speicher.'**
  String get batteriesFieldRoundtripHelp;

  /// No description provided for @batteriesFieldMinSoc.
  ///
  /// In de, this message translates to:
  /// **'Min. SOC'**
  String get batteriesFieldMinSoc;

  /// No description provided for @batteriesCustomInitial.
  ///
  /// In de, this message translates to:
  /// **'Start-SOC manuell setzen'**
  String get batteriesCustomInitial;

  /// No description provided for @batteriesFieldStartSoc.
  ///
  /// In de, this message translates to:
  /// **'Start-SOC'**
  String get batteriesFieldStartSoc;

  /// No description provided for @loadTitle.
  ///
  /// In de, this message translates to:
  /// **'Lastprofil'**
  String get loadTitle;

  /// No description provided for @loadFieldDaily.
  ///
  /// In de, this message translates to:
  /// **'Tagesverbrauch'**
  String get loadFieldDaily;

  /// No description provided for @loadHourlyHint.
  ///
  /// In de, this message translates to:
  /// **'Stundenform: deutsches Haushalts-Standardprofil (24 Werte). Eine manuelle Anpassung der Stundenform ist für eine spätere Version vorgesehen.'**
  String get loadHourlyHint;

  /// No description provided for @loadCsvImportButton.
  ///
  /// In de, this message translates to:
  /// **'CSV importieren'**
  String get loadCsvImportButton;

  /// No description provided for @loadCsvImportSuccess.
  ///
  /// In de, this message translates to:
  /// **'Lastprofil aus CSV übernommen ({dailyKwh} kWh/Tag).'**
  String loadCsvImportSuccess(String dailyKwh);

  /// No description provided for @loadCsvImportError.
  ///
  /// In de, this message translates to:
  /// **'Import fehlgeschlagen: {error}'**
  String loadCsvImportError(String error);

  /// No description provided for @loadHourlySummary.
  ///
  /// In de, this message translates to:
  /// **'Stundenprofil aus Import (Spitze {peakHour} Uhr: {peakKwh} kWh).'**
  String loadHourlySummary(int peakHour, String peakKwh);

  /// No description provided for @resultsTitle.
  ///
  /// In de, this message translates to:
  /// **'Ergebnis — {name}'**
  String resultsTitle(String name);

  /// No description provided for @resultsEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine Simulation ausgeführt.'**
  String get resultsEmpty;

  /// No description provided for @resultsBack.
  ///
  /// In de, this message translates to:
  /// **'Zurück zur Konfiguration'**
  String get resultsBack;

  /// No description provided for @resultsAnnualKpis.
  ///
  /// In de, this message translates to:
  /// **'Jahreskennzahlen'**
  String get resultsAnnualKpis;

  /// No description provided for @resultsKpiPvAc.
  ///
  /// In de, this message translates to:
  /// **'PV AC'**
  String get resultsKpiPvAc;

  /// No description provided for @resultsKpiLoad.
  ///
  /// In de, this message translates to:
  /// **'Last'**
  String get resultsKpiLoad;

  /// No description provided for @resultsKpiSelfConsumption.
  ///
  /// In de, this message translates to:
  /// **'Eigenverbrauch'**
  String get resultsKpiSelfConsumption;

  /// No description provided for @resultsKpiGridImport.
  ///
  /// In de, this message translates to:
  /// **'Netzimport'**
  String get resultsKpiGridImport;

  /// No description provided for @resultsKpiGridExport.
  ///
  /// In de, this message translates to:
  /// **'Netzeinspeisung'**
  String get resultsKpiGridExport;

  /// No description provided for @resultsKpiCurtailDc.
  ///
  /// In de, this message translates to:
  /// **'Abregelung DC (MPPT)'**
  String get resultsKpiCurtailDc;

  /// No description provided for @resultsKpiCurtailAc.
  ///
  /// In de, this message translates to:
  /// **'Abregelung AC (WR-Limit)'**
  String get resultsKpiCurtailAc;

  /// No description provided for @resultsKpiCurtailExport.
  ///
  /// In de, this message translates to:
  /// **'Abregelung Einspeisung'**
  String get resultsKpiCurtailExport;

  /// No description provided for @resultsKpiBatteryCharge.
  ///
  /// In de, this message translates to:
  /// **'Batt-Ladung'**
  String get resultsKpiBatteryCharge;

  /// No description provided for @resultsKpiBatteryDischarge.
  ///
  /// In de, this message translates to:
  /// **'Batt-Entladung'**
  String get resultsKpiBatteryDischarge;

  /// No description provided for @resultsKpiAutarky.
  ///
  /// In de, this message translates to:
  /// **'Autarkie'**
  String get resultsKpiAutarky;

  /// No description provided for @resultsKpiSelfConsumptionRate.
  ///
  /// In de, this message translates to:
  /// **'EV-Quote'**
  String get resultsKpiSelfConsumptionRate;

  /// No description provided for @resultsBatterySection.
  ///
  /// In de, this message translates to:
  /// **'Batterien (End-SOC)'**
  String get resultsBatterySection;

  /// No description provided for @resultsBatteryLabel.
  ///
  /// In de, this message translates to:
  /// **'Speicher {n}'**
  String resultsBatteryLabel(int n);

  /// No description provided for @resultsPreRunSection.
  ///
  /// In de, this message translates to:
  /// **'SOC-Vorlauf'**
  String get resultsPreRunSection;

  /// No description provided for @resultsPreRunMode.
  ///
  /// In de, this message translates to:
  /// **'Modus'**
  String get resultsPreRunMode;

  /// No description provided for @resultsPreRunIterations.
  ///
  /// In de, this message translates to:
  /// **'Iterationen'**
  String get resultsPreRunIterations;

  /// No description provided for @resultsPreRunConverged.
  ///
  /// In de, this message translates to:
  /// **'Konvergiert'**
  String get resultsPreRunConverged;

  /// No description provided for @resultsPreRunConvergedYes.
  ///
  /// In de, this message translates to:
  /// **'Ja'**
  String get resultsPreRunConvergedYes;

  /// No description provided for @resultsPreRunConvergedNo.
  ///
  /// In de, this message translates to:
  /// **'Nein'**
  String get resultsPreRunConvergedNo;

  /// No description provided for @resultsPreRunStartSoc.
  ///
  /// In de, this message translates to:
  /// **'Start-SOC Speicher {n}'**
  String resultsPreRunStartSoc(int n);

  /// No description provided for @resultsMonthly.
  ///
  /// In de, this message translates to:
  /// **'Monatliche Bilanz'**
  String get resultsMonthly;

  /// No description provided for @resultsCsvSteps.
  ///
  /// In de, this message translates to:
  /// **'CSV-Export Schritte'**
  String get resultsCsvSteps;

  /// No description provided for @resultsCsvMonthly.
  ///
  /// In de, this message translates to:
  /// **'CSV-Export Monat'**
  String get resultsCsvMonthly;

  /// No description provided for @resultsCsvPending.
  ///
  /// In de, this message translates to:
  /// **'CSV bereit ({size} Zeichen). Export folgt im Persistence-Layer.'**
  String resultsCsvPending(int size);

  /// No description provided for @resultsExported.
  ///
  /// In de, this message translates to:
  /// **'Exportiert: {filename}'**
  String resultsExported(String filename);

  /// No description provided for @resultsExportFailed.
  ///
  /// In de, this message translates to:
  /// **'Export fehlgeschlagen: {error}'**
  String resultsExportFailed(String error);

  /// No description provided for @resultsSyntheticNote.
  ///
  /// In de, this message translates to:
  /// **'Hinweis: synthetisches Demo-Strahlungsmodell — keine validierte Ertragsprognose.'**
  String get resultsSyntheticNote;

  /// No description provided for @monthlyColMonth.
  ///
  /// In de, this message translates to:
  /// **'Monat'**
  String get monthlyColMonth;

  /// No description provided for @monthlyColPvAc.
  ///
  /// In de, this message translates to:
  /// **'PV AC (kWh)'**
  String get monthlyColPvAc;

  /// No description provided for @monthlyColLoad.
  ///
  /// In de, this message translates to:
  /// **'Last (kWh)'**
  String get monthlyColLoad;

  /// No description provided for @monthlyColSelfConsumption.
  ///
  /// In de, this message translates to:
  /// **'EV (kWh)'**
  String get monthlyColSelfConsumption;

  /// No description provided for @monthlyColBatteryCharge.
  ///
  /// In de, this message translates to:
  /// **'Bat-Lad. (kWh)'**
  String get monthlyColBatteryCharge;

  /// No description provided for @monthlyColBatteryDischarge.
  ///
  /// In de, this message translates to:
  /// **'Bat-Entl. (kWh)'**
  String get monthlyColBatteryDischarge;

  /// No description provided for @monthlyColImport.
  ///
  /// In de, this message translates to:
  /// **'Import (kWh)'**
  String get monthlyColImport;

  /// No description provided for @monthlyColExport.
  ///
  /// In de, this message translates to:
  /// **'Export (kWh)'**
  String get monthlyColExport;

  /// No description provided for @monthlyColImportCost.
  ///
  /// In de, this message translates to:
  /// **'Bezugskosten (€)'**
  String get monthlyColImportCost;

  /// No description provided for @monthlyColExportRevenue.
  ///
  /// In de, this message translates to:
  /// **'Einspeise-Erlös (€)'**
  String get monthlyColExportRevenue;

  /// No description provided for @monthlyColNetCost.
  ///
  /// In de, this message translates to:
  /// **'Netto (€)'**
  String get monthlyColNetCost;

  /// No description provided for @catalogPickButton.
  ///
  /// In de, this message translates to:
  /// **'Aus Bibliothek wählen'**
  String get catalogPickButton;

  /// No description provided for @catalogPickerTitle.
  ///
  /// In de, this message translates to:
  /// **'Komponente wählen'**
  String get catalogPickerTitle;

  /// No description provided for @catalogSearchHint.
  ///
  /// In de, this message translates to:
  /// **'Suchen'**
  String get catalogSearchHint;

  /// No description provided for @catalogEmptyState.
  ///
  /// In de, this message translates to:
  /// **'Keine passenden Einträge'**
  String get catalogEmptyState;

  /// No description provided for @catalogModuleCountPrompt.
  ///
  /// In de, this message translates to:
  /// **'Anzahl Module'**
  String get catalogModuleCountPrompt;

  /// No description provided for @catalogRoleGrid.
  ///
  /// In de, this message translates to:
  /// **'Netz'**
  String get catalogRoleGrid;

  /// No description provided for @catalogRoleBattery.
  ///
  /// In de, this message translates to:
  /// **'Speicher'**
  String get catalogRoleBattery;

  /// No description provided for @catalogRoleMicro.
  ///
  /// In de, this message translates to:
  /// **'Mikro 800 W'**
  String get catalogRoleMicro;

  /// No description provided for @catalogLoadError.
  ///
  /// In de, this message translates to:
  /// **'Bibliothek konnte nicht geladen werden:'**
  String get catalogLoadError;

  /// No description provided for @drawerCatalog.
  ///
  /// In de, this message translates to:
  /// **'Komponentenbibliothek'**
  String get drawerCatalog;

  /// No description provided for @catalogManagerTitle.
  ///
  /// In de, this message translates to:
  /// **'Komponentenbibliothek verwalten'**
  String get catalogManagerTitle;

  /// No description provided for @catalogManagerTabModules.
  ///
  /// In de, this message translates to:
  /// **'Module'**
  String get catalogManagerTabModules;

  /// No description provided for @catalogManagerTabInverters.
  ///
  /// In de, this message translates to:
  /// **'Wechselrichter'**
  String get catalogManagerTabInverters;

  /// No description provided for @catalogManagerTabBatteries.
  ///
  /// In de, this message translates to:
  /// **'Batterien'**
  String get catalogManagerTabBatteries;

  /// No description provided for @catalogManagerUserSection.
  ///
  /// In de, this message translates to:
  /// **'Eigene Einträge'**
  String get catalogManagerUserSection;

  /// No description provided for @catalogManagerSeedSection.
  ///
  /// In de, this message translates to:
  /// **'Mitgelieferter Seed (schreibgeschützt)'**
  String get catalogManagerSeedSection;

  /// No description provided for @catalogManagerEmptyUser.
  ///
  /// In de, this message translates to:
  /// **'Noch keine eigenen Einträge.'**
  String get catalogManagerEmptyUser;

  /// No description provided for @catalogManagerImportTooltip.
  ///
  /// In de, this message translates to:
  /// **'Importieren'**
  String get catalogManagerImportTooltip;

  /// No description provided for @catalogManagerExportTooltip.
  ///
  /// In de, this message translates to:
  /// **'Exportieren'**
  String get catalogManagerExportTooltip;

  /// No description provided for @catalogManagerExportEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine eigenen Einträge zum Exportieren.'**
  String get catalogManagerExportEmpty;

  /// No description provided for @catalogManagerEditTooltip.
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get catalogManagerEditTooltip;

  /// No description provided for @catalogManagerDeleteTooltip.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get catalogManagerDeleteTooltip;

  /// No description provided for @catalogManagerDuplicateTooltip.
  ///
  /// In de, this message translates to:
  /// **'Als eigenen Eintrag kopieren'**
  String get catalogManagerDuplicateTooltip;

  /// No description provided for @catalogManagerDuplicatePrefix.
  ///
  /// In de, this message translates to:
  /// **'Eigene Kopie — '**
  String get catalogManagerDuplicatePrefix;

  /// No description provided for @catalogManagerAddModuleFab.
  ///
  /// In de, this message translates to:
  /// **'Modul hinzufügen'**
  String get catalogManagerAddModuleFab;

  /// No description provided for @catalogManagerAddInverterFab.
  ///
  /// In de, this message translates to:
  /// **'Wechselrichter hinzufügen'**
  String get catalogManagerAddInverterFab;

  /// No description provided for @catalogManagerAddBatteryFab.
  ///
  /// In de, this message translates to:
  /// **'Batterie hinzufügen'**
  String get catalogManagerAddBatteryFab;

  /// No description provided for @catalogManagerDeleteConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'Eintrag löschen?'**
  String get catalogManagerDeleteConfirmTitle;

  /// No description provided for @catalogManagerDeleteConfirmBody.
  ///
  /// In de, this message translates to:
  /// **'„{name}\" wird aus deiner Bibliothek entfernt.'**
  String catalogManagerDeleteConfirmBody(String name);

  /// No description provided for @catalogManagerImportConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'Import bestätigen'**
  String get catalogManagerImportConfirmTitle;

  /// No description provided for @catalogManagerImportConfirmBody.
  ///
  /// In de, this message translates to:
  /// **'{newCount} neue, {overwriteCount} vorhandene Einträge werden überschrieben.'**
  String catalogManagerImportConfirmBody(int newCount, int overwriteCount);

  /// No description provided for @catalogManagerImportConfirmAccept.
  ///
  /// In de, this message translates to:
  /// **'Übernehmen'**
  String get catalogManagerImportConfirmAccept;

  /// No description provided for @catalogManagerImportSuccess.
  ///
  /// In de, this message translates to:
  /// **'Importiert: {added} neu, {updated} aktualisiert.'**
  String catalogManagerImportSuccess(int added, int updated);

  /// No description provided for @catalogManagerImportFailed.
  ///
  /// In de, this message translates to:
  /// **'Import fehlgeschlagen: {error}'**
  String catalogManagerImportFailed(String error);

  /// No description provided for @catalogManagerExportSuccess.
  ///
  /// In de, this message translates to:
  /// **'Exportiert: {filename}'**
  String catalogManagerExportSuccess(String filename);

  /// No description provided for @catalogManagerExportCancelled.
  ///
  /// In de, this message translates to:
  /// **'Export abgebrochen'**
  String get catalogManagerExportCancelled;

  /// No description provided for @catalogManagerExportFailed.
  ///
  /// In de, this message translates to:
  /// **'Export fehlgeschlagen: {error}'**
  String catalogManagerExportFailed(String error);

  /// No description provided for @catalogEditorTitleNewModule.
  ///
  /// In de, this message translates to:
  /// **'Neues Modul'**
  String get catalogEditorTitleNewModule;

  /// No description provided for @catalogEditorTitleNewInverter.
  ///
  /// In de, this message translates to:
  /// **'Neuer Wechselrichter'**
  String get catalogEditorTitleNewInverter;

  /// No description provided for @catalogEditorTitleNewBattery.
  ///
  /// In de, this message translates to:
  /// **'Neue Batterie'**
  String get catalogEditorTitleNewBattery;

  /// No description provided for @catalogEditorTitleEdit.
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten: {name}'**
  String catalogEditorTitleEdit(String name);

  /// No description provided for @catalogEditorSave.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get catalogEditorSave;

  /// No description provided for @catalogEditorFieldId.
  ///
  /// In de, this message translates to:
  /// **'ID'**
  String get catalogEditorFieldId;

  /// No description provided for @catalogEditorFieldIdHelp.
  ///
  /// In de, this message translates to:
  /// **'Eindeutige Kennung. Beim Bearbeiten gesperrt — zum Umbenennen den Eintrag löschen und neu anlegen.'**
  String get catalogEditorFieldIdHelp;

  /// No description provided for @catalogEditorFieldManufacturer.
  ///
  /// In de, this message translates to:
  /// **'Hersteller'**
  String get catalogEditorFieldManufacturer;

  /// No description provided for @catalogEditorFieldModel.
  ///
  /// In de, this message translates to:
  /// **'Modell'**
  String get catalogEditorFieldModel;

  /// No description provided for @catalogEditorFieldSourceUrl.
  ///
  /// In de, this message translates to:
  /// **'Quelle/URL'**
  String get catalogEditorFieldSourceUrl;

  /// No description provided for @catalogEditorFieldNotes.
  ///
  /// In de, this message translates to:
  /// **'Notizen'**
  String get catalogEditorFieldNotes;

  /// No description provided for @catalogEditorFieldPeakKwPerModule.
  ///
  /// In de, this message translates to:
  /// **'Spitzenleistung pro Modul (kWp)'**
  String get catalogEditorFieldPeakKwPerModule;

  /// No description provided for @catalogEditorFieldCellTech.
  ///
  /// In de, this message translates to:
  /// **'Zelltechnologie'**
  String get catalogEditorFieldCellTech;

  /// No description provided for @catalogEditorFieldTempCoef.
  ///
  /// In de, this message translates to:
  /// **'Temperaturkoeff. (%/°C)'**
  String get catalogEditorFieldTempCoef;

  /// No description provided for @catalogEditorFieldNoct.
  ///
  /// In de, this message translates to:
  /// **'NOCT (°C)'**
  String get catalogEditorFieldNoct;

  /// No description provided for @catalogEditorFieldDegradation.
  ///
  /// In de, this message translates to:
  /// **'Degradation (%/Jahr)'**
  String get catalogEditorFieldDegradation;

  /// No description provided for @catalogEditorFieldMaxAcKw.
  ///
  /// In de, this message translates to:
  /// **'Max. AC-Leistung (kW)'**
  String get catalogEditorFieldMaxAcKw;

  /// No description provided for @catalogEditorFieldMaxDcKw.
  ///
  /// In de, this message translates to:
  /// **'Max. DC-Eingang (kW)'**
  String get catalogEditorFieldMaxDcKw;

  /// No description provided for @catalogEditorFieldEfficiency.
  ///
  /// In de, this message translates to:
  /// **'Wirkungsgrad'**
  String get catalogEditorFieldEfficiency;

  /// No description provided for @catalogEditorFieldRole.
  ///
  /// In de, this message translates to:
  /// **'Rolle'**
  String get catalogEditorFieldRole;

  /// No description provided for @catalogEditorFieldCapacityKwh.
  ///
  /// In de, this message translates to:
  /// **'Kapazität (kWh)'**
  String get catalogEditorFieldCapacityKwh;

  /// No description provided for @catalogEditorFieldChargeKw.
  ///
  /// In de, this message translates to:
  /// **'Max. Ladeleistung (kW)'**
  String get catalogEditorFieldChargeKw;

  /// No description provided for @catalogEditorFieldDischargeKw.
  ///
  /// In de, this message translates to:
  /// **'Max. Entladeleistung (kW)'**
  String get catalogEditorFieldDischargeKw;

  /// No description provided for @catalogEditorFieldChemistry.
  ///
  /// In de, this message translates to:
  /// **'Chemie'**
  String get catalogEditorFieldChemistry;

  /// No description provided for @catalogEditorFieldRoundtrip.
  ///
  /// In de, this message translates to:
  /// **'Roundtrip-Wirkungsgrad'**
  String get catalogEditorFieldRoundtrip;

  /// No description provided for @catalogEditorFieldMinSoc.
  ///
  /// In de, this message translates to:
  /// **'Min. SOC (kWh)'**
  String get catalogEditorFieldMinSoc;

  /// No description provided for @catalogEditorValidationFailed.
  ///
  /// In de, this message translates to:
  /// **'Validierung fehlgeschlagen: {error}'**
  String catalogEditorValidationFailed(String error);

  /// No description provided for @catalogEditorIdConflictTitle.
  ///
  /// In de, this message translates to:
  /// **'ID existiert bereits'**
  String get catalogEditorIdConflictTitle;

  /// No description provided for @catalogEditorIdConflictBody.
  ///
  /// In de, this message translates to:
  /// **'Ein eigener Eintrag mit der ID „{id}\" existiert bereits. Überschreiben?'**
  String catalogEditorIdConflictBody(String id);

  /// No description provided for @catalogEditorIdConflictOverwrite.
  ///
  /// In de, this message translates to:
  /// **'Überschreiben'**
  String get catalogEditorIdConflictOverwrite;

  /// No description provided for @monthJan.
  ///
  /// In de, this message translates to:
  /// **'Jan'**
  String get monthJan;

  /// No description provided for @monthFeb.
  ///
  /// In de, this message translates to:
  /// **'Feb'**
  String get monthFeb;

  /// No description provided for @monthMar.
  ///
  /// In de, this message translates to:
  /// **'Mär'**
  String get monthMar;

  /// No description provided for @monthApr.
  ///
  /// In de, this message translates to:
  /// **'Apr'**
  String get monthApr;

  /// No description provided for @monthMay.
  ///
  /// In de, this message translates to:
  /// **'Mai'**
  String get monthMay;

  /// No description provided for @monthJun.
  ///
  /// In de, this message translates to:
  /// **'Jun'**
  String get monthJun;

  /// No description provided for @monthJul.
  ///
  /// In de, this message translates to:
  /// **'Jul'**
  String get monthJul;

  /// No description provided for @monthAug.
  ///
  /// In de, this message translates to:
  /// **'Aug'**
  String get monthAug;

  /// No description provided for @monthSep.
  ///
  /// In de, this message translates to:
  /// **'Sep'**
  String get monthSep;

  /// No description provided for @monthOct.
  ///
  /// In de, this message translates to:
  /// **'Okt'**
  String get monthOct;

  /// No description provided for @monthNov.
  ///
  /// In de, this message translates to:
  /// **'Nov'**
  String get monthNov;

  /// No description provided for @monthDec.
  ///
  /// In de, this message translates to:
  /// **'Dez'**
  String get monthDec;

  /// No description provided for @geocodingTimeout.
  ///
  /// In de, this message translates to:
  /// **'Zeitüberschreitung bei der Adresssuche.'**
  String get geocodingTimeout;

  /// No description provided for @geocodingNetworkError.
  ///
  /// In de, this message translates to:
  /// **'Netzwerkfehler: {error}'**
  String geocodingNetworkError(String error);

  /// No description provided for @geocodingRateLimit.
  ///
  /// In de, this message translates to:
  /// **'Nominatim hat das Limit erreicht (429). Bitte einen Moment warten.'**
  String get geocodingRateLimit;

  /// No description provided for @geocodingBadStatus.
  ///
  /// In de, this message translates to:
  /// **'Nominatim antwortete mit Status {code}.'**
  String geocodingBadStatus(int code);

  /// No description provided for @geocodingInvalidJson.
  ///
  /// In de, this message translates to:
  /// **'Antwort von Nominatim ist kein gültiges JSON.'**
  String get geocodingInvalidJson;

  /// No description provided for @geocodingInvalidFormat.
  ///
  /// In de, this message translates to:
  /// **'Unerwartetes Antwortformat von Nominatim.'**
  String get geocodingInvalidFormat;

  /// No description provided for @pvgisApiInvalidRequest.
  ///
  /// In de, this message translates to:
  /// **'Ungültige PVGIS-Anfrage: {error}'**
  String pvgisApiInvalidRequest(String error);

  /// No description provided for @pvgisApiTimeout.
  ///
  /// In de, this message translates to:
  /// **'Zeitüberschreitung bei PVGIS-Abfrage.'**
  String get pvgisApiTimeout;

  /// No description provided for @pvgisApiNetworkError.
  ///
  /// In de, this message translates to:
  /// **'Netzwerkfehler bei PVGIS-Abfrage: {error}'**
  String pvgisApiNetworkError(String error);

  /// No description provided for @pvgisApiBadStatus.
  ///
  /// In de, this message translates to:
  /// **'PVGIS antwortete mit Status {code}. {message}'**
  String pvgisApiBadStatus(int code, String message);

  /// No description provided for @pvgisApiParseFailed.
  ///
  /// In de, this message translates to:
  /// **'PVGIS-Antwort konnte nicht gelesen werden: {error}'**
  String pvgisApiParseFailed(String error);

  /// No description provided for @demoArrayLabel.
  ///
  /// In de, this message translates to:
  /// **'Süddach'**
  String get demoArrayLabel;

  /// No description provided for @demoInverterLabel.
  ///
  /// In de, this message translates to:
  /// **'Hauptwechselrichter'**
  String get demoInverterLabel;

  /// No description provided for @demoBatteryLabel.
  ///
  /// In de, this message translates to:
  /// **'Hauptspeicher'**
  String get demoBatteryLabel;

  /// No description provided for @tabProjects.
  ///
  /// In de, this message translates to:
  /// **'Projekte'**
  String get tabProjects;

  /// No description provided for @tabIrradiance.
  ///
  /// In de, this message translates to:
  /// **'Einstrahlung'**
  String get tabIrradiance;

  /// No description provided for @tabArrays.
  ///
  /// In de, this message translates to:
  /// **'PV-Arrays'**
  String get tabArrays;

  /// No description provided for @tabResults.
  ///
  /// In de, this message translates to:
  /// **'Auswertung'**
  String get tabResults;

  /// No description provided for @irradianceTitle.
  ///
  /// In de, this message translates to:
  /// **'Standort & Einstrahlung'**
  String get irradianceTitle;

  /// No description provided for @irradianceMapHint.
  ///
  /// In de, this message translates to:
  /// **'Karte verschieben, um den Standort zu setzen. Pin = Projektkoordinaten.'**
  String get irradianceMapHint;

  /// No description provided for @irradianceYearLabel.
  ///
  /// In de, this message translates to:
  /// **'Zeitraum'**
  String get irradianceYearLabel;

  /// No description provided for @irradianceLoadButton.
  ///
  /// In de, this message translates to:
  /// **'Lade Daten'**
  String get irradianceLoadButton;

  /// No description provided for @irradianceLoadingHint.
  ///
  /// In de, this message translates to:
  /// **'Strahlungsdaten werden geladen …'**
  String get irradianceLoadingHint;

  /// No description provided for @irradianceEmpty.
  ///
  /// In de, this message translates to:
  /// **'Standort wählen und „Lade Daten“ drücken, um die jährliche Globalstrahlung zu laden.'**
  String get irradianceEmpty;

  /// No description provided for @irradianceErrorTitle.
  ///
  /// In de, this message translates to:
  /// **'PVGIS-Abfrage fehlgeschlagen'**
  String get irradianceErrorTitle;

  /// No description provided for @irradianceChartTitle.
  ///
  /// In de, this message translates to:
  /// **'Globalstrahlung [ kW/m² ]'**
  String get irradianceChartTitle;

  /// No description provided for @irradianceSeriesTotal.
  ///
  /// In de, this message translates to:
  /// **'Gesamte'**
  String get irradianceSeriesTotal;

  /// No description provided for @irradianceSeriesDiffuse.
  ///
  /// In de, this message translates to:
  /// **'Diffuse'**
  String get irradianceSeriesDiffuse;

  /// No description provided for @irradianceAnnualSum.
  ///
  /// In de, this message translates to:
  /// **'Abs {value} kWh/m²'**
  String irradianceAnnualSum(String value);

  /// No description provided for @irradianceAverage.
  ///
  /// In de, this message translates to:
  /// **'Ø {value} W/m²'**
  String irradianceAverage(String value);

  /// No description provided for @irradianceCacheHit.
  ///
  /// In de, this message translates to:
  /// **'aus Cache geladen'**
  String get irradianceCacheHit;

  /// No description provided for @irradianceCacheMiss.
  ///
  /// In de, this message translates to:
  /// **'frisch von PVGIS'**
  String get irradianceCacheMiss;

  /// No description provided for @azimuthCompassTitle.
  ///
  /// In de, this message translates to:
  /// **'Azimut auswählen'**
  String get azimuthCompassTitle;

  /// No description provided for @azimuthCompassHint.
  ///
  /// In de, this message translates to:
  /// **'Tippen, um den Azimut für das ausgewählte PV-Array zu setzen.'**
  String get azimuthCompassHint;

  /// No description provided for @azimuthApply.
  ///
  /// In de, this message translates to:
  /// **'Übernehmen'**
  String get azimuthApply;

  /// No description provided for @azimuthCancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get azimuthCancel;

  /// No description provided for @resultsRun.
  ///
  /// In de, this message translates to:
  /// **'Simulation starten'**
  String get resultsRun;

  /// No description provided for @resultsRunMissingData.
  ///
  /// In de, this message translates to:
  /// **'Bitte zuerst Strahlungsdaten und mindestens ein PV-Array eintragen.'**
  String get resultsRunMissingData;

  /// No description provided for @resultsErrorTitle.
  ///
  /// In de, this message translates to:
  /// **'Simulation fehlgeschlagen'**
  String get resultsErrorTitle;

  /// No description provided for @resultsRunStarting.
  ///
  /// In de, this message translates to:
  /// **'Wird gestartet…'**
  String get resultsRunStarting;

  /// No description provided for @resultsRunPhasePreRun.
  ///
  /// In de, this message translates to:
  /// **'Speicher-SOC einlaufen (Vorlauf)'**
  String get resultsRunPhasePreRun;

  /// No description provided for @resultsRunPhaseReporting.
  ///
  /// In de, this message translates to:
  /// **'Berichtsjahr wird simuliert'**
  String get resultsRunPhaseReporting;

  /// No description provided for @resultsRunPhaseConvergence.
  ///
  /// In de, this message translates to:
  /// **'Zyklische Konvergenz Iteration {iteration}'**
  String resultsRunPhaseConvergence(int iteration);

  /// No description provided for @resultsRunPhaseYear.
  ///
  /// In de, this message translates to:
  /// **'Jahr {year} von {totalYears} wird simuliert'**
  String resultsRunPhaseYear(int year, int totalYears);

  /// No description provided for @arraysTabHint.
  ///
  /// In de, this message translates to:
  /// **'Kein PVGIS-Aufruf pro Array — alle Module beziehen ihre POA-Werte aus den im Tab „Einstrahlung“ geladenen Standortdaten.'**
  String get arraysTabHint;

  /// No description provided for @arraysSelectForCompass.
  ///
  /// In de, this message translates to:
  /// **'Für Kompass-Auswahl markiert'**
  String get arraysSelectForCompass;

  /// No description provided for @dispatchPolicyTitle.
  ///
  /// In de, this message translates to:
  /// **'Dispatch-Strategie'**
  String get dispatchPolicyTitle;

  /// No description provided for @dispatchPolicyKindLabel.
  ///
  /// In de, this message translates to:
  /// **'Strategie'**
  String get dispatchPolicyKindLabel;

  /// No description provided for @dispatchPolicySelfConsumption.
  ///
  /// In de, this message translates to:
  /// **'Eigenverbrauch zuerst'**
  String get dispatchPolicySelfConsumption;

  /// No description provided for @dispatchPolicySelfConsumptionDesc.
  ///
  /// In de, this message translates to:
  /// **'PV deckt zuerst die Last, Überschuss lädt die Speicher, danach Einspeisung. Standardverhalten und identisch zur alten Engine.'**
  String get dispatchPolicySelfConsumptionDesc;

  /// No description provided for @dispatchPolicyReserve.
  ///
  /// In de, this message translates to:
  /// **'Speicherreserve'**
  String get dispatchPolicyReserve;

  /// No description provided for @dispatchPolicyReserveDesc.
  ///
  /// In de, this message translates to:
  /// **'Wie Eigenverbrauch, aber die Speicher werden nur bis zum Reserveziel geladen. PV-Überschuss wird früher eingespeist statt vollständig zwischengespeichert.'**
  String get dispatchPolicyReserveDesc;

  /// No description provided for @dispatchPolicyReserveSoc.
  ///
  /// In de, this message translates to:
  /// **'Reserveziel'**
  String get dispatchPolicyReserveSoc;

  /// No description provided for @dispatchPolicyReserveSocHelp.
  ///
  /// In de, this message translates to:
  /// **'Bruchteil der Speicherkapazität (0..1), bis zu dem PV-Überschuss geladen wird. 0,5 = nur bis zur Hälfte laden.'**
  String get dispatchPolicyReserveSocHelp;

  /// No description provided for @dispatchPolicyConstantFeed.
  ///
  /// In de, this message translates to:
  /// **'24h-Konstanteinspeisung'**
  String get dispatchPolicyConstantFeed;

  /// No description provided for @dispatchPolicyConstantFeedDesc.
  ///
  /// In de, this message translates to:
  /// **'Micro-Inverter-Bänke speisen rund um die Uhr mit ihrer Sollleistung, solange der Speicher über dem Abschalt-SOC liegt.'**
  String get dispatchPolicyConstantFeedDesc;

  /// No description provided for @dispatchPolicyTimeWindow.
  ///
  /// In de, this message translates to:
  /// **'Zeitfenster-Einspeisung'**
  String get dispatchPolicyTimeWindow;

  /// No description provided for @dispatchPolicyTimeWindowDesc.
  ///
  /// In de, this message translates to:
  /// **'Micro-Inverter-Bänke speisen nur innerhalb der in jedem Bank konfigurierten Zeitfenster.'**
  String get dispatchPolicyTimeWindowDesc;

  /// No description provided for @dispatchPolicyGridAssist.
  ///
  /// In de, this message translates to:
  /// **'Netz-Assist'**
  String get dispatchPolicyGridAssist;

  /// No description provided for @dispatchPolicyGridAssistDesc.
  ///
  /// In de, this message translates to:
  /// **'Wie Eigenverbrauch, aber Netzimport kann blockiert werden — nicht gedeckte Last erscheint als „unversorgte Last“.'**
  String get dispatchPolicyGridAssistDesc;

  /// No description provided for @dispatchPolicyGridImportLabel.
  ///
  /// In de, this message translates to:
  /// **'Netzimport zulassen'**
  String get dispatchPolicyGridImportLabel;

  /// No description provided for @dispatchPolicyGridImportHelp.
  ///
  /// In de, this message translates to:
  /// **'Aus = Inselbetrieb. Nicht gedeckte Last wird als „unversorgte Last“ statt als Netzimport bilanziert.'**
  String get dispatchPolicyGridImportHelp;

  /// No description provided for @dispatchPolicyBankHint.
  ///
  /// In de, this message translates to:
  /// **'Tipp: Diese Strategie ist nur sinnvoll mit mindestens einem Micro-Inverter-Bank.'**
  String get dispatchPolicyBankHint;

  /// No description provided for @microInverterBanksTitle.
  ///
  /// In de, this message translates to:
  /// **'Micro-Inverter-Bänke (Batterieausgang)'**
  String get microInverterBanksTitle;

  /// No description provided for @microInverterBanksCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Bänke konfiguriert} =1{1 Bank} other{{count} Bänke}}'**
  String microInverterBanksCount(int count);

  /// No description provided for @microInverterBanksEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine Bänke konfiguriert. Über „Hinzufügen“ einen batteriegekoppelten AC-Ausgang anlegen.'**
  String get microInverterBanksEmpty;

  /// No description provided for @microInverterBanksHeading.
  ///
  /// In de, this message translates to:
  /// **'Bank {n}'**
  String microInverterBanksHeading(int n);

  /// No description provided for @microInverterBanksDefaultLabel.
  ///
  /// In de, this message translates to:
  /// **'Bank {n}'**
  String microInverterBanksDefaultLabel(int n);

  /// No description provided for @microInverterBanksWarnPvDevice.
  ///
  /// In de, this message translates to:
  /// **'Hinweis: Reguläre PV-Micro-Inverter erwarten Modulkennlinien; ein Batterieausgang braucht ein vom Hersteller dafür freigegebenes Gerät. Die Simulation ersetzt keine Elektrofachplanung.'**
  String get microInverterBanksWarnPvDevice;

  /// No description provided for @microInverterBankBattery.
  ///
  /// In de, this message translates to:
  /// **'Quell-Speicher'**
  String get microInverterBankBattery;

  /// No description provided for @microInverterBankCount.
  ///
  /// In de, this message translates to:
  /// **'Anzahl'**
  String get microInverterBankCount;

  /// No description provided for @microInverterBankUnitW.
  ///
  /// In de, this message translates to:
  /// **'Leistung je Einheit'**
  String get microInverterBankUnitW;

  /// No description provided for @microInverterBankShutdown.
  ///
  /// In de, this message translates to:
  /// **'Abschalt-SOC'**
  String get microInverterBankShutdown;

  /// No description provided for @microInverterBankShutdownHelp.
  ///
  /// In de, this message translates to:
  /// **'Bruchteil der Speicherkapazität (0..1), unter dem die Bank nicht mehr einspeist. 0 = nie abschalten.'**
  String get microInverterBankShutdownHelp;

  /// No description provided for @microInverterBankEfficiency.
  ///
  /// In de, this message translates to:
  /// **'Wirkungsgrad'**
  String get microInverterBankEfficiency;

  /// No description provided for @microInverterBankSchedule.
  ///
  /// In de, this message translates to:
  /// **'Zeitplan'**
  String get microInverterBankSchedule;

  /// No description provided for @microInverterBankScheduleKind.
  ///
  /// In de, this message translates to:
  /// **'Zeitplan-Typ'**
  String get microInverterBankScheduleKind;

  /// No description provided for @microInverterBankScheduleAlwaysOn.
  ///
  /// In de, this message translates to:
  /// **'Dauerbetrieb'**
  String get microInverterBankScheduleAlwaysOn;

  /// No description provided for @microInverterBankScheduleTimeWindows.
  ///
  /// In de, this message translates to:
  /// **'Zeitfenster'**
  String get microInverterBankScheduleTimeWindows;

  /// No description provided for @microInverterBankScheduleHourly.
  ///
  /// In de, this message translates to:
  /// **'Stündlich (24 Werte)'**
  String get microInverterBankScheduleHourly;

  /// No description provided for @microInverterBankAddWindow.
  ///
  /// In de, this message translates to:
  /// **'Zeitfenster'**
  String get microInverterBankAddWindow;

  /// No description provided for @microInverterBankAlwaysOn.
  ///
  /// In de, this message translates to:
  /// **'Dauerbetrieb: rund um die Uhr aktiv (gemäß Dispatch-Strategie).'**
  String get microInverterBankAlwaysOn;

  /// No description provided for @microInverterBankWindowStart.
  ///
  /// In de, this message translates to:
  /// **'Start (h)'**
  String get microInverterBankWindowStart;

  /// No description provided for @microInverterBankWindowEnd.
  ///
  /// In de, this message translates to:
  /// **'Ende (h)'**
  String get microInverterBankWindowEnd;

  /// No description provided for @microInverterBankWindowFactor.
  ///
  /// In de, this message translates to:
  /// **'Faktor'**
  String get microInverterBankWindowFactor;

  /// No description provided for @microInverterBankHourlyHour.
  ///
  /// In de, this message translates to:
  /// **'{hour}:00'**
  String microInverterBankHourlyHour(int hour);

  /// No description provided for @microInverterBankHourlyHelp.
  ///
  /// In de, this message translates to:
  /// **'Faktor je Stunde (0..1). 1.0 = volle Sollleistung, 0.0 = aus. Wirkt auf die Bank-Sollleistung, nicht direkt auf SOC.'**
  String get microInverterBankHourlyHelp;

  /// No description provided for @microInverterBankHourlyReset.
  ///
  /// In de, this message translates to:
  /// **'Alles auf 1.0'**
  String get microInverterBankHourlyReset;

  /// No description provided for @resultsKpiMicroDelivered.
  ///
  /// In de, this message translates to:
  /// **'Micro-Inverter geliefert'**
  String get resultsKpiMicroDelivered;

  /// No description provided for @resultsKpiMicroShortfall.
  ///
  /// In de, this message translates to:
  /// **'Micro-Inverter Fehlbetrag'**
  String get resultsKpiMicroShortfall;

  /// No description provided for @resultsKpiUnservedLoad.
  ///
  /// In de, this message translates to:
  /// **'Unversorgte Last'**
  String get resultsKpiUnservedLoad;

  /// No description provided for @microInverterBanksWarnSharedPvInverter.
  ///
  /// In de, this message translates to:
  /// **'Achtung: Wechselrichter „{inverterId}“ ist als „800-W-Micro-Inverter“ mit angeschlossenen PV-Modulen konfiguriert. Reguläre PV-Micro-Inverter dürfen nicht aus einem Speicher gespeist werden — der Batterieausgang braucht ein eigenes, vom Hersteller dafür freigegebenes Gerät.'**
  String microInverterBanksWarnSharedPvInverter(String inverterId);

  /// No description provided for @bankRuntimeSectionTitle.
  ///
  /// In de, this message translates to:
  /// **'24h-Ausgang — Laufzeit pro Tag'**
  String get bankRuntimeSectionTitle;

  /// No description provided for @bankRuntimeLegendFull.
  ///
  /// In de, this message translates to:
  /// **'Voll gedeckt (Soll erreicht)'**
  String get bankRuntimeLegendFull;

  /// No description provided for @bankRuntimeLegendPartial.
  ///
  /// In de, this message translates to:
  /// **'Teilweise (Soll unterschritten)'**
  String get bankRuntimeLegendPartial;

  /// No description provided for @bankRuntimeLegendShortfall.
  ///
  /// In de, this message translates to:
  /// **'Fehlbetrag (geplante Stunden ohne Lieferung)'**
  String get bankRuntimeLegendShortfall;

  /// No description provided for @bankRuntimeStatCoverage.
  ///
  /// In de, this message translates to:
  /// **'Abdeckung: {pct} %'**
  String bankRuntimeStatCoverage(String pct);

  /// No description provided for @bankRuntimeStatAvgHours.
  ///
  /// In de, this message translates to:
  /// **'Ø {hours} h/Tag aktiv'**
  String bankRuntimeStatAvgHours(String hours);

  /// No description provided for @bankRuntimeStatDelivered.
  ///
  /// In de, this message translates to:
  /// **'Geliefert: {kwh} kWh'**
  String bankRuntimeStatDelivered(String kwh);

  /// No description provided for @bankRuntimeStatShortfall.
  ///
  /// In de, this message translates to:
  /// **'Fehlbetrag: {kwh} kWh'**
  String bankRuntimeStatShortfall(String kwh);

  /// No description provided for @topologyTitle.
  ///
  /// In de, this message translates to:
  /// **'Topologie'**
  String get topologyTitle;

  /// No description provided for @topologyEnable.
  ///
  /// In de, this message translates to:
  /// **'Explizite Topologie verwenden'**
  String get topologyEnable;

  /// No description provided for @topologyAutoGeneratedInfo.
  ///
  /// In de, this message translates to:
  /// **'Aus: Engine baut die Standardtopologie aus Arrays, Wechselrichtern und Batterien automatisch.'**
  String get topologyAutoGeneratedInfo;

  /// No description provided for @topologyDcBusesTitle.
  ///
  /// In de, this message translates to:
  /// **'DC-Busse'**
  String get topologyDcBusesTitle;

  /// No description provided for @topologyAcBusesTitle.
  ///
  /// In de, this message translates to:
  /// **'AC-Busse'**
  String get topologyAcBusesTitle;

  /// No description provided for @topologyMpptTitle.
  ///
  /// In de, this message translates to:
  /// **'MPPT-Knoten'**
  String get topologyMpptTitle;

  /// No description provided for @topologyMpptEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine MPPTs konfiguriert. Über „Aus aktueller Konfiguration übernehmen“ aus den Wechselrichtern ableiten.'**
  String get topologyMpptEmpty;

  /// No description provided for @topologyEdgesTitle.
  ///
  /// In de, this message translates to:
  /// **'Kanten'**
  String get topologyEdgesTitle;

  /// No description provided for @topologyCouplingsTitle.
  ///
  /// In de, this message translates to:
  /// **'Batterie-Kopplungen'**
  String get topologyCouplingsTitle;

  /// No description provided for @topologyCouplingsEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine Batterien konfiguriert.'**
  String get topologyCouplingsEmpty;

  /// No description provided for @topologyAddDcBus.
  ///
  /// In de, this message translates to:
  /// **'DC-Bus'**
  String get topologyAddDcBus;

  /// No description provided for @topologyAddAcBus.
  ///
  /// In de, this message translates to:
  /// **'AC-Bus'**
  String get topologyAddAcBus;

  /// No description provided for @topologyAddEdge.
  ///
  /// In de, this message translates to:
  /// **'Kante'**
  String get topologyAddEdge;

  /// No description provided for @topologyEdgeFrom.
  ///
  /// In de, this message translates to:
  /// **'Von'**
  String get topologyEdgeFrom;

  /// No description provided for @topologyEdgeTo.
  ///
  /// In de, this message translates to:
  /// **'Nach'**
  String get topologyEdgeTo;

  /// No description provided for @topologyEdgeEfficiency.
  ///
  /// In de, this message translates to:
  /// **'Wirkungsgrad'**
  String get topologyEdgeEfficiency;

  /// No description provided for @topologyEdgeMaxPowerKw.
  ///
  /// In de, this message translates to:
  /// **'Max. Leistung'**
  String get topologyEdgeMaxPowerKw;

  /// No description provided for @topologyEdgeStandbyW.
  ///
  /// In de, this message translates to:
  /// **'Standby'**
  String get topologyEdgeStandbyW;

  /// No description provided for @topologyCouplingAc.
  ///
  /// In de, this message translates to:
  /// **'AC'**
  String get topologyCouplingAc;

  /// No description provided for @topologyCouplingDc.
  ///
  /// In de, this message translates to:
  /// **'DC'**
  String get topologyCouplingDc;

  /// No description provided for @topologyCouplingDcBus.
  ///
  /// In de, this message translates to:
  /// **'DC-Bus'**
  String get topologyCouplingDcBus;

  /// No description provided for @topologyCouplingInverter.
  ///
  /// In de, this message translates to:
  /// **'Batterie-Wechselrichter'**
  String get topologyCouplingInverter;

  /// No description provided for @topologyCouplingInverterNone.
  ///
  /// In de, this message translates to:
  /// **'— keiner —'**
  String get topologyCouplingInverterNone;

  /// No description provided for @topologyCouplingInverterHelp.
  ///
  /// In de, this message translates to:
  /// **'Optional: Wechselrichter, der die AC-Ausgangsleistung der Batterie begrenzt (Architektur §5.3). Leer = `BatteryConfig.maxDischargeKw` ist die AC-Grenze.'**
  String get topologyCouplingInverterHelp;

  /// No description provided for @topologySeedFromLegacy.
  ///
  /// In de, this message translates to:
  /// **'Aus aktueller Konfiguration übernehmen'**
  String get topologySeedFromLegacy;

  /// No description provided for @projectsTabCompareButton.
  ///
  /// In de, this message translates to:
  /// **'Vergleichen ({count})'**
  String projectsTabCompareButton(int count);

  /// No description provided for @projectsTabScenarioCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Szenarien} =1{1 Szenario} other{{count} Szenarien}}'**
  String projectsTabScenarioCount(int count);

  /// No description provided for @projectsTabEmptyScenarios.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Szenario in diesem Projekt.'**
  String get projectsTabEmptyScenarios;

  /// No description provided for @projectsTabPopupNewScenario.
  ///
  /// In de, this message translates to:
  /// **'Neues Szenario'**
  String get projectsTabPopupNewScenario;

  /// No description provided for @projectsTabPopupRename.
  ///
  /// In de, this message translates to:
  /// **'Umbenennen'**
  String get projectsTabPopupRename;

  /// No description provided for @projectsTabPopupDeleteProject.
  ///
  /// In de, this message translates to:
  /// **'Projekt löschen'**
  String get projectsTabPopupDeleteProject;

  /// No description provided for @projectsTabDuplicateTooltip.
  ///
  /// In de, this message translates to:
  /// **'Duplizieren'**
  String get projectsTabDuplicateTooltip;

  /// No description provided for @projectsTabRenameTooltip.
  ///
  /// In de, this message translates to:
  /// **'Umbenennen'**
  String get projectsTabRenameTooltip;

  /// No description provided for @projectsTabExportTooltip.
  ///
  /// In de, this message translates to:
  /// **'Exportieren'**
  String get projectsTabExportTooltip;

  /// No description provided for @projectsTabDeleteTooltip.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get projectsTabDeleteTooltip;

  /// No description provided for @projectsTabRenameProjectTitle.
  ///
  /// In de, this message translates to:
  /// **'Projekt umbenennen'**
  String get projectsTabRenameProjectTitle;

  /// No description provided for @projectsTabRenameScenarioTitle.
  ///
  /// In de, this message translates to:
  /// **'Szenario umbenennen'**
  String get projectsTabRenameScenarioTitle;

  /// No description provided for @projectsTabNewScenarioTitle.
  ///
  /// In de, this message translates to:
  /// **'Neues Szenario'**
  String get projectsTabNewScenarioTitle;

  /// No description provided for @projectsTabDeleteScenarioTitle.
  ///
  /// In de, this message translates to:
  /// **'Szenario löschen?'**
  String get projectsTabDeleteScenarioTitle;

  /// No description provided for @projectsTabDeleteScenarioBody.
  ///
  /// In de, this message translates to:
  /// **'Wirklich \"{name}\" löschen?'**
  String projectsTabDeleteScenarioBody(String name);

  /// No description provided for @projectsTabDialogSave.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get projectsTabDialogSave;

  /// No description provided for @projectsTabDialogCreate.
  ///
  /// In de, this message translates to:
  /// **'Anlegen'**
  String get projectsTabDialogCreate;

  /// No description provided for @projectsTabSuggestedScenarioName.
  ///
  /// In de, this message translates to:
  /// **'Szenario'**
  String get projectsTabSuggestedScenarioName;

  /// No description provided for @compareTitle.
  ///
  /// In de, this message translates to:
  /// **'Szenariovergleich'**
  String get compareTitle;

  /// No description provided for @comparePreparing.
  ///
  /// In de, this message translates to:
  /// **'Wird vorbereitet…'**
  String get comparePreparing;

  /// No description provided for @compareEmptyHint.
  ///
  /// In de, this message translates to:
  /// **'Wähle mindestens zwei Szenarien aus dem Projekte-Tab.'**
  String get compareEmptyHint;

  /// No description provided for @compareKpisCard.
  ///
  /// In de, this message translates to:
  /// **'KPIs'**
  String get compareKpisCard;

  /// No description provided for @compareChartCard.
  ///
  /// In de, this message translates to:
  /// **'Energiebilanz im Vergleich'**
  String get compareChartCard;

  /// No description provided for @compareTableScenario.
  ///
  /// In de, this message translates to:
  /// **'Szenario'**
  String get compareTableScenario;

  /// No description provided for @compareTablePvAcKwh.
  ///
  /// In de, this message translates to:
  /// **'PV AC (kWh)'**
  String get compareTablePvAcKwh;

  /// No description provided for @compareTableSelfConsumption.
  ///
  /// In de, this message translates to:
  /// **'Eigenverbrauch %'**
  String get compareTableSelfConsumption;

  /// No description provided for @compareTableAutarky.
  ///
  /// In de, this message translates to:
  /// **'Autarkie %'**
  String get compareTableAutarky;

  /// No description provided for @compareTableGridImport.
  ///
  /// In de, this message translates to:
  /// **'Netzbezug (kWh)'**
  String get compareTableGridImport;

  /// No description provided for @compareTableGridExport.
  ///
  /// In de, this message translates to:
  /// **'Einspeisung (kWh)'**
  String get compareTableGridExport;

  /// No description provided for @compareTableMicroInverter.
  ///
  /// In de, this message translates to:
  /// **'Mikro-WR (kWh)'**
  String get compareTableMicroInverter;

  /// No description provided for @compareTableCurtailedAc.
  ///
  /// In de, this message translates to:
  /// **'Abregelung AC (kWh)'**
  String get compareTableCurtailedAc;

  /// No description provided for @compareTableSource.
  ///
  /// In de, this message translates to:
  /// **'Quelle'**
  String get compareTableSource;

  /// No description provided for @compareTableSourceCache.
  ///
  /// In de, this message translates to:
  /// **'Cache'**
  String get compareTableSourceCache;

  /// No description provided for @compareTableSourceFresh.
  ///
  /// In de, this message translates to:
  /// **'Neu'**
  String get compareTableSourceFresh;

  /// No description provided for @compareChartPvAc.
  ///
  /// In de, this message translates to:
  /// **'PV AC'**
  String get compareChartPvAc;

  /// No description provided for @compareChartSelfConsumption.
  ///
  /// In de, this message translates to:
  /// **'Eigenverbr.'**
  String get compareChartSelfConsumption;

  /// No description provided for @compareChartGridImport.
  ///
  /// In de, this message translates to:
  /// **'Netzbezug'**
  String get compareChartGridImport;

  /// No description provided for @compareChartGridExport.
  ///
  /// In de, this message translates to:
  /// **'Einspeisung'**
  String get compareChartGridExport;

  /// No description provided for @resultsEnableExpertHint.
  ///
  /// In de, this message translates to:
  /// **'Erweiterte Einstellungen aktivieren'**
  String get resultsEnableExpertHint;

  /// No description provided for @resultsEnableExpertHintDesc.
  ///
  /// In de, this message translates to:
  /// **'Topologie, Mikro-Wechselrichter-Bänke und Dispatch-Strategien sind im Expertenmodus verfügbar.'**
  String get resultsEnableExpertHintDesc;

  /// No description provided for @resultsAdvancedScenarioBanner.
  ///
  /// In de, this message translates to:
  /// **'Dieses Szenario nutzt erweiterte Funktionen (Topologie, Mikro-Wechselrichter-Bänke oder ein abweichendes Dispatch). Aktiviere den Expertenmodus, um sie zu sehen und zu bearbeiten.'**
  String get resultsAdvancedScenarioBanner;

  /// No description provided for @wizardTitle.
  ///
  /// In de, this message translates to:
  /// **'Neues Projekt anlegen'**
  String get wizardTitle;

  /// No description provided for @wizardStepSite.
  ///
  /// In de, this message translates to:
  /// **'Standort'**
  String get wizardStepSite;

  /// No description provided for @wizardStepArray.
  ///
  /// In de, this message translates to:
  /// **'PV-Modulfeld'**
  String get wizardStepArray;

  /// No description provided for @wizardStepBattery.
  ///
  /// In de, this message translates to:
  /// **'Speicher'**
  String get wizardStepBattery;

  /// No description provided for @wizardStepLoad.
  ///
  /// In de, this message translates to:
  /// **'Lastprofil'**
  String get wizardStepLoad;

  /// No description provided for @wizardStepSummary.
  ///
  /// In de, this message translates to:
  /// **'Zusammenfassung'**
  String get wizardStepSummary;

  /// No description provided for @wizardProjectName.
  ///
  /// In de, this message translates to:
  /// **'Projektname'**
  String get wizardProjectName;

  /// No description provided for @wizardLatitude.
  ///
  /// In de, this message translates to:
  /// **'Breitengrad'**
  String get wizardLatitude;

  /// No description provided for @wizardLongitude.
  ///
  /// In de, this message translates to:
  /// **'Längengrad'**
  String get wizardLongitude;

  /// No description provided for @wizardArrayPeak.
  ///
  /// In de, this message translates to:
  /// **'Spitzenleistung'**
  String get wizardArrayPeak;

  /// No description provided for @wizardArrayAzimuth.
  ///
  /// In de, this message translates to:
  /// **'Azimut (0 = Nord, 180 = Süd)'**
  String get wizardArrayAzimuth;

  /// No description provided for @wizardArrayTilt.
  ///
  /// In de, this message translates to:
  /// **'Neigung'**
  String get wizardArrayTilt;

  /// No description provided for @wizardAddBattery.
  ///
  /// In de, this message translates to:
  /// **'Speicher hinzufügen'**
  String get wizardAddBattery;

  /// No description provided for @wizardBatteryCapacity.
  ///
  /// In de, this message translates to:
  /// **'Kapazität'**
  String get wizardBatteryCapacity;

  /// No description provided for @wizardBatteryChargeRate.
  ///
  /// In de, this message translates to:
  /// **'Max. Ladeleistung'**
  String get wizardBatteryChargeRate;

  /// No description provided for @wizardBatteryDischargeRate.
  ///
  /// In de, this message translates to:
  /// **'Max. Entladeleistung'**
  String get wizardBatteryDischargeRate;

  /// No description provided for @wizardLoadDaily.
  ///
  /// In de, this message translates to:
  /// **'Tagesverbrauch'**
  String get wizardLoadDaily;

  /// No description provided for @wizardSummaryIntro.
  ///
  /// In de, this message translates to:
  /// **'Diese Werte werden für das neue Projekt übernommen. Du kannst sie später jederzeit im Editor anpassen und Einstrahlungsdaten laden.'**
  String get wizardSummaryIntro;

  /// No description provided for @wizardSummaryName.
  ///
  /// In de, this message translates to:
  /// **'Projekt'**
  String get wizardSummaryName;

  /// No description provided for @wizardSummarySite.
  ///
  /// In de, this message translates to:
  /// **'Standort'**
  String get wizardSummarySite;

  /// No description provided for @wizardSummaryArray.
  ///
  /// In de, this message translates to:
  /// **'PV: {peak} kWp, {azimuth}°/{tilt}°'**
  String wizardSummaryArray(String peak, String azimuth, String tilt);

  /// No description provided for @wizardSummaryBatteryNone.
  ///
  /// In de, this message translates to:
  /// **'Kein Speicher'**
  String get wizardSummaryBatteryNone;

  /// No description provided for @wizardSummaryBattery.
  ///
  /// In de, this message translates to:
  /// **'Speicher: {capacity} kWh ({charge}/{discharge} kW)'**
  String wizardSummaryBattery(String capacity, String charge, String discharge);

  /// No description provided for @wizardSummaryLoad.
  ///
  /// In de, this message translates to:
  /// **'Last: {kwh} kWh/Tag'**
  String wizardSummaryLoad(String kwh);

  /// No description provided for @wizardCancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get wizardCancel;

  /// No description provided for @wizardBack.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get wizardBack;

  /// No description provided for @wizardContinue.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get wizardContinue;

  /// No description provided for @wizardFinish.
  ///
  /// In de, this message translates to:
  /// **'Projekt anlegen'**
  String get wizardFinish;

  /// No description provided for @warningsSectionTitle.
  ///
  /// In de, this message translates to:
  /// **'Hinweise zur Konfiguration'**
  String get warningsSectionTitle;

  /// No description provided for @warningInverterOversized.
  ///
  /// In de, this message translates to:
  /// **'Wechselrichter „{inverter}\" ist mit DC/AC-Verhältnis {ratio} überdimensioniert — chronische Abregelung am Tag wahrscheinlich.'**
  String warningInverterOversized(String inverter, String ratio);

  /// No description provided for @warningBankExceedsDischarge.
  ///
  /// In de, this message translates to:
  /// **'Bank „{bank}\" zieht {bankKw} kW, der Speicher kann aber nur {dischargeKw} kW liefern — dauerhafter Shortfall.'**
  String warningBankExceedsDischarge(
    String bank,
    String bankKw,
    String dischargeKw,
  );

  /// No description provided for @warningBatteryMinSocHigh.
  ///
  /// In de, this message translates to:
  /// **'Speicher „{battery}\" reserviert {pct}% der Kapazität als minSOC — nutzbare Energie stark reduziert.'**
  String warningBatteryMinSocHigh(String battery, String pct);

  /// No description provided for @hintIrradianceMissing.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Einstrahlungsdaten geladen. Die Simulation läuft mit dem synthetischen Demo-Modell — Lade Daten über den Einstrahlung-Tab für reale Werte.'**
  String get hintIrradianceMissing;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
