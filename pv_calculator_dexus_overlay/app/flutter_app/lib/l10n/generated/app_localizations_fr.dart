// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get commonAdd => 'Ajouter';

  @override
  String get commonRemove => 'Supprimer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get validationRequired => 'Champ requis';

  @override
  String get validationMustBeNumber => 'Veuillez entrer un nombre';

  @override
  String validationAtLeast(String value) {
    return 'Au moins $value';
  }

  @override
  String validationAtMost(String value) {
    return 'Au plus $value';
  }

  @override
  String get drawerSubtitle => 'Démo · modèle synthétique';

  @override
  String get drawerProjects => 'Projets';

  @override
  String get drawerSettings => 'Paramètres';

  @override
  String get drawerAbout => 'À propos';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsThemeSystem => 'Suivre le système';

  @override
  String get settingsThemeSystemDesc =>
      'Change avec le réglage de l\'appareil.';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSystem => 'Utiliser la langue du système';

  @override
  String get settingsLanguageSystemDesc => 'Suit la langue de l\'appareil.';

  @override
  String get settingsAboutApp => 'À propos de l\'application';

  @override
  String get settingsAboutBody =>
      'Application de démonstration pour le dimensionnement PV avec stockage par batterie et micro-onduleur 800 W. Le modèle de rayonnement actuel est synthétique et ne constitue pas une prévision de rendement validée.';

  @override
  String get settingsAdvanced => 'Avancé';

  @override
  String get settingsExpertMode => 'Mode expert';

  @override
  String get settingsExpertModeDesc =>
      'Affiche l\'éditeur de topologie, les bancs de micro-onduleurs et les stratégies de dispatch alternatives dans l\'onglet Résultats.';

  @override
  String get projectListTitle => 'PV Calculator — Projets';

  @override
  String get projectListEmpty => 'Aucun projet enregistré.';

  @override
  String get projectListEmptyHint =>
      'Créez un nouveau projet ou importez un JSON enregistré.';

  @override
  String get projectListCreateButton => 'Créer un projet';

  @override
  String get projectListImportTooltip => 'Importer';

  @override
  String get projectListNewTooltip => 'Nouveau projet';

  @override
  String get projectListExportTooltip => 'Exporter';

  @override
  String get projectListDeleteTooltip => 'Supprimer';

  @override
  String get projectListNewDefaultName => 'Nouveau projet';

  @override
  String projectListLoadFailed(String name) {
    return 'Impossible de charger le projet « $name ».';
  }

  @override
  String projectListImported(String name) {
    return 'Importé : $name';
  }

  @override
  String projectListImportFailed(String error) {
    return 'Échec de l\'import : $error';
  }

  @override
  String projectListDownloaded(String filename) {
    return 'Téléchargé : $filename';
  }

  @override
  String projectListExported(String filename) {
    return 'Exporté : $filename';
  }

  @override
  String projectListShared(String filename) {
    return 'Partagé : $filename';
  }

  @override
  String get projectListExportCancelled => 'Export annulé';

  @override
  String projectListExportFailed(String error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String get projectListConflictTitle => 'Le projet existe déjà';

  @override
  String projectListConflictBody(String name) {
    return '« $name » est déjà enregistré. L\'import doit-il écraser cette version, ou être enregistré sous un nouveau nom ?';
  }

  @override
  String get projectListConflictRename => 'Renommer';

  @override
  String get projectListConflictOverwrite => 'Écraser';

  @override
  String get projectListDeleteTitle => 'Supprimer le projet ?';

  @override
  String projectListDeleteBody(String name) {
    return '« $name » sera définitivement supprimé.';
  }

  @override
  String projectListSaveFailed(String error) {
    return 'Échec de l\'enregistrement : $error';
  }

  @override
  String get editorRun => 'Lancer la simulation';

  @override
  String get editorValidationTitle => 'Configuration incomplète';

  @override
  String get editorRunErrorTitle => 'Échec de la simulation';

  @override
  String get editorOrphanedTitle => 'Imports PVGIS sans champ correspondant';

  @override
  String get editorOrphanedBody =>
      'Les séries météo importées suivantes renvoient à des champs supprimés ou renommés et ne sont pas utilisées par la simulation. Utilisez « Oublier » pour les libérer.';

  @override
  String get editorOrphanedForget => 'Oublier';

  @override
  String get editorWeatherSynthetic =>
      'Remarque : cette simulation utilise un modèle de rayonnement démo synthétique et ne remplace pas une validation PVGIS. Vous pouvez importer un JSON horaire PVGIS par champ pour utiliser un rayonnement réel.';

  @override
  String get editorWeatherSession =>
      ' Les imports PVGIS ne valent que pour cette session ; ils doivent être ré-importés à la réouverture d\'un projet enregistré.';

  @override
  String editorWeatherAll(int total, String session) {
    return 'Source météo : données PVGIS importées pour les $total champs. Moyennes TMY sur les années contenues dans le fichier.$session';
  }

  @override
  String editorWeatherMixed(int withCount, int total, String session) {
    return 'Source météo mixte : $withCount champs sur $total utilisent des données PVGIS importées, les autres retombent sur le modèle démo synthétique.$session';
  }

  @override
  String get projectSectionTitle => 'Projet';

  @override
  String get projectName => 'Nom du projet';

  @override
  String get projectLatitude => 'Latitude';

  @override
  String get projectLongitude => 'Longitude';

  @override
  String get projectStartDay => 'Jour de l\'année (début)';

  @override
  String get projectSimulationDays => 'Jours de simulation';

  @override
  String get projectPreRunDays => 'Jours d\'amorçage';

  @override
  String get projectPreRunHelp =>
      'Nombre de jours d\'amorçage pour le mode \"Amorçage simple\". N\'est utilisé que dans ce mode ; les pas d\'amorçage n\'apparaissent pas dans les résultats.';

  @override
  String get projectPreRunMode => 'Préparation du SOC';

  @override
  String get projectPreRunModeManual => 'SOC initial manuel';

  @override
  String get projectPreRunModeSingle => 'Amorçage simple';

  @override
  String get projectPreRunModeCyclic => 'Convergence cyclique';

  @override
  String get projectPreRunModeCyclicPro => 'Convergence cyclique (Pro)';

  @override
  String get projectConvergenceTolerance => 'Tolérance de convergence';

  @override
  String get projectConvergenceToleranceHelp =>
      '|début − fin| SOC max après un cycle, en % de la capacité utile. PRD §6.2 suggère 0,5 %.';

  @override
  String get projectMaxConvergenceIterations => 'Itérations max';

  @override
  String get projectExportLimit => 'Limite d\'injection';

  @override
  String get projectSimulationYears => 'Années de simulation';

  @override
  String get projectSimulationYearsHelp =>
      'Nombre d\'années consécutives à simuler. Avec > 1, la puissance des modules est dégradée chaque année selon le facteur de dégradation ; le SOC est conservé entre les années.';

  @override
  String get pvArrayDegradation => 'Dégradation';

  @override
  String get pvArrayDegradationHelp =>
      'Perte de puissance annuelle en %/an. Typique 0,4–0,7 pour silicium cristallin. Seulement effectif avec années de simulation > 1.';

  @override
  String get tariffSectionTitle => 'Tarif électrique';

  @override
  String get tariffEnabled => 'Calculer la rentabilité';

  @override
  String get tariffEnabledHelp =>
      'Calcule le coût d\'importation et les revenus d\'exportation à partir des prix saisis.';

  @override
  String get tariffImportLabel => 'Prix d\'importation';

  @override
  String get tariffExportLabel => 'Tarif d\'injection';

  @override
  String get tariffTouTitle => 'Prix par tranche horaire';

  @override
  String get tariffTouHelp =>
      '24 créneaux horaires pour des prix variables d\'import/export. Fonction Pro.';

  @override
  String get tariffTouImportHeader => 'Prix d\'importation horaires (EUR/kWh)';

  @override
  String get tariffTouExportHeader => 'Tarif d\'injection horaire (EUR/kWh)';

  @override
  String get resultsKpiImportCost => 'Coût d\'importation';

  @override
  String get resultsKpiExportRevenue => 'Revenus d\'injection';

  @override
  String get resultsKpiNetCost => 'Coût net d\'électricité';

  @override
  String get resultsPdfReport => 'Exporter le rapport (PDF)';

  @override
  String get resultsPdfReportProTooltip =>
      'Les rapports PDF sont une fonction Pro.';

  @override
  String get pdfAppTitle => 'PV Calculator';

  @override
  String pdfGeneratedAt(String timestamp, String engineVersion) {
    return 'Généré $timestamp  -  moteur $engineVersion';
  }

  @override
  String get pdfSectionPerYear => 'Répartition annuelle';

  @override
  String get pdfSectionMonthly => 'Mensuel';

  @override
  String get pdfSectionMonthlyFinalYear =>
      'Mensuel (dernière année uniquement)';

  @override
  String get pdfSectionMonthlyCashflow => 'Flux mensuel';

  @override
  String get pdfSectionMonthlyCashflowFinalYear =>
      'Flux mensuel (dernière année uniquement)';

  @override
  String get pdfSectionArrays => 'Modules PV';

  @override
  String get pdfSectionBanks => 'Bancs de micro-onduleurs';

  @override
  String get pdfSectionWarnings => 'Avertissements';

  @override
  String get pdfColMetric => 'Indicateur';

  @override
  String get pdfColValue => 'Valeur';

  @override
  String get pdfColYear => 'Année';

  @override
  String get pdfColSelfShort => 'Autocons.';

  @override
  String get pdfColMonth => 'Mois';

  @override
  String get pdfColSelfTight => 'Auto.';

  @override
  String get pdfColCharge => 'Charge';

  @override
  String get pdfColDischarge => 'Décharge';

  @override
  String get pdfColImport => 'Import.';

  @override
  String get pdfColExport => 'Export.';

  @override
  String get pdfColId => 'ID';

  @override
  String get pdfColLabel => 'Libellé';

  @override
  String get pdfColPeakKw => 'Crête kW';

  @override
  String get pdfColAzimuth => 'Azim.';

  @override
  String get pdfColTilt => 'Incl.';

  @override
  String get pdfColInverter => 'Onduleur';

  @override
  String get pdfColDegradation => 'Dégr. %/a';

  @override
  String get pdfColTargetKwh => 'Cible kWh';

  @override
  String get pdfColDeliveredKwh => 'Livré kWh';

  @override
  String get pdfColShortfallKwh => 'Manque kWh';

  @override
  String get pdfColCoverage => 'Couverture %';

  @override
  String get pdfFooterSynthetic =>
      'Note: ce rapport a été généré avec le modèle d\'irradiance synthétique de démonstration. Les chiffres sont indicatifs et ne constituent pas une prévision de production validée.';

  @override
  String pdfFooterAgpl(String engineVersion) {
    return 'Généré par PV Calculator (AGPL-3.0)  -  moteur $engineVersion';
  }

  @override
  String get projectTimeStep => 'Pas de temps';

  @override
  String get projectTimeStepHourly => 'Horaire';

  @override
  String get projectTimeStepQuarter => 'Quart d\'heure';

  @override
  String get projectPvgisApiTitle => 'API PVGIS';

  @override
  String get projectPvgisApiHelp =>
      'Fenêtre temporelle et base de rayonnement pour « Charger depuis l\'API PVGIS ». PVGIS-SARAH3 couvre typiquement 2005–2023 ; plus la fenêtre est large, plus les moyennes TMY sont stables.';

  @override
  String get projectPvgisStartYear => 'Année de début PVGIS';

  @override
  String get projectPvgisEndYear => 'Année de fin PVGIS';

  @override
  String get projectRadDatabase => 'Base de rayonnement';

  @override
  String get projectRadDatabaseAuto => 'PVGIS auto';

  @override
  String get projectAddressSearch => 'Rechercher une adresse (OpenStreetMap)';

  @override
  String get projectAddressHint => 'ex. Marktplatz 1, Frankfurt';

  @override
  String get projectAddressNoResults => 'Aucun résultat.';

  @override
  String get fieldId => 'ID';

  @override
  String get fieldLabel => 'Libellé';

  @override
  String get arraysTitle => 'Champs PV';

  @override
  String get arraysEmpty => 'Au moins un champ est requis.';

  @override
  String arraysDefaultLabel(int n) {
    return 'Champ $n';
  }

  @override
  String arraysHeading(int n) {
    return 'Champ $n';
  }

  @override
  String get arraysFieldPeak => 'Puissance crête';

  @override
  String get arraysFieldAzimuth => 'Azimut';

  @override
  String get arraysFieldTilt => 'Inclinaison';

  @override
  String get arraysFieldLosses => 'Pertes';

  @override
  String get arraysFieldShading => 'Ombrage';

  @override
  String get arraysFieldTempCoef => 'Coeff. température';

  @override
  String get arraysFieldTempCoefHelp =>
      'Perte de puissance par °C au-dessus de 25 °C de température cellule. Silicium cristallin ≈ −0,4 %/°C ; 0 désactive le derating thermique.';

  @override
  String get arraysFieldNoct => 'NOCT';

  @override
  String get arraysFieldNoctHelp =>
      'Nominal Operating Cell Temperature : température cellule à 800 W/m², air à 20 °C, vent 1 m/s. Typiquement 45 °C.';

  @override
  String get arraysFieldInverter => 'Onduleur';

  @override
  String get arraysFieldInverterRequired => 'Sélectionner un onduleur';

  @override
  String get pvgisIdRequired => 'Veuillez d\'abord attribuer un ID au champ.';

  @override
  String pvgisImported(String id, int count) {
    return 'Données PVGIS importées pour « $id » ($count valeurs).';
  }

  @override
  String pvgisImportFailed(String error) {
    return 'Échec de l\'import PVGIS : $error';
  }

  @override
  String get pvgisArrayNotFound => 'Champ introuvable.';

  @override
  String pvgisInvalidRequest(String error) {
    return 'Requête PVGIS invalide : $error';
  }

  @override
  String pvgisApiLoaded(String id, int count) {
    return 'Données API PVGIS chargées pour « $id » ($count valeurs).';
  }

  @override
  String pvgisApiFailed(String error) {
    return 'Échec de la requête API PVGIS : $error';
  }

  @override
  String get pvgisStatusSynthetic => 'Source météo : modèle démo synthétique';

  @override
  String get pvgisStatusLoaded => 'Données PVGIS chargées';

  @override
  String pvgisMetadata(
    String source,
    int count,
    String years,
    String lat,
    String lon,
    String orientation,
  ) {
    return '$source · $count heures · Années $years · Position PVGIS $lat°/$lon°$orientation';
  }

  @override
  String get pvgisSessionNote =>
      'Remarque : les imports PVGIS ne valent que pour cette session — ils ne sont pas enregistrés dans le JSON du projet.';

  @override
  String pvgisOrientationWarning(String issues) {
    return 'L\'orientation PVGIS diffère ($issues). Les valeurs POA importées correspondent à l\'orientation PVGIS, pas à celle configurée ici.';
  }

  @override
  String pvgisOrientationTilt(String value) {
    return 'Inclinaison $value°';
  }

  @override
  String pvgisOrientationAzimuth(String value) {
    return 'Azimut $value°';
  }

  @override
  String pvgisTiltMismatch(String imported, String configured) {
    return 'Inclinaison $imported° vs $configured°';
  }

  @override
  String pvgisAzimuthMismatch(String imported, String configured) {
    return 'Azimut $imported° vs $configured°';
  }

  @override
  String get pvgisReloadApi => 'Recharger l\'API';

  @override
  String get pvgisLoadFromApi => 'Charger depuis l\'API PVGIS';

  @override
  String get pvgisImportJson => 'Importer JSON';

  @override
  String get invertersTitle => 'Onduleurs';

  @override
  String get invertersEmpty => 'Au moins un onduleur est requis.';

  @override
  String invertersDefaultLabel(int n) {
    return 'Onduleur $n';
  }

  @override
  String invertersHeading(int n) {
    return 'Onduleur $n';
  }

  @override
  String get invertersFieldMaxAc => 'Puissance AC max.';

  @override
  String get invertersFieldEfficiency => 'Rendement';

  @override
  String get invertersFieldMaxDc => 'Entrée DC max.';

  @override
  String get invertersFieldMaxDcHelp =>
      'Limite optionnelle d\'entrée DC (MPPT). La puissance DC au-dessus est écrêtée avant l\'onduleur et comptée comme écrêtage. Laisser vide si l\'onduleur n\'est pas surdimensionné.';

  @override
  String get invertersFieldRole => 'Rôle';

  @override
  String get invertersRoleGrid => 'Réseau';

  @override
  String get invertersRoleMicro => 'Micro 800 W';

  @override
  String get invertersRoleBattery => 'Couplé batterie';

  @override
  String get invertersRoleMicroHelp =>
      'Solaire 800 W prise : la sortie AC est écrêtée à 0,8 kW, quel que soit le réglage de puissance AC max.';

  @override
  String get invertersRoleBatteryHelp =>
      'Onduleur couplé en DC à une batterie ; mesuré comme un onduleur réseau mais marqué sémantiquement.';

  @override
  String get invertersRoleGridHelp =>
      'Onduleur réseau standard sans plafond AC strict.';

  @override
  String get chargeControllersTitle => 'Régulateurs de charge (MPPT)';

  @override
  String get chargeControllersEmpty =>
      'Aucun régulateur de charge configuré pour le moment.';

  @override
  String chargeControllersDefaultLabel(int n) {
    return 'Régulateur de charge $n';
  }

  @override
  String chargeControllersHeading(int n) {
    return 'Régulateur de charge $n';
  }

  @override
  String get chargeControllersFieldDcBusId => 'Bus CC';

  @override
  String get chargeControllersFieldDcBusIdHelp =>
      'ID du bus CC alimenté par ce régulateur. En mode hérité (sans éditeur de topologie), les bus sont nommés automatiquement d\'après l\'onduleur, p. ex. `dc-main`.';

  @override
  String get chargeControllersFieldEfficiency => 'Rendement';

  @override
  String get chargeControllersFieldMaxInputKw => 'Entrée PV max.';

  @override
  String get chargeControllersFieldMaxInputKwHelp =>
      'Plafond optionnel sur la puissance d\'entrée côté PV. L\'excédent est écrêté avant d\'atteindre le bus CC et comptabilisé comme écrêtage côté CC.';

  @override
  String get dcBusModeLabel => 'Mode';

  @override
  String get dcBusModeHybrid => 'Hybride';

  @override
  String get dcBusModeBatteryFed => 'Batterie uniquement';

  @override
  String get dcBusModeHybridHelp =>
      'Quand la batterie est pleine, la PV peut transiter directement par le bus CC vers l\'onduleur (PV → bus CC → onduleur → AC).';

  @override
  String get dcBusModeBatteryFedHelp =>
      'La PV atteint le bus AC uniquement via la décharge de la batterie. L\'excédent PV avec la batterie pleine est écrêté.';

  @override
  String get batteriesTitle => 'Stockage batterie';

  @override
  String get batteriesEmpty => 'Aucun stockage configuré (optionnel).';

  @override
  String batteriesDefaultLabel(int n) {
    return 'Batterie $n';
  }

  @override
  String batteriesHeading(int n) {
    return 'Batterie $n';
  }

  @override
  String get batteriesFieldCapacity => 'Capacité';

  @override
  String get batteriesFieldChargePower => 'Puissance de charge max.';

  @override
  String get batteriesFieldDischargePower => 'Puissance de décharge max.';

  @override
  String get batteriesFieldRoundtrip => 'Rendement aller-retour';

  @override
  String get batteriesFieldRoundtripHelp =>
      'Rendement charge × décharge. Typiquement 0,9 pour le lithium, ≈ 0,75 pour le plomb.';

  @override
  String get batteriesFieldMinSoc => 'SOC min.';

  @override
  String get batteriesCustomInitial => 'Définir le SOC initial manuellement';

  @override
  String get batteriesFieldStartSoc => 'SOC initial';

  @override
  String get loadTitle => 'Profil de charge';

  @override
  String get loadFieldDaily => 'Consommation journalière';

  @override
  String get loadHourlyHint =>
      'Forme horaire : profil standard de ménage allemand (24 valeurs). L\'édition manuelle de la forme horaire est prévue pour une version ultérieure.';

  @override
  String get loadCsvImportButton => 'Importer le CSV';

  @override
  String loadCsvImportSuccess(String dailyKwh) {
    return 'Profil de charge importé depuis CSV ($dailyKwh kWh/jour).';
  }

  @override
  String loadCsvImportError(String error) {
    return 'Échec de l\'importation : $error';
  }

  @override
  String loadHourlySummary(int peakHour, String peakKwh) {
    return 'Profil horaire issu de l\'import (pic $peakHour:00 — $peakKwh kWh).';
  }

  @override
  String resultsTitle(String name) {
    return 'Résultat — $name';
  }

  @override
  String get resultsEmpty => 'Aucune simulation lancée.';

  @override
  String get resultsBack => 'Retour à la configuration';

  @override
  String get resultsAnnualKpis => 'Indicateurs annuels';

  @override
  String get resultsKpiPvAc => 'PV AC';

  @override
  String get resultsKpiLoad => 'Charge';

  @override
  String get resultsKpiSelfConsumption => 'Autoconsommation';

  @override
  String get resultsKpiGridImport => 'Import réseau';

  @override
  String get resultsKpiGridExport => 'Injection réseau';

  @override
  String get resultsKpiCurtailDc => 'Écrêtage DC (MPPT)';

  @override
  String get resultsKpiCurtailAc => 'Écrêtage AC (limite onduleur)';

  @override
  String get resultsKpiCurtailExport => 'Écrêtage injection';

  @override
  String get resultsKpiBatteryCharge => 'Charge batterie';

  @override
  String get resultsKpiBatteryDischarge => 'Décharge batterie';

  @override
  String get resultsKpiAutarky => 'Autonomie';

  @override
  String get resultsKpiSelfConsumptionRate => 'Taux d\'autoconsommation';

  @override
  String get resultsBatterySection => 'Batteries (SOC final)';

  @override
  String resultsBatteryLabel(int n) {
    return 'Batterie $n';
  }

  @override
  String get resultsPreRunSection => 'Préparation du SOC';

  @override
  String get resultsPreRunMode => 'Mode';

  @override
  String get resultsPreRunIterations => 'Itérations';

  @override
  String get resultsPreRunConverged => 'Convergé';

  @override
  String get resultsPreRunConvergedYes => 'Oui';

  @override
  String get resultsPreRunConvergedNo => 'Non';

  @override
  String resultsPreRunStartSoc(int n) {
    return 'SOC initial batterie $n';
  }

  @override
  String get resultsMonthly => 'Bilan mensuel';

  @override
  String get resultsCsvSteps => 'Export CSV pas';

  @override
  String get resultsCsvMonthly => 'Export CSV mensuel';

  @override
  String get resultsCsvPerYearMonthly => 'Export CSV mensuel par année';

  @override
  String get perYearMonthlyTitle => 'Détail mensuel par année';

  @override
  String get perYearMonthlyYearPickerLabel => 'Choisir l\'année';

  @override
  String perYearMonthlyYearLabel(int n) {
    return 'Année $n';
  }

  @override
  String resultsCsvPending(int size) {
    return 'CSV prêt ($size caractères). L\'export viendra dans la couche de persistance.';
  }

  @override
  String resultsExported(String filename) {
    return 'Exporté : $filename';
  }

  @override
  String resultsExportFailed(String error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String get resultsSyntheticNote =>
      'Remarque : modèle de rayonnement démo synthétique — pas une prévision de rendement validée.';

  @override
  String get monthlyColMonth => 'Mois';

  @override
  String get monthlyColPvAc => 'PV AC (kWh)';

  @override
  String get monthlyColLoad => 'Charge (kWh)';

  @override
  String get monthlyColSelfConsumption => 'AC (kWh)';

  @override
  String get monthlyColBatteryCharge => 'Bat-ch. (kWh)';

  @override
  String get monthlyColBatteryDischarge => 'Bat-déch. (kWh)';

  @override
  String get monthlyColImport => 'Import (kWh)';

  @override
  String get monthlyColExport => 'Export (kWh)';

  @override
  String get monthlyColImportCost => 'Coût import (€)';

  @override
  String get monthlyColExportRevenue => 'Revenu export (€)';

  @override
  String get monthlyColNetCost => 'Net (€)';

  @override
  String get catalogPickButton => 'Choisir dans la bibliothèque';

  @override
  String get catalogPickerTitle => 'Choisir un composant';

  @override
  String get catalogSearchHint => 'Rechercher';

  @override
  String get catalogEmptyState => 'Aucun résultat';

  @override
  String get catalogModuleCountPrompt => 'Nombre de modules';

  @override
  String get catalogRoleGrid => 'réseau';

  @override
  String get catalogRoleBattery => 'batterie';

  @override
  String get catalogRoleMicro => 'micro 800 W';

  @override
  String get catalogLoadError => 'Impossible de charger la bibliothèque :';

  @override
  String get drawerCatalog => 'Bibliothèque de composants';

  @override
  String get catalogManagerTitle => 'Gérer la bibliothèque de composants';

  @override
  String get catalogManagerTabModules => 'Modules';

  @override
  String get catalogManagerTabInverters => 'Onduleurs';

  @override
  String get catalogManagerTabBatteries => 'Batteries';

  @override
  String get catalogManagerUserSection => 'Vos entrées';

  @override
  String get catalogManagerSeedSection => 'Catalogue fourni (lecture seule)';

  @override
  String get catalogManagerEmptyUser => 'Aucune entrée personnelle.';

  @override
  String get catalogManagerImportTooltip => 'Importer';

  @override
  String get catalogManagerExportTooltip => 'Exporter';

  @override
  String get catalogManagerExportEmpty =>
      'Aucune entrée personnelle à exporter.';

  @override
  String get catalogManagerEditTooltip => 'Modifier';

  @override
  String get catalogManagerDeleteTooltip => 'Supprimer';

  @override
  String get catalogManagerDuplicateTooltip =>
      'Copier comme entrée personnelle';

  @override
  String get catalogManagerDuplicatePrefix => 'Copie de — ';

  @override
  String get catalogManagerAddModuleFab => 'Ajouter un module';

  @override
  String get catalogManagerAddInverterFab => 'Ajouter un onduleur';

  @override
  String get catalogManagerAddBatteryFab => 'Ajouter une batterie';

  @override
  String get catalogManagerDeleteConfirmTitle => 'Supprimer l\'entrée ?';

  @override
  String catalogManagerDeleteConfirmBody(String name) {
    return '« $name » sera retirée de votre bibliothèque.';
  }

  @override
  String get catalogManagerImportConfirmTitle => 'Confirmer l\'import';

  @override
  String catalogManagerImportConfirmBody(int newCount, int overwriteCount) {
    return '$newCount nouvelles, $overwriteCount entrées existantes seront écrasées.';
  }

  @override
  String get catalogManagerImportConfirmAccept => 'Appliquer';

  @override
  String catalogManagerImportSuccess(int added, int updated) {
    return 'Importées : $added nouvelles, $updated mises à jour.';
  }

  @override
  String catalogManagerImportFailed(String error) {
    return 'Échec de l\'import : $error';
  }

  @override
  String catalogManagerExportSuccess(String filename) {
    return 'Exporté : $filename';
  }

  @override
  String catalogManagerExportShared(String filename) {
    return 'Partagé : $filename';
  }

  @override
  String get catalogManagerExportCancelled => 'Export annulé';

  @override
  String catalogManagerExportFailed(String error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String get catalogEditorTitleNewModule => 'Nouveau module';

  @override
  String get catalogEditorTitleNewInverter => 'Nouvel onduleur';

  @override
  String get catalogEditorTitleNewBattery => 'Nouvelle batterie';

  @override
  String catalogEditorTitleEdit(String name) {
    return 'Modifier : $name';
  }

  @override
  String get catalogEditorSave => 'Enregistrer';

  @override
  String get catalogEditorFieldId => 'ID';

  @override
  String get catalogEditorFieldIdHelp =>
      'Identifiant unique. Verrouillé en édition — supprimer et recréer pour renommer.';

  @override
  String get catalogEditorFieldManufacturer => 'Fabricant';

  @override
  String get catalogEditorFieldModel => 'Modèle';

  @override
  String get catalogEditorFieldSourceUrl => 'Source/URL';

  @override
  String get catalogEditorFieldNotes => 'Notes';

  @override
  String get catalogEditorFieldPeakKwPerModule =>
      'Puissance crête par module (kWp)';

  @override
  String get catalogEditorFieldCellTech => 'Technologie cellule';

  @override
  String get catalogEditorFieldTempCoef => 'Coeff. température (%/°C)';

  @override
  String get catalogEditorFieldNoct => 'NOCT (°C)';

  @override
  String get catalogEditorFieldDegradation => 'Dégradation (%/an)';

  @override
  String get catalogEditorFieldMaxAcKw => 'Puissance AC max (kW)';

  @override
  String get catalogEditorFieldMaxDcKw => 'Entrée DC max (kW)';

  @override
  String get catalogEditorFieldEfficiency => 'Rendement';

  @override
  String get catalogEditorFieldRole => 'Rôle';

  @override
  String get catalogEditorFieldCapacityKwh => 'Capacité (kWh)';

  @override
  String get catalogEditorFieldChargeKw => 'Puissance de charge max (kW)';

  @override
  String get catalogEditorFieldDischargeKw => 'Puissance de décharge max (kW)';

  @override
  String get catalogEditorFieldChemistry => 'Chimie';

  @override
  String get catalogEditorFieldRoundtrip => 'Rendement aller-retour';

  @override
  String get catalogEditorFieldMinSoc => 'SOC min. (kWh)';

  @override
  String catalogEditorValidationFailed(String error) {
    return 'Validation échouée : $error';
  }

  @override
  String get catalogEditorIdConflictTitle => 'L\'ID existe déjà';

  @override
  String catalogEditorIdConflictBody(String id) {
    return 'Une entrée avec l\'ID « $id » existe déjà. Écraser ?';
  }

  @override
  String get catalogEditorIdConflictOverwrite => 'Écraser';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Fév';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Avr';

  @override
  String get monthMay => 'Mai';

  @override
  String get monthJun => 'Juin';

  @override
  String get monthJul => 'Juil';

  @override
  String get monthAug => 'Aoû';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Déc';

  @override
  String get geocodingTimeout =>
      'Délai dépassé lors de la recherche d\'adresse.';

  @override
  String geocodingNetworkError(String error) {
    return 'Erreur réseau : $error';
  }

  @override
  String get geocodingRateLimit =>
      'Nominatim a atteint la limite (429). Veuillez patienter un instant.';

  @override
  String geocodingBadStatus(int code) {
    return 'Nominatim a répondu avec le statut $code.';
  }

  @override
  String get geocodingInvalidJson =>
      'La réponse de Nominatim n\'est pas un JSON valide.';

  @override
  String get geocodingInvalidFormat =>
      'Format de réponse inattendu de Nominatim.';

  @override
  String pvgisApiInvalidRequest(String error) {
    return 'Requête PVGIS invalide : $error';
  }

  @override
  String get pvgisApiTimeout => 'Délai dépassé pour la requête PVGIS.';

  @override
  String pvgisApiNetworkError(String error) {
    return 'Erreur réseau sur la requête PVGIS : $error';
  }

  @override
  String pvgisApiBadStatus(int code, String message) {
    return 'PVGIS a répondu avec le statut $code. $message';
  }

  @override
  String pvgisApiParseFailed(String error) {
    return 'Impossible de lire la réponse PVGIS : $error';
  }

  @override
  String get demoArrayLabel => 'Toit sud';

  @override
  String get demoInverterLabel => 'Onduleur principal';

  @override
  String get demoBatteryLabel => 'Batterie principale';

  @override
  String get tabProjects => 'Projets';

  @override
  String get tabIrradiance => 'Irradiance';

  @override
  String get tabArrays => 'Champs PV';

  @override
  String get tabResults => 'Résultats';

  @override
  String get irradianceTitle => 'Site & irradiance';

  @override
  String get irradianceMapHint =>
      'Déplacez la carte pour définir le site. L’épingle marque les coordonnées actuelles du projet.';

  @override
  String get irradianceYearLabel => 'Période';

  @override
  String get irradianceLoadButton => 'Charger les données';

  @override
  String get irradianceLoadingHint => 'Chargement de l’irradiance PVGIS …';

  @override
  String get irradianceEmpty =>
      'Choisissez un emplacement puis appuyez sur « Charger les données » pour récupérer l’irradiance annuelle.';

  @override
  String get irradianceErrorTitle => 'Requête PVGIS échouée';

  @override
  String get irradianceChartTitle => 'Irradiance globale horizontale [ kW/m² ]';

  @override
  String get irradianceSeriesTotal => 'Total';

  @override
  String get irradianceSeriesDiffuse => 'Diffuse';

  @override
  String irradianceAnnualSum(String value) {
    return 'Somme $value kWh/m²';
  }

  @override
  String irradianceAverage(String value) {
    return 'Moy. $value W/m²';
  }

  @override
  String get irradianceCacheHit => 'depuis le cache';

  @override
  String get irradianceCacheMiss => 'frais depuis PVGIS';

  @override
  String get azimuthCompassTitle => 'Choisir l’azimut';

  @override
  String get azimuthCompassHint =>
      'Touchez pour définir l’azimut du champ PV sélectionné.';

  @override
  String get azimuthApply => 'Appliquer';

  @override
  String get azimuthCancel => 'Annuler';

  @override
  String get resultsRun => 'Lancer la simulation';

  @override
  String get resultsRunMissingData =>
      'Chargez d’abord les données d’irradiance et ajoutez au moins un champ PV.';

  @override
  String get resultsErrorTitle => 'Simulation échouée';

  @override
  String get resultsRunStarting => 'Démarrage…';

  @override
  String get resultsRunPhasePreRun =>
      'Stabilisation du SOC de la batterie (pré-exécution)';

  @override
  String get resultsRunPhaseReporting => 'Simulation de l’année de référence';

  @override
  String resultsRunPhaseConvergence(int iteration) {
    return 'Convergence cyclique, itération $iteration';
  }

  @override
  String resultsRunPhaseYear(int year, int totalYears) {
    return 'Simulation année $year sur $totalYears';
  }

  @override
  String get arraysTabHint =>
      'Aucun appel PVGIS par champ — tous les modules dérivent leur POA des données horizontales du site, chargées dans l’onglet « Irradiance ».';

  @override
  String get arraysSelectForCompass => 'Sélectionné pour la boussole';

  @override
  String get dispatchPolicyTitle => 'Stratégie de dispatch';

  @override
  String get dispatchPolicyKindLabel => 'Stratégie';

  @override
  String get dispatchPolicySelfConsumption => 'Autoconsommation d’abord';

  @override
  String get dispatchPolicySelfConsumptionDesc =>
      'Le PV couvre d’abord la charge, le surplus charge les batteries, puis exporte. Comportement par défaut, identique au moteur d’avant la phase 4.';

  @override
  String get dispatchPolicyReserve => 'Réserve batterie';

  @override
  String get dispatchPolicyReserveDesc =>
      'Comme l’autoconsommation, mais les batteries ne se chargent que jusqu’à un plafond de réserve. Le surplus PV est exporté plus tôt.';

  @override
  String get dispatchPolicyReserveSoc => 'Plafond de réserve';

  @override
  String get dispatchPolicyReserveSocHelp =>
      'Fraction de la capacité (0..1) jusqu’à laquelle le surplus PV charge la batterie. 0,5 = charger seulement jusqu’à la moitié.';

  @override
  String get dispatchPolicyConstantFeed => 'Injection continue 24 h';

  @override
  String get dispatchPolicyConstantFeedDesc =>
      'Les bancs de micro-onduleurs injectent en continu à leur puissance cible tant que le SOC dépasse le seuil d’arrêt.';

  @override
  String get dispatchPolicyTimeWindow => 'Injection par fenêtres';

  @override
  String get dispatchPolicyTimeWindowDesc =>
      'Les bancs n’injectent qu’à l’intérieur des fenêtres horaires configurées sur chaque banc.';

  @override
  String get dispatchPolicyGridAssist => 'Assistance réseau';

  @override
  String get dispatchPolicyGridAssistDesc =>
      'Comme l’autoconsommation, mais l’import réseau peut être désactivé — la charge non couverte est comptée comme « charge non servie ».';

  @override
  String get dispatchPolicyGridImportLabel => 'Autoriser l’import réseau';

  @override
  String get dispatchPolicyGridImportHelp =>
      'Désactivé = mode îloté. La charge non couverte est reportée comme « charge non servie » au lieu d’import réseau.';

  @override
  String get dispatchPolicyBankHint =>
      'Astuce : cette stratégie n’a de sens qu’avec au moins un banc de micro-onduleurs.';

  @override
  String get microInverterBanksTitle =>
      'Bancs de micro-onduleurs (sortie batterie)';

  @override
  String microInverterBanksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bancs',
      one: '1 banc',
      zero: 'Aucun banc configuré',
    );
    return '$_temp0';
  }

  @override
  String get microInverterBanksEmpty =>
      'Aucun banc configuré. Utilisez « Ajouter » pour créer une sortie AC couplée batterie.';

  @override
  String microInverterBanksHeading(int n) {
    return 'Banc $n';
  }

  @override
  String microInverterBanksDefaultLabel(int n) {
    return 'Banc $n';
  }

  @override
  String get microInverterBanksWarnPvDevice =>
      'Note : les micro-onduleurs PV standards attendent des courbes IV de modules ; une sortie alimentée par batterie exige un appareil certifié par le fabricant pour cet usage. La simulation ne remplace pas une étude électrique qualifiée.';

  @override
  String get microInverterBankBattery => 'Batterie source';

  @override
  String get microInverterBankCount => 'Nombre';

  @override
  String get microInverterBankUnitW => 'Puissance par unité';

  @override
  String get microInverterBankShutdown => 'SOC d’arrêt';

  @override
  String get microInverterBankShutdownHelp =>
      'Fraction de la capacité (0..1) en dessous de laquelle le banc cesse d’injecter. 0 = jamais d’arrêt.';

  @override
  String get microInverterBankEfficiency => 'Rendement';

  @override
  String get microInverterBankSchedule => 'Programmation';

  @override
  String get microInverterBankScheduleKind => 'Type de programmation';

  @override
  String get microInverterBankScheduleAlwaysOn => 'Toujours actif';

  @override
  String get microInverterBankScheduleTimeWindows => 'Fenêtres horaires';

  @override
  String get microInverterBankScheduleHourly => 'Horaire (24 facteurs)';

  @override
  String get microInverterBankAddWindow => 'Fenêtre';

  @override
  String get microInverterBankAlwaysOn =>
      'Toujours actif : 24 h/24 (selon la stratégie de dispatch).';

  @override
  String get microInverterBankWindowStart => 'Début (h)';

  @override
  String get microInverterBankWindowEnd => 'Fin (h)';

  @override
  String get microInverterBankWindowFactor => 'Facteur';

  @override
  String microInverterBankHourlyHour(int hour) {
    return '$hour:00';
  }

  @override
  String get microInverterBankHourlyHelp =>
      'Facteur par heure (0..1). 1,0 = puissance cible complète, 0,0 = arrêt. S\'applique à la cible du banc, pas directement au SOC.';

  @override
  String get microInverterBankHourlyReset => 'Tout remettre à 1,0';

  @override
  String get resultsKpiMicroDelivered => 'Micro-onduleur livré';

  @override
  String get resultsKpiMicroShortfall => 'Micro-onduleur déficit';

  @override
  String get resultsKpiUnservedLoad => 'Charge non servie';

  @override
  String microInverterBanksWarnSharedPvInverter(String inverterId) {
    return 'Attention : l\'onduleur « $inverterId » est configuré comme micro-onduleur PV 800 W avec des modules PV raccordés. Les micro-onduleurs PV classiques ne doivent pas être alimentés par une batterie — la sortie batterie nécessite un appareil distinct certifié par son fabricant pour cet usage.';
  }

  @override
  String get bankRuntimeSectionTitle => 'Sortie 24h — autonomie journalière';

  @override
  String get bankRuntimeLegendFull => 'Entièrement couvert (objectif atteint)';

  @override
  String get bankRuntimeLegendPartial => 'Partiel (en dessous de l\'objectif)';

  @override
  String get bankRuntimeLegendShortfall =>
      'Manque (heures programmées sans livraison)';

  @override
  String bankRuntimeStatCoverage(String pct) {
    return 'Couverture : $pct %';
  }

  @override
  String bankRuntimeStatAvgHours(String hours) {
    return 'Moy. $hours h/jour actif';
  }

  @override
  String bankRuntimeStatDelivered(String kwh) {
    return 'Livré : $kwh kWh';
  }

  @override
  String bankRuntimeStatShortfall(String kwh) {
    return 'Manque : $kwh kWh';
  }

  @override
  String get topologyTitle => 'Topologie';

  @override
  String get topologyEnable => 'Utiliser une topologie explicite';

  @override
  String get topologyAutoGeneratedInfo =>
      'Désactivé : le moteur déduit une topologie par défaut à partir des arrays, onduleurs et batteries.';

  @override
  String get topologyDcBusesTitle => 'Bus DC';

  @override
  String get topologyAcBusesTitle => 'Bus AC';

  @override
  String get topologyMpptTitle => 'Nœuds MPPT';

  @override
  String get topologyMpptEmpty =>
      'Aucun MPPT configuré. Utilisez « Initialiser depuis la configuration actuelle » pour les dériver des onduleurs.';

  @override
  String get topologyEdgesTitle => 'Arêtes';

  @override
  String get topologyCouplingsTitle => 'Couplages batterie';

  @override
  String get topologyCouplingsEmpty => 'Aucune batterie configurée.';

  @override
  String get topologyAddDcBus => 'Bus DC';

  @override
  String get topologyAddAcBus => 'Bus AC';

  @override
  String get topologyAddEdge => 'Arête';

  @override
  String get topologyEdgeFrom => 'De';

  @override
  String get topologyEdgeTo => 'Vers';

  @override
  String get topologyEdgeEfficiency => 'Rendement';

  @override
  String get topologyEdgeMaxPowerKw => 'Puissance max';

  @override
  String get topologyEdgeStandbyW => 'Veille';

  @override
  String get topologyCouplingAc => 'AC';

  @override
  String get topologyCouplingDc => 'DC';

  @override
  String get topologyCouplingDcBus => 'Bus DC';

  @override
  String get topologyCouplingInverter => 'Onduleur batterie';

  @override
  String get topologyCouplingInverterNone => '— aucun —';

  @override
  String get topologyCouplingInverterHelp =>
      'Optionnel : onduleur qui limite la puissance AC de la batterie (Architecture §5.3). Vide = `BatteryConfig.maxDischargeKw` est la limite AC.';

  @override
  String get topologySeedFromLegacy =>
      'Initialiser depuis la configuration actuelle';

  @override
  String projectsTabCompareButton(int count) {
    return 'Comparer ($count)';
  }

  @override
  String projectsTabScenarioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scénarios',
      one: '1 scénario',
      zero: 'Aucun scénario',
    );
    return '$_temp0';
  }

  @override
  String get projectsTabEmptyScenarios => 'Aucun scénario dans ce projet.';

  @override
  String get projectsTabPopupNewScenario => 'Nouveau scénario';

  @override
  String get projectsTabPopupRename => 'Renommer';

  @override
  String get projectsTabPopupDeleteProject => 'Supprimer le projet';

  @override
  String get projectsTabDuplicateTooltip => 'Dupliquer';

  @override
  String get projectsTabRenameTooltip => 'Renommer';

  @override
  String get projectsTabExportTooltip => 'Exporter';

  @override
  String get projectsTabDeleteTooltip => 'Supprimer';

  @override
  String get projectsTabRenameProjectTitle => 'Renommer le projet';

  @override
  String get projectsTabRenameScenarioTitle => 'Renommer le scénario';

  @override
  String get projectsTabNewScenarioTitle => 'Nouveau scénario';

  @override
  String get projectsTabDeleteScenarioTitle => 'Supprimer le scénario ?';

  @override
  String projectsTabDeleteScenarioBody(String name) {
    return 'Supprimer vraiment « $name » ?';
  }

  @override
  String get projectsTabDialogSave => 'Enregistrer';

  @override
  String get projectsTabDialogCreate => 'Créer';

  @override
  String get projectsTabSuggestedScenarioName => 'Scénario';

  @override
  String get compareTitle => 'Comparaison des scénarios';

  @override
  String get comparePreparing => 'Préparation…';

  @override
  String get compareEmptyHint =>
      'Sélectionnez au moins deux scénarios dans l\'onglet Projets.';

  @override
  String get compareKpisCard => 'KPIs';

  @override
  String get compareChartCard => 'Comparaison du bilan énergétique';

  @override
  String get compareTableScenario => 'Scénario';

  @override
  String get compareTablePvAcKwh => 'PV CA (kWh)';

  @override
  String get compareTableSelfConsumption => 'Autoconsommation %';

  @override
  String get compareTableAutarky => 'Autarcie %';

  @override
  String get compareTableGridImport => 'Soutirage réseau (kWh)';

  @override
  String get compareTableGridExport => 'Injection réseau (kWh)';

  @override
  String get compareTableMicroInverter => 'Micro-ond. (kWh)';

  @override
  String get compareTableCurtailedAc => 'Écrêtage CA (kWh)';

  @override
  String get compareTableSource => 'Source';

  @override
  String get compareTableSourceCache => 'Cache';

  @override
  String get compareTableSourceFresh => 'Récent';

  @override
  String get compareChartPvAc => 'PV CA';

  @override
  String get compareChartSelfConsumption => 'Autocons.';

  @override
  String get compareChartGridImport => 'Soutirage';

  @override
  String get compareChartGridExport => 'Injection';

  @override
  String get resultsEnableExpertHint => 'Activer les paramètres avancés';

  @override
  String get resultsEnableExpertHintDesc =>
      'La topologie, les bancs de micro-onduleurs et les stratégies de dispatch sont accessibles en mode expert.';

  @override
  String get resultsAdvancedScenarioBanner =>
      'Ce scénario utilise des fonctions avancées (topologie, bancs de micro-onduleurs ou dispatch personnalisé). Active le mode expert pour les afficher et les modifier.';

  @override
  String get wizardTitle => 'Créer un nouveau projet';

  @override
  String get wizardStepSite => 'Emplacement';

  @override
  String get wizardStepArray => 'Champ PV';

  @override
  String get wizardStepBattery => 'Batterie';

  @override
  String get wizardStepLoad => 'Profil de charge';

  @override
  String get wizardStepSummary => 'Récapitulatif';

  @override
  String get wizardProjectName => 'Nom du projet';

  @override
  String get wizardLatitude => 'Latitude';

  @override
  String get wizardLongitude => 'Longitude';

  @override
  String get wizardArrayPeak => 'Puissance crête';

  @override
  String get wizardArrayAzimuth => 'Azimut (0 = nord, 180 = sud)';

  @override
  String get wizardArrayTilt => 'Inclinaison';

  @override
  String get wizardAddBattery => 'Ajouter une batterie';

  @override
  String get wizardBatteryCapacity => 'Capacité';

  @override
  String get wizardBatteryChargeRate => 'Puissance de charge max.';

  @override
  String get wizardBatteryDischargeRate => 'Puissance de décharge max.';

  @override
  String get wizardLoadDaily => 'Consommation quotidienne';

  @override
  String get wizardSummaryIntro =>
      'Ces valeurs serviront de base au nouveau projet. Tu peux les ajuster ensuite dans l\'éditeur et charger les données d\'irradiation.';

  @override
  String get wizardSummaryName => 'Projet';

  @override
  String get wizardSummarySite => 'Emplacement';

  @override
  String wizardSummaryArray(String peak, String azimuth, String tilt) {
    return 'PV : $peak kWc, $azimuth°/$tilt°';
  }

  @override
  String get wizardSummaryBatteryNone => 'Pas de batterie';

  @override
  String wizardSummaryBattery(
    String capacity,
    String charge,
    String discharge,
  ) {
    return 'Batterie : $capacity kWh ($charge/$discharge kW)';
  }

  @override
  String wizardSummaryLoad(String kwh) {
    return 'Charge : $kwh kWh/jour';
  }

  @override
  String get wizardCancel => 'Annuler';

  @override
  String get wizardBack => 'Retour';

  @override
  String get wizardContinue => 'Continuer';

  @override
  String get wizardFinish => 'Créer le projet';

  @override
  String get warningsSectionTitle => 'Avis de configuration';

  @override
  String warningInverterOversized(String inverter, String ratio) {
    return 'L\'onduleur « $inverter » a un rapport DC/AC de $ratio — un écrêtage en journée est probable.';
  }

  @override
  String warningBankExceedsDischarge(
    String bank,
    String bankKw,
    String dischargeKw,
  ) {
    return 'Le banc « $bank » demande $bankKw kW mais la batterie ne peut fournir que $dischargeKw kW — pénurie continue.';
  }

  @override
  String warningBatteryMinSocHigh(String battery, String pct) {
    return 'La batterie « $battery » réserve $pct% de sa capacité en minSOC — l\'énergie utilisable est fortement réduite.';
  }

  @override
  String get hintIrradianceMissing =>
      'Aucune donnée d\'irradiation chargée. La simulation utilisera le modèle synthétique de démonstration — ouvre l\'onglet Irradiation pour charger des valeurs réelles.';

  @override
  String get optimizerEntryButton => 'Optimiser';

  @override
  String get optimizerEntryProTooltip =>
      'L\'optimiseur est une fonctionnalité Pro.';

  @override
  String get optimizerTitle => 'Optimiseur';

  @override
  String get optimizerIntro =>
      'Fait varier la taille de batterie, la puissance de l\'onduleur et l\'échelle PV ; classe selon l\'objectif choisi et respecte un budget.';

  @override
  String get optimizerSectionObjective => 'Objectif';

  @override
  String get optimizerObjectiveAutarky => 'Maximiser l\'autarcie';

  @override
  String get optimizerObjectiveNetCost => 'Minimiser le coût électrique';

  @override
  String get optimizerObjectiveNetCostHint =>
      'Nécessite un tarif actif dans la section Tarif.';

  @override
  String get optimizerSectionSweeps => 'Plages de balayage';

  @override
  String get optimizerSweepBattery => 'Batterie (kWh)';

  @override
  String get optimizerSweepInverter => 'Onduleur AC (kW)';

  @override
  String get optimizerSweepPvScale => 'Facteur PV';

  @override
  String get optimizerSweepMin => 'Min';

  @override
  String get optimizerSweepMax => 'Max';

  @override
  String get optimizerSweepSteps => 'Pas';

  @override
  String get optimizerSweepHint => 'Pas = 1 fixe la valeur Min.';

  @override
  String get optimizerSectionPrices => 'Prix';

  @override
  String get optimizerPricePv => '€/kWp PV';

  @override
  String get optimizerPriceInverter => '€/kW onduleur';

  @override
  String get optimizerPriceBattery => '€/kWh batterie';

  @override
  String get optimizerBudget => 'Budget (€, optionnel)';

  @override
  String get optimizerHorizon => 'Horizon (années)';

  @override
  String get optimizerDiscountRate => 'Taux d\'actualisation (%/an)';

  @override
  String get optimizerPriceEscalation =>
      'Escalade du prix de l\'électricité (%/an)';

  @override
  String get optimizerDiscountHint =>
      'Les deux à 0 % → coût de cycle de vie = investissement + horizon × net annuel (ancienne formule). Sinon, les années suivantes sont escaladées et actualisées à la valeur présente. Payback / TRI ne sont pas calculés.';

  @override
  String get optimizerSectionOptionalArrays => 'Arrays optionnels';

  @override
  String get optimizerOptionalArraysHint =>
      'Les arrays cochés sont testés avec et sans eux (max. 4).';

  @override
  String get optimizerRunButton => 'Lancer le balayage';

  @override
  String get optimizerRunning => 'Optimiseur en cours …';

  @override
  String optimizerProgress(int done, int total) {
    return '$done / $total candidats';
  }

  @override
  String get optimizerCancelButton => 'Annuler';

  @override
  String get optimizerCancelled => 'Optimisation annulée.';

  @override
  String get optimizerCancelUnavailable =>
      'L’annulation n’est pas disponible sur le web.';

  @override
  String optimizerCounters(int evaluated, int overBudget, int invalid) {
    return '$evaluated évalués · $overBudget hors budget · $invalid invalides';
  }

  @override
  String get optimizerNoCandidates =>
      'Aucun candidat. Élargis le budget ou les plages de balayage.';

  @override
  String optimizerErrorPrefix(String message) {
    return 'Erreur : $message';
  }

  @override
  String get optimizerColBattery => 'Batterie (kWh)';

  @override
  String get optimizerColInverter => 'Onduleur (kW)';

  @override
  String get optimizerColPvScale => 'Facteur PV';

  @override
  String get optimizerColDisabled => 'Désactivés';

  @override
  String get optimizerColInvestment => 'Investissement (€)';

  @override
  String get optimizerColAutarky => 'Autarcie';

  @override
  String get optimizerColLifetimeCost => 'Coût cycle de vie (€)';

  @override
  String get optimizerColPvAcKwh => 'PV AC (kWh/an)';

  @override
  String get optimizerColPareto => 'Pareto';

  @override
  String get optimizerColParetoTooltipOn =>
      'Pareto-optimal : aucune autre combinaison évaluée n\'est à la fois au plus aussi coûteuse et au moins aussi autoconsommatrice (strictement meilleure sur au moins un axe).';

  @override
  String get optimizerColParetoTooltipOff =>
      'Dominé : au moins une autre combinaison est au plus aussi coûteuse et au moins aussi autoconsommatrice (strictement meilleure sur au moins un axe).';

  @override
  String get optimizerParetoTitle =>
      'Frontière de Pareto (coût × autoconsommation)';

  @override
  String get optimizerParetoHint =>
      'Les points en évidence sont non dominés : aucune autre combinaison évaluée n\'est à la fois moins chère et plus autoconsommatrice. Nécessite un tarif actif pour que le coût sur la durée de vie soit défini.';

  @override
  String get optimizerParetoAxisCost => 'Coût net sur la durée de vie (€)';

  @override
  String get optimizerParetoAxisAutarky => 'Autoconsommation (%)';

  @override
  String get optimizerParetoLegendCloud => 'Tous les candidats';

  @override
  String get optimizerParetoLegendFrontier => 'Pareto-optimal';
}
