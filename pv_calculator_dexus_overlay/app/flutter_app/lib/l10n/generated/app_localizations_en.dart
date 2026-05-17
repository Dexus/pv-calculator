// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonAdd => 'Add';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSearch => 'Search';

  @override
  String get validationRequired => 'Required';

  @override
  String get validationMustBeNumber => 'Please enter a number';

  @override
  String validationAtLeast(String value) {
    return 'At least $value';
  }

  @override
  String validationAtMost(String value) {
    return 'At most $value';
  }

  @override
  String get drawerSubtitle => 'Demo · synthetic model';

  @override
  String get drawerProjects => 'Projects';

  @override
  String get drawerSettings => 'Settings';

  @override
  String get drawerAbout => 'About';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeSystem => 'Follow system setting';

  @override
  String get settingsThemeSystemDesc => 'Switches with the device setting.';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Use system language';

  @override
  String get settingsLanguageSystemDesc => 'Follows the device language.';

  @override
  String get settingsAboutApp => 'About this app';

  @override
  String get settingsAboutBody =>
      'Demo application for PV system design with battery storage and 800 W micro-inverter. The current radiation model is synthetic and is not a validated yield forecast.';

  @override
  String get projectListTitle => 'PV Calculator — Projects';

  @override
  String get projectListEmpty => 'No projects saved yet.';

  @override
  String get projectListEmptyHint =>
      'Create a new project or import a saved JSON.';

  @override
  String get projectListCreateButton => 'Create new project';

  @override
  String get projectListImportTooltip => 'Import';

  @override
  String get projectListNewTooltip => 'New project';

  @override
  String get projectListExportTooltip => 'Export';

  @override
  String get projectListDeleteTooltip => 'Delete';

  @override
  String get projectListNewDefaultName => 'New project';

  @override
  String projectListLoadFailed(String name) {
    return 'Project \"$name\" could not be loaded.';
  }

  @override
  String projectListImported(String name) {
    return 'Imported: $name';
  }

  @override
  String projectListImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String projectListDownloaded(String filename) {
    return 'Downloaded: $filename';
  }

  @override
  String projectListExported(String filename) {
    return 'Exported: $filename';
  }

  @override
  String get projectListExportCancelled => 'Export cancelled';

  @override
  String projectListExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get projectListConflictTitle => 'Project already exists';

  @override
  String projectListConflictBody(String name) {
    return '\"$name\" is already saved. Should the import overwrite this version, or be stored under a new name?';
  }

  @override
  String get projectListConflictRename => 'Rename';

  @override
  String get projectListConflictOverwrite => 'Overwrite';

  @override
  String get projectListDeleteTitle => 'Delete project?';

  @override
  String projectListDeleteBody(String name) {
    return '\"$name\" will be permanently deleted.';
  }

  @override
  String projectListSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get editorRun => 'Run simulation';

  @override
  String get editorValidationTitle => 'Configuration incomplete';

  @override
  String get editorRunErrorTitle => 'Simulation failed';

  @override
  String get editorOrphanedTitle => 'PVGIS imports without a matching array';

  @override
  String get editorOrphanedBody =>
      'The following imported weather series refer to deleted or renamed arrays and are not used by the simulation. Use \"Forget\" to release them.';

  @override
  String get editorOrphanedForget => 'Forget';

  @override
  String get editorWeatherSynthetic =>
      'Note: this simulation uses a synthetic demo radiation model and does not replace PVGIS validation. You can import a PVGIS hourly-data JSON per array to use real irradiance.';

  @override
  String get editorWeatherSession =>
      ' PVGIS imports apply only to this session; they must be re-imported when a saved project is reopened.';

  @override
  String editorWeatherAll(int total, String session) {
    return 'Weather source: PVGIS data imported for all $total arrays. TMY averages over the years contained in the file.$session';
  }

  @override
  String editorWeatherMixed(int withCount, int total, String session) {
    return 'Mixed weather source: $withCount of $total arrays use imported PVGIS data; the rest fall back to the synthetic demo model.$session';
  }

  @override
  String get projectSectionTitle => 'Project';

  @override
  String get projectName => 'Project name';

  @override
  String get projectLatitude => 'Latitude';

  @override
  String get projectLongitude => 'Longitude';

  @override
  String get projectStartDay => 'Start day of year';

  @override
  String get projectSimulationDays => 'Simulation days';

  @override
  String get projectPreRunDays => 'Pre-run days';

  @override
  String get projectPreRunHelp =>
      'Pre-run days stabilise the battery starting state of charge before the actual simulation. Pre-run steps do not appear in the results.';

  @override
  String get projectExportLimit => 'Export limit';

  @override
  String get projectTimeStep => 'Time step';

  @override
  String get projectTimeStepHourly => 'Hourly';

  @override
  String get projectTimeStepQuarter => 'Quarter-hourly';

  @override
  String get projectPvgisApiTitle => 'PVGIS API';

  @override
  String get projectPvgisApiHelp =>
      'Time window and radiation database for \"Load from PVGIS API\". PVGIS-SARAH3 typically covers 2005–2023; the wider the window, the more stable the TMY averages.';

  @override
  String get projectPvgisStartYear => 'PVGIS start year';

  @override
  String get projectPvgisEndYear => 'PVGIS end year';

  @override
  String get projectRadDatabase => 'Radiation database';

  @override
  String get projectRadDatabaseAuto => 'PVGIS auto';

  @override
  String get projectAddressSearch => 'Search address (OpenStreetMap)';

  @override
  String get projectAddressHint => 'e.g. Marktplatz 1, Frankfurt';

  @override
  String get projectAddressNoResults => 'No matches found.';

  @override
  String get fieldId => 'ID';

  @override
  String get fieldLabel => 'Label';

  @override
  String get arraysTitle => 'PV arrays';

  @override
  String get arraysEmpty => 'At least one array is required.';

  @override
  String arraysDefaultLabel(int n) {
    return 'Array $n';
  }

  @override
  String arraysHeading(int n) {
    return 'Array $n';
  }

  @override
  String get arraysFieldPeak => 'Peak power';

  @override
  String get arraysFieldAzimuth => 'Azimuth';

  @override
  String get arraysFieldTilt => 'Tilt';

  @override
  String get arraysFieldLosses => 'Losses';

  @override
  String get arraysFieldShading => 'Shading';

  @override
  String get arraysFieldTempCoef => 'Temp. coefficient';

  @override
  String get arraysFieldTempCoefHelp =>
      'Power loss per °C cell temperature above 25 °C. Crystalline silicon ≈ −0.4 %/°C; 0 disables temperature derating.';

  @override
  String get arraysFieldNoct => 'NOCT';

  @override
  String get arraysFieldNoctHelp =>
      'Nominal Operating Cell Temperature: cell temperature at 800 W/m², 20 °C air, 1 m/s wind. Typically 45 °C.';

  @override
  String get arraysFieldInverter => 'Inverter';

  @override
  String get arraysFieldInverterRequired => 'Select inverter';

  @override
  String get pvgisIdRequired => 'Please assign an array ID first.';

  @override
  String pvgisImported(String id, int count) {
    return 'PVGIS data for \"$id\" imported ($count values).';
  }

  @override
  String pvgisImportFailed(String error) {
    return 'PVGIS import failed: $error';
  }

  @override
  String get pvgisArrayNotFound => 'Array not found.';

  @override
  String pvgisInvalidRequest(String error) {
    return 'PVGIS request invalid: $error';
  }

  @override
  String pvgisApiLoaded(String id, int count) {
    return 'PVGIS API data for \"$id\" loaded ($count values).';
  }

  @override
  String pvgisApiFailed(String error) {
    return 'PVGIS API request failed: $error';
  }

  @override
  String get pvgisStatusSynthetic => 'Weather source: synthetic demo model';

  @override
  String get pvgisStatusLoaded => 'PVGIS data loaded';

  @override
  String pvgisMetadata(
    String source,
    int count,
    String years,
    String lat,
    String lon,
    String orientation,
  ) {
    return '$source · $count hours · Years $years · PVGIS location $lat°/$lon°$orientation';
  }

  @override
  String get pvgisSessionNote =>
      'Note: PVGIS imports apply only to this session — they are not stored in the project JSON.';

  @override
  String pvgisOrientationWarning(String issues) {
    return 'PVGIS orientation differs ($issues). The imported POA values apply to the PVGIS orientation, not the one configured here.';
  }

  @override
  String pvgisOrientationTilt(String value) {
    return 'Tilt $value°';
  }

  @override
  String pvgisOrientationAzimuth(String value) {
    return 'Azimuth $value°';
  }

  @override
  String pvgisTiltMismatch(String imported, String configured) {
    return 'Tilt $imported° vs $configured°';
  }

  @override
  String pvgisAzimuthMismatch(String imported, String configured) {
    return 'Azimuth $imported° vs $configured°';
  }

  @override
  String get pvgisReloadApi => 'Reload from API';

  @override
  String get pvgisLoadFromApi => 'Load from PVGIS API';

  @override
  String get pvgisImportJson => 'Import JSON';

  @override
  String get invertersTitle => 'Inverters';

  @override
  String get invertersEmpty => 'At least one inverter is required.';

  @override
  String invertersDefaultLabel(int n) {
    return 'Inverter $n';
  }

  @override
  String invertersHeading(int n) {
    return 'Inverter $n';
  }

  @override
  String get invertersFieldMaxAc => 'Max. AC power';

  @override
  String get invertersFieldEfficiency => 'Efficiency';

  @override
  String get invertersFieldMaxDc => 'Max. DC input';

  @override
  String get invertersFieldMaxDcHelp =>
      'Optional DC input limit (MPPT). DC power above this is clipped before the inverter and recorded as curtailment. Leave blank if the inverter is not oversized.';

  @override
  String get invertersFieldRole => 'Role';

  @override
  String get invertersRoleGrid => 'Grid';

  @override
  String get invertersRoleMicro => '800 W micro';

  @override
  String get invertersRoleBattery => 'Battery-coupled';

  @override
  String get invertersRoleMicroHelp =>
      '800 W plug-in solar: AC output is hard-capped at 0.8 kW regardless of the configured max. AC power.';

  @override
  String get invertersRoleBatteryHelp =>
      'Inverter is DC-coupled to a battery; metered like a grid inverter but semantically marked.';

  @override
  String get invertersRoleGridHelp =>
      'Standard grid inverter without a hard AC cap.';

  @override
  String get batteriesTitle => 'Battery storage';

  @override
  String get batteriesEmpty => 'No battery storage configured (optional).';

  @override
  String batteriesDefaultLabel(int n) {
    return 'Battery $n';
  }

  @override
  String batteriesHeading(int n) {
    return 'Battery $n';
  }

  @override
  String get batteriesFieldCapacity => 'Capacity';

  @override
  String get batteriesFieldChargePower => 'Max. charge power';

  @override
  String get batteriesFieldDischargePower => 'Max. discharge power';

  @override
  String get batteriesFieldRoundtrip => 'Round-trip efficiency';

  @override
  String get batteriesFieldRoundtripHelp =>
      'Charge × discharge efficiency. Typically 0.9 for lithium storage, ≈ 0.75 for lead-acid.';

  @override
  String get batteriesFieldMinSoc => 'Min. SOC';

  @override
  String get batteriesCustomInitial => 'Set start SOC manually';

  @override
  String get batteriesFieldStartSoc => 'Start SOC';

  @override
  String get loadTitle => 'Load profile';

  @override
  String get loadFieldDaily => 'Daily consumption';

  @override
  String get loadHourlyHint =>
      'Hourly shape: German household standard profile (24 values). Manual editing of the hourly shape is planned for a later release.';

  @override
  String resultsTitle(String name) {
    return 'Result — $name';
  }

  @override
  String get resultsEmpty => 'No simulation has been run.';

  @override
  String get resultsBack => 'Back to configuration';

  @override
  String get resultsAnnualKpis => 'Annual KPIs';

  @override
  String get resultsKpiPvAc => 'PV AC';

  @override
  String get resultsKpiLoad => 'Load';

  @override
  String get resultsKpiSelfConsumption => 'Self-consumption';

  @override
  String get resultsKpiGridImport => 'Grid import';

  @override
  String get resultsKpiGridExport => 'Grid export';

  @override
  String get resultsKpiCurtailDc => 'Curtailment DC (MPPT)';

  @override
  String get resultsKpiCurtailAc => 'Curtailment AC (inverter cap)';

  @override
  String get resultsKpiCurtailExport => 'Curtailment export';

  @override
  String get resultsKpiBatteryCharge => 'Battery charge';

  @override
  String get resultsKpiBatteryDischarge => 'Battery discharge';

  @override
  String get resultsKpiAutarky => 'Autonomy';

  @override
  String get resultsKpiSelfConsumptionRate => 'Self-consumption rate';

  @override
  String get resultsBatterySection => 'Batteries (final SOC)';

  @override
  String resultsBatteryLabel(int n) {
    return 'Battery $n';
  }

  @override
  String get resultsMonthly => 'Monthly balance';

  @override
  String get resultsCsvSteps => 'CSV export steps';

  @override
  String get resultsCsvMonthly => 'CSV export monthly';

  @override
  String resultsCsvPending(int size) {
    return 'CSV ready ($size characters). Export follows in the persistence layer.';
  }

  @override
  String resultsExported(String filename) {
    return 'Exported: $filename';
  }

  @override
  String resultsExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get resultsSyntheticNote =>
      'Note: synthetic demo radiation model — not a validated yield forecast.';

  @override
  String get monthlyColMonth => 'Month';

  @override
  String get monthlyColPvAc => 'PV AC (kWh)';

  @override
  String get monthlyColLoad => 'Load (kWh)';

  @override
  String get monthlyColSelfConsumption => 'SC (kWh)';

  @override
  String get monthlyColBatteryCharge => 'Bat-chg. (kWh)';

  @override
  String get monthlyColBatteryDischarge => 'Bat-dch. (kWh)';

  @override
  String get monthlyColImport => 'Import (kWh)';

  @override
  String get monthlyColExport => 'Export (kWh)';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dec';

  @override
  String get geocodingTimeout => 'Address lookup timed out.';

  @override
  String geocodingNetworkError(String error) {
    return 'Network error: $error';
  }

  @override
  String get geocodingRateLimit =>
      'Nominatim rate limit hit (429). Please wait a moment.';

  @override
  String geocodingBadStatus(int code) {
    return 'Nominatim responded with status $code.';
  }

  @override
  String get geocodingInvalidJson => 'Nominatim response is not valid JSON.';

  @override
  String get geocodingInvalidFormat =>
      'Unexpected response format from Nominatim.';

  @override
  String pvgisApiInvalidRequest(String error) {
    return 'Invalid PVGIS request: $error';
  }

  @override
  String get pvgisApiTimeout => 'PVGIS request timed out.';

  @override
  String pvgisApiNetworkError(String error) {
    return 'Network error on PVGIS request: $error';
  }

  @override
  String pvgisApiBadStatus(int code, String message) {
    return 'PVGIS responded with status $code. $message';
  }

  @override
  String pvgisApiParseFailed(String error) {
    return 'Could not read PVGIS response: $error';
  }

  @override
  String get demoArrayLabel => 'South roof';

  @override
  String get demoInverterLabel => 'Main inverter';

  @override
  String get demoBatteryLabel => 'Main battery';

  @override
  String get tabProjects => 'Projects';

  @override
  String get tabIrradiance => 'Irradiance';

  @override
  String get tabArrays => 'PV arrays';

  @override
  String get tabResults => 'Results';

  @override
  String get irradianceTitle => 'Site & irradiance';

  @override
  String get irradianceMapHint =>
      'Pan the map to set the site. The pin marks the current project coordinates.';

  @override
  String get irradianceYearLabel => 'Year';

  @override
  String get irradianceLoadButton => 'Load data';

  @override
  String get irradianceLoadingHint => 'Loading PVGIS irradiance …';

  @override
  String get irradianceEmpty =>
      'Pick a location and press “Load data” to fetch the annual horizontal irradiance.';

  @override
  String get irradianceErrorTitle => 'PVGIS request failed';

  @override
  String get irradianceChartTitle => 'Global horizontal irradiance [ kW/m² ]';

  @override
  String get irradianceSeriesTotal => 'Total';

  @override
  String get irradianceSeriesDiffuse => 'Diffuse';

  @override
  String irradianceAnnualSum(String value) {
    return 'Sum $value kWh/m²';
  }

  @override
  String irradianceAverage(String value) {
    return 'Avg $value W/m²';
  }

  @override
  String get irradianceCacheHit => 'from cache';

  @override
  String get irradianceCacheMiss => 'fresh from PVGIS';

  @override
  String get azimuthCompassTitle => 'Pick azimuth';

  @override
  String get azimuthCompassHint =>
      'Tap to set the azimuth on the selected PV array.';

  @override
  String get azimuthApply => 'Apply';

  @override
  String get azimuthCancel => 'Cancel';

  @override
  String get resultsRun => 'Run simulation';

  @override
  String get resultsRunMissingData =>
      'Load irradiance data and add at least one PV array first.';

  @override
  String get resultsErrorTitle => 'Simulation failed';

  @override
  String get arraysTabHint =>
      'No per-array PVGIS call — every module derives POA from the site-level horizontal data loaded on the Irradiance tab.';

  @override
  String get arraysSelectForCompass => 'Selected for compass picker';

  @override
  String get dispatchPolicyTitle => 'Dispatch policy';

  @override
  String get dispatchPolicyKindLabel => 'Strategy';

  @override
  String get dispatchPolicySelfConsumption => 'Self-consumption first';

  @override
  String get dispatchPolicySelfConsumptionDesc =>
      'PV covers load first, surplus charges batteries, then exports. Default behaviour, identical to the pre-Phase-4 engine.';

  @override
  String get dispatchPolicyReserve => 'Battery reserve';

  @override
  String get dispatchPolicyReserveDesc =>
      'Like self-consumption, but batteries only charge up to a reserve ceiling. PV surplus exports earlier instead of fully storing.';

  @override
  String get dispatchPolicyReserveSoc => 'Reserve ceiling';

  @override
  String get dispatchPolicyReserveSocHelp =>
      'Fraction of capacity (0..1) up to which PV surplus charges the battery. 0.5 = charge to half full only.';

  @override
  String get dispatchPolicyConstantFeed => '24h constant feed';

  @override
  String get dispatchPolicyConstantFeedDesc =>
      'Micro-inverter banks deliver continuously at their target power as long as SOC stays above the shutdown threshold.';

  @override
  String get dispatchPolicyTimeWindow => 'Time-window feed';

  @override
  String get dispatchPolicyTimeWindowDesc =>
      'Micro-inverter banks deliver only inside the time windows configured on each bank.';

  @override
  String get dispatchPolicyGridAssist => 'Grid assist';

  @override
  String get dispatchPolicyGridAssistDesc =>
      'Like self-consumption, but grid import can be disabled — unmet load shows as \"unserved load\".';

  @override
  String get dispatchPolicyGridImportLabel => 'Allow grid import';

  @override
  String get dispatchPolicyGridImportHelp =>
      'Off = islanded. Unmet load is reported as \"unserved load\" instead of grid import.';

  @override
  String get dispatchPolicyBankHint =>
      'Tip: this policy only makes sense with at least one configured micro-inverter bank.';

  @override
  String get microInverterBanksTitle => 'Micro-inverter banks (battery output)';

  @override
  String microInverterBanksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count banks',
      one: '1 bank',
      zero: 'No banks configured',
    );
    return '$_temp0';
  }

  @override
  String get microInverterBanksEmpty =>
      'No banks configured. Use \"Add\" to create a battery-coupled AC output.';

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
      'Note: regular PV micro-inverters expect module IV curves; a battery-fed output requires a device that the manufacturer certifies for that purpose. The simulation does not replace qualified electrical planning.';

  @override
  String get microInverterBankBattery => 'Source battery';

  @override
  String get microInverterBankCount => 'Count';

  @override
  String get microInverterBankUnitW => 'Power per unit';

  @override
  String get microInverterBankShutdown => 'Shutdown SOC';

  @override
  String get microInverterBankShutdownHelp =>
      'Fraction of capacity (0..1) below which the bank stops delivering. 0 = never shut down.';

  @override
  String get microInverterBankEfficiency => 'Efficiency';

  @override
  String get microInverterBankSchedule => 'Schedule';

  @override
  String get microInverterBankAddWindow => 'Window';

  @override
  String get microInverterBankAlwaysOn =>
      'No windows: active 24h (subject to dispatch policy).';

  @override
  String get microInverterBankWindowStart => 'Start (h)';

  @override
  String get microInverterBankWindowEnd => 'End (h)';

  @override
  String get microInverterBankWindowFactor => 'Factor';

  @override
  String get resultsKpiMicroDelivered => 'Micro-inverter delivered';

  @override
  String get resultsKpiMicroShortfall => 'Micro-inverter shortfall';

  @override
  String get resultsKpiUnservedLoad => 'Unserved load';
}
