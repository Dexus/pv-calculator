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
      'Les jours d\'amorçage stabilisent l\'état de charge initial de la batterie avant la simulation proprement dite. Les pas d\'amorçage n\'apparaissent pas dans les résultats.';

  @override
  String get projectExportLimit => 'Limite d\'injection';

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
  String get resultsMonthly => 'Bilan mensuel';

  @override
  String get resultsCsvSteps => 'Export CSV pas';

  @override
  String get resultsCsvMonthly => 'Export CSV mensuel';

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
  String get microInverterBankAddWindow => 'Fenêtre';

  @override
  String get microInverterBankAlwaysOn =>
      'Sans fenêtres : actif 24 h/24 (selon la stratégie de dispatch).';

  @override
  String get microInverterBankWindowStart => 'Début (h)';

  @override
  String get microInverterBankWindowEnd => 'Fin (h)';

  @override
  String get microInverterBankWindowFactor => 'Facteur';

  @override
  String get resultsKpiMicroDelivered => 'Micro-onduleur livré';

  @override
  String get resultsKpiMicroShortfall => 'Micro-onduleur déficit';

  @override
  String get resultsKpiUnservedLoad => 'Charge non servie';
}
