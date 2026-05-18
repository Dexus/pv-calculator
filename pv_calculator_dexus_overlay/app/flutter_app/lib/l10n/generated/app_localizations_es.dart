// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get commonAdd => 'Añadir';

  @override
  String get commonRemove => 'Quitar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get validationRequired => 'Campo obligatorio';

  @override
  String get validationMustBeNumber => 'Introduce un número';

  @override
  String validationAtLeast(String value) {
    return 'Al menos $value';
  }

  @override
  String validationAtMost(String value) {
    return 'Como máximo $value';
  }

  @override
  String get drawerSubtitle => 'Demo · modelo sintético';

  @override
  String get drawerProjects => 'Proyectos';

  @override
  String get drawerSettings => 'Ajustes';

  @override
  String get drawerAbout => 'Acerca de';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsThemeSystem => 'Seguir al sistema';

  @override
  String get settingsThemeSystemDesc => 'Cambia con el ajuste del dispositivo.';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Usar el idioma del sistema';

  @override
  String get settingsLanguageSystemDesc => 'Sigue el idioma del dispositivo.';

  @override
  String get settingsAboutApp => 'Acerca de la app';

  @override
  String get settingsAboutBody =>
      'Aplicación de demostración para el dimensionamiento PV con almacenamiento por batería y microinversor de 800 W. El modelo de irradiación actual es sintético y no constituye una previsión de producción validada.';

  @override
  String get settingsAdvanced => 'Avanzado';

  @override
  String get settingsExpertMode => 'Modo experto';

  @override
  String get settingsExpertModeDesc =>
      'Muestra el editor de topología, los bancos de microinversores y estrategias de despacho alternativas en la pestaña Resultados.';

  @override
  String get projectListTitle => 'PV Calculator — Proyectos';

  @override
  String get projectListEmpty => 'Aún no hay proyectos guardados.';

  @override
  String get projectListEmptyHint =>
      'Crea un proyecto nuevo o importa un JSON guardado.';

  @override
  String get projectListCreateButton => 'Crear proyecto';

  @override
  String get projectListImportTooltip => 'Importar';

  @override
  String get projectListNewTooltip => 'Proyecto nuevo';

  @override
  String get projectListExportTooltip => 'Exportar';

  @override
  String get projectListDeleteTooltip => 'Eliminar';

  @override
  String get projectListNewDefaultName => 'Proyecto nuevo';

  @override
  String projectListLoadFailed(String name) {
    return 'No se pudo cargar el proyecto «$name».';
  }

  @override
  String projectListImported(String name) {
    return 'Importado: $name';
  }

  @override
  String projectListImportFailed(String error) {
    return 'Error de importación: $error';
  }

  @override
  String projectListDownloaded(String filename) {
    return 'Descargado: $filename';
  }

  @override
  String projectListExported(String filename) {
    return 'Exportado: $filename';
  }

  @override
  String get projectListExportCancelled => 'Exportación cancelada';

  @override
  String projectListExportFailed(String error) {
    return 'Error de exportación: $error';
  }

  @override
  String get projectListConflictTitle => 'El proyecto ya existe';

  @override
  String projectListConflictBody(String name) {
    return '«$name» ya está guardado. ¿La importación debe sobrescribir esta versión o guardarse con otro nombre?';
  }

  @override
  String get projectListConflictRename => 'Renombrar';

  @override
  String get projectListConflictOverwrite => 'Sobrescribir';

  @override
  String get projectListDeleteTitle => '¿Eliminar el proyecto?';

  @override
  String projectListDeleteBody(String name) {
    return '«$name» se eliminará permanentemente.';
  }

  @override
  String projectListSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get editorRun => 'Ejecutar simulación';

  @override
  String get editorValidationTitle => 'Configuración incompleta';

  @override
  String get editorRunErrorTitle => 'La simulación falló';

  @override
  String get editorOrphanedTitle => 'Imports PVGIS sin campo asociado';

  @override
  String get editorOrphanedBody =>
      'Las series meteorológicas importadas a continuación apuntan a campos eliminados o renombrados y no se usan en la simulación. Usa «Olvidar» para liberarlas.';

  @override
  String get editorOrphanedForget => 'Olvidar';

  @override
  String get editorWeatherSynthetic =>
      'Nota: esta simulación usa un modelo de irradiación demo sintético y no sustituye a la validación PVGIS. Puedes importar un JSON horario PVGIS por campo para usar irradiación real.';

  @override
  String get editorWeatherSession =>
      ' Los imports PVGIS solo valen para esta sesión; deben reimportarse al volver a abrir un proyecto guardado.';

  @override
  String editorWeatherAll(int total, String session) {
    return 'Fuente meteorológica: datos PVGIS importados para los $total campos. Promedios TMY sobre los años incluidos en el archivo.$session';
  }

  @override
  String editorWeatherMixed(int withCount, int total, String session) {
    return 'Fuente meteorológica mixta: $withCount de $total campos usan datos PVGIS importados; el resto vuelve al modelo demo sintético.$session';
  }

  @override
  String get projectSectionTitle => 'Proyecto';

  @override
  String get projectName => 'Nombre del proyecto';

  @override
  String get projectLatitude => 'Latitud';

  @override
  String get projectLongitude => 'Longitud';

  @override
  String get projectStartDay => 'Día inicial del año';

  @override
  String get projectSimulationDays => 'Días de simulación';

  @override
  String get projectPreRunDays => 'Días de precalentado';

  @override
  String get projectPreRunHelp =>
      'Número de días de precalentado para el modo \"Precalentado simple\". Solo se aplica si ese modo está activo; los pasos de precalentado no aparecen en los resultados.';

  @override
  String get projectPreRunMode => 'Precarga del SOC';

  @override
  String get projectPreRunModeManual => 'SOC inicial manual';

  @override
  String get projectPreRunModeSingle => 'Precalentado simple';

  @override
  String get projectPreRunModeCyclic => 'Convergencia cíclica';

  @override
  String get projectPreRunModeCyclicPro => 'Convergencia cíclica (Pro)';

  @override
  String get projectConvergenceTolerance => 'Tolerancia de convergencia';

  @override
  String get projectConvergenceToleranceHelp =>
      '|inicio − final| SOC máximo tras un ciclo, en % de la capacidad útil. PRD §6.2 sugiere 0,5 %.';

  @override
  String get projectMaxConvergenceIterations => 'Iteraciones máx.';

  @override
  String get projectExportLimit => 'Límite de inyección';

  @override
  String get projectSimulationYears => 'Años de simulación';

  @override
  String get projectSimulationYearsHelp =>
      'Número de años consecutivos a simular. Con > 1, la potencia de los módulos se reduce por año según el factor de degradación; el SOC se mantiene entre años.';

  @override
  String get pvArrayDegradation => 'Degradación';

  @override
  String get pvArrayDegradationHelp =>
      'Pérdida anual de potencia en %/año. Típico 0,4–0,7 para silicio cristalino. Solo efectivo con años de simulación > 1.';

  @override
  String get tariffSectionTitle => 'Tarifa eléctrica';

  @override
  String get tariffEnabled => 'Calcular economía';

  @override
  String get tariffEnabledHelp =>
      'Calcula el coste de importación y los ingresos por exportación a partir de los precios introducidos.';

  @override
  String get tariffImportLabel => 'Precio de importación';

  @override
  String get tariffExportLabel => 'Tarifa de exportación';

  @override
  String get tariffTouTitle => 'Precios por franja horaria';

  @override
  String get tariffTouHelp =>
      '24 franjas horarias para precios variables de importación/exportación. Función Pro.';

  @override
  String get tariffTouImportHeader =>
      'Precios horarios de importación (EUR/kWh)';

  @override
  String get tariffTouExportHeader => 'Tarifa horaria de exportación (EUR/kWh)';

  @override
  String get resultsKpiImportCost => 'Coste importación';

  @override
  String get resultsKpiExportRevenue => 'Ingresos exportación';

  @override
  String get resultsKpiNetCost => 'Coste neto de electricidad';

  @override
  String get resultsPdfReport => 'Exportar informe (PDF)';

  @override
  String get resultsPdfReportProTooltip =>
      'Los informes PDF son una función Pro.';

  @override
  String get projectTimeStep => 'Paso temporal';

  @override
  String get projectTimeStepHourly => 'Horario';

  @override
  String get projectTimeStepQuarter => 'Cuarto de hora';

  @override
  String get projectPvgisApiTitle => 'API PVGIS';

  @override
  String get projectPvgisApiHelp =>
      'Ventana temporal y base de irradiación para «Cargar desde API PVGIS». PVGIS-SARAH3 cubre típicamente 2005–2023; cuanto más ancha la ventana, más estables los promedios TMY.';

  @override
  String get projectPvgisStartYear => 'Año inicial PVGIS';

  @override
  String get projectPvgisEndYear => 'Año final PVGIS';

  @override
  String get projectRadDatabase => 'Base de irradiación';

  @override
  String get projectRadDatabaseAuto => 'PVGIS auto';

  @override
  String get projectAddressSearch => 'Buscar dirección (OpenStreetMap)';

  @override
  String get projectAddressHint => 'p. ej. Marktplatz 1, Frankfurt';

  @override
  String get projectAddressNoResults => 'Sin resultados.';

  @override
  String get fieldId => 'ID';

  @override
  String get fieldLabel => 'Etiqueta';

  @override
  String get arraysTitle => 'Campos PV';

  @override
  String get arraysEmpty => 'Se requiere al menos un campo.';

  @override
  String arraysDefaultLabel(int n) {
    return 'Campo $n';
  }

  @override
  String arraysHeading(int n) {
    return 'Campo $n';
  }

  @override
  String get arraysFieldPeak => 'Potencia pico';

  @override
  String get arraysFieldAzimuth => 'Azimut';

  @override
  String get arraysFieldTilt => 'Inclinación';

  @override
  String get arraysFieldLosses => 'Pérdidas';

  @override
  String get arraysFieldShading => 'Sombreado';

  @override
  String get arraysFieldTempCoef => 'Coef. temperatura';

  @override
  String get arraysFieldTempCoefHelp =>
      'Pérdida de potencia por °C de temperatura de célula por encima de 25 °C. Silicio cristalino ≈ −0,4 %/°C; 0 desactiva el derating por temperatura.';

  @override
  String get arraysFieldNoct => 'NOCT';

  @override
  String get arraysFieldNoctHelp =>
      'Nominal Operating Cell Temperature: temperatura de célula a 800 W/m², 20 °C de aire, 1 m/s de viento. Típico 45 °C.';

  @override
  String get arraysFieldInverter => 'Inversor';

  @override
  String get arraysFieldInverterRequired => 'Selecciona un inversor';

  @override
  String get pvgisIdRequired => 'Asigna primero un ID al campo.';

  @override
  String pvgisImported(String id, int count) {
    return 'Datos PVGIS importados para «$id» ($count valores).';
  }

  @override
  String pvgisImportFailed(String error) {
    return 'Error en importación PVGIS: $error';
  }

  @override
  String get pvgisArrayNotFound => 'Campo no encontrado.';

  @override
  String pvgisInvalidRequest(String error) {
    return 'Solicitud PVGIS inválida: $error';
  }

  @override
  String pvgisApiLoaded(String id, int count) {
    return 'Datos API PVGIS cargados para «$id» ($count valores).';
  }

  @override
  String pvgisApiFailed(String error) {
    return 'Error en solicitud API PVGIS: $error';
  }

  @override
  String get pvgisStatusSynthetic =>
      'Fuente meteorológica: modelo demo sintético';

  @override
  String get pvgisStatusLoaded => 'Datos PVGIS cargados';

  @override
  String pvgisMetadata(
    String source,
    int count,
    String years,
    String lat,
    String lon,
    String orientation,
  ) {
    return '$source · $count horas · Años $years · Ubicación PVGIS $lat°/$lon°$orientation';
  }

  @override
  String get pvgisSessionNote =>
      'Nota: los imports PVGIS solo valen para esta sesión; no se guardan en el JSON del proyecto.';

  @override
  String pvgisOrientationWarning(String issues) {
    return 'La orientación PVGIS difiere ($issues). Los valores POA importados corresponden a la orientación PVGIS, no a la configurada aquí.';
  }

  @override
  String pvgisOrientationTilt(String value) {
    return 'Inclinación $value°';
  }

  @override
  String pvgisOrientationAzimuth(String value) {
    return 'Azimut $value°';
  }

  @override
  String pvgisTiltMismatch(String imported, String configured) {
    return 'Inclinación $imported° vs $configured°';
  }

  @override
  String pvgisAzimuthMismatch(String imported, String configured) {
    return 'Azimut $imported° vs $configured°';
  }

  @override
  String get pvgisReloadApi => 'Recargar API';

  @override
  String get pvgisLoadFromApi => 'Cargar desde API PVGIS';

  @override
  String get pvgisImportJson => 'Importar JSON';

  @override
  String get invertersTitle => 'Inversores';

  @override
  String get invertersEmpty => 'Se requiere al menos un inversor.';

  @override
  String invertersDefaultLabel(int n) {
    return 'Inversor $n';
  }

  @override
  String invertersHeading(int n) {
    return 'Inversor $n';
  }

  @override
  String get invertersFieldMaxAc => 'Potencia AC máx.';

  @override
  String get invertersFieldEfficiency => 'Rendimiento';

  @override
  String get invertersFieldMaxDc => 'Entrada DC máx.';

  @override
  String get invertersFieldMaxDcHelp =>
      'Límite opcional de entrada DC (MPPT). La potencia DC superior se recorta antes del inversor y se contabiliza como recorte. Deja vacío si el inversor no está sobredimensionado.';

  @override
  String get invertersFieldRole => 'Rol';

  @override
  String get invertersRoleGrid => 'Red';

  @override
  String get invertersRoleMicro => 'Micro 800 W';

  @override
  String get invertersRoleBattery => 'Acoplado a batería';

  @override
  String get invertersRoleMicroHelp =>
      'Solar 800 W de enchufe: la salida AC se recorta a 0,8 kW independientemente de la potencia AC máx. configurada.';

  @override
  String get invertersRoleBatteryHelp =>
      'Inversor acoplado en DC a una batería; medido como inversor de red pero marcado semánticamente.';

  @override
  String get invertersRoleGridHelp =>
      'Inversor de red estándar sin tope AC duro.';

  @override
  String get batteriesTitle => 'Almacenamiento por batería';

  @override
  String get batteriesEmpty => 'No hay batería configurada (opcional).';

  @override
  String batteriesDefaultLabel(int n) {
    return 'Batería $n';
  }

  @override
  String batteriesHeading(int n) {
    return 'Batería $n';
  }

  @override
  String get batteriesFieldCapacity => 'Capacidad';

  @override
  String get batteriesFieldChargePower => 'Potencia de carga máx.';

  @override
  String get batteriesFieldDischargePower => 'Potencia de descarga máx.';

  @override
  String get batteriesFieldRoundtrip => 'Rendimiento ciclo completo';

  @override
  String get batteriesFieldRoundtripHelp =>
      'Rendimiento de carga × descarga. Típico 0,9 para litio, ≈ 0,75 para plomo.';

  @override
  String get batteriesFieldMinSoc => 'SOC mín.';

  @override
  String get batteriesCustomInitial => 'Establecer SOC inicial manualmente';

  @override
  String get batteriesFieldStartSoc => 'SOC inicial';

  @override
  String get loadTitle => 'Perfil de carga';

  @override
  String get loadFieldDaily => 'Consumo diario';

  @override
  String get loadHourlyHint =>
      'Forma horaria: perfil estándar de hogar alemán (24 valores). La edición manual de la forma horaria está prevista para una versión posterior.';

  @override
  String resultsTitle(String name) {
    return 'Resultado — $name';
  }

  @override
  String get resultsEmpty => 'No se ha ejecutado ninguna simulación.';

  @override
  String get resultsBack => 'Volver a la configuración';

  @override
  String get resultsAnnualKpis => 'Indicadores anuales';

  @override
  String get resultsKpiPvAc => 'PV AC';

  @override
  String get resultsKpiLoad => 'Carga';

  @override
  String get resultsKpiSelfConsumption => 'Autoconsumo';

  @override
  String get resultsKpiGridImport => 'Importación de red';

  @override
  String get resultsKpiGridExport => 'Inyección a red';

  @override
  String get resultsKpiCurtailDc => 'Recorte DC (MPPT)';

  @override
  String get resultsKpiCurtailAc => 'Recorte AC (tope inversor)';

  @override
  String get resultsKpiCurtailExport => 'Recorte de inyección';

  @override
  String get resultsKpiBatteryCharge => 'Carga batería';

  @override
  String get resultsKpiBatteryDischarge => 'Descarga batería';

  @override
  String get resultsKpiAutarky => 'Autonomía';

  @override
  String get resultsKpiSelfConsumptionRate => 'Tasa de autoconsumo';

  @override
  String get resultsBatterySection => 'Baterías (SOC final)';

  @override
  String resultsBatteryLabel(int n) {
    return 'Batería $n';
  }

  @override
  String get resultsPreRunSection => 'Precarga del SOC';

  @override
  String get resultsPreRunMode => 'Modo';

  @override
  String get resultsPreRunIterations => 'Iteraciones';

  @override
  String get resultsPreRunConverged => 'Convergido';

  @override
  String get resultsPreRunConvergedYes => 'Sí';

  @override
  String get resultsPreRunConvergedNo => 'No';

  @override
  String resultsPreRunStartSoc(int n) {
    return 'SOC inicial batería $n';
  }

  @override
  String get resultsMonthly => 'Balance mensual';

  @override
  String get resultsCsvSteps => 'Exportar CSV pasos';

  @override
  String get resultsCsvMonthly => 'Exportar CSV mensual';

  @override
  String resultsCsvPending(int size) {
    return 'CSV listo ($size caracteres). La exportación llegará en la capa de persistencia.';
  }

  @override
  String resultsExported(String filename) {
    return 'Exportado: $filename';
  }

  @override
  String resultsExportFailed(String error) {
    return 'Error de exportación: $error';
  }

  @override
  String get resultsSyntheticNote =>
      'Nota: modelo de irradiación demo sintético — no es una previsión de producción validada.';

  @override
  String get monthlyColMonth => 'Mes';

  @override
  String get monthlyColPvAc => 'PV AC (kWh)';

  @override
  String get monthlyColLoad => 'Carga (kWh)';

  @override
  String get monthlyColSelfConsumption => 'AC (kWh)';

  @override
  String get monthlyColBatteryCharge => 'Bat-car. (kWh)';

  @override
  String get monthlyColBatteryDischarge => 'Bat-des. (kWh)';

  @override
  String get monthlyColImport => 'Import (kWh)';

  @override
  String get monthlyColExport => 'Inyec. (kWh)';

  @override
  String get monthJan => 'Ene';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Abr';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Ago';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dic';

  @override
  String get geocodingTimeout => 'Tiempo agotado en la búsqueda de dirección.';

  @override
  String geocodingNetworkError(String error) {
    return 'Error de red: $error';
  }

  @override
  String get geocodingRateLimit =>
      'Nominatim ha alcanzado el límite (429). Espera un momento.';

  @override
  String geocodingBadStatus(int code) {
    return 'Nominatim respondió con el estado $code.';
  }

  @override
  String get geocodingInvalidJson =>
      'La respuesta de Nominatim no es JSON válido.';

  @override
  String get geocodingInvalidFormat =>
      'Formato de respuesta inesperado de Nominatim.';

  @override
  String pvgisApiInvalidRequest(String error) {
    return 'Solicitud PVGIS inválida: $error';
  }

  @override
  String get pvgisApiTimeout => 'Tiempo agotado en la solicitud PVGIS.';

  @override
  String pvgisApiNetworkError(String error) {
    return 'Error de red en la solicitud PVGIS: $error';
  }

  @override
  String pvgisApiBadStatus(int code, String message) {
    return 'PVGIS respondió con el estado $code. $message';
  }

  @override
  String pvgisApiParseFailed(String error) {
    return 'No se pudo leer la respuesta PVGIS: $error';
  }

  @override
  String get demoArrayLabel => 'Tejado sur';

  @override
  String get demoInverterLabel => 'Inversor principal';

  @override
  String get demoBatteryLabel => 'Batería principal';

  @override
  String get tabProjects => 'Proyectos';

  @override
  String get tabIrradiance => 'Irradiancia';

  @override
  String get tabArrays => 'Campos PV';

  @override
  String get tabResults => 'Resultados';

  @override
  String get irradianceTitle => 'Sitio e irradiancia';

  @override
  String get irradianceMapHint =>
      'Desplaza el mapa para fijar la ubicación. El pin marca las coordenadas actuales del proyecto.';

  @override
  String get irradianceYearLabel => 'Periodo';

  @override
  String get irradianceLoadButton => 'Cargar datos';

  @override
  String get irradianceLoadingHint => 'Cargando irradiancia PVGIS …';

  @override
  String get irradianceEmpty =>
      'Selecciona una ubicación y pulsa «Cargar datos» para obtener la irradiancia anual.';

  @override
  String get irradianceErrorTitle => 'La solicitud PVGIS falló';

  @override
  String get irradianceChartTitle => 'Irradiancia global horizontal [ kW/m² ]';

  @override
  String get irradianceSeriesTotal => 'Total';

  @override
  String get irradianceSeriesDiffuse => 'Difusa';

  @override
  String irradianceAnnualSum(String value) {
    return 'Suma $value kWh/m²';
  }

  @override
  String irradianceAverage(String value) {
    return 'Med. $value W/m²';
  }

  @override
  String get irradianceCacheHit => 'desde caché';

  @override
  String get irradianceCacheMiss => 'fresco desde PVGIS';

  @override
  String get azimuthCompassTitle => 'Elegir azimut';

  @override
  String get azimuthCompassHint =>
      'Toca para fijar el azimut del campo PV seleccionado.';

  @override
  String get azimuthApply => 'Aplicar';

  @override
  String get azimuthCancel => 'Cancelar';

  @override
  String get resultsRun => 'Iniciar simulación';

  @override
  String get resultsRunMissingData =>
      'Carga primero los datos de irradiancia y añade al menos un campo PV.';

  @override
  String get resultsErrorTitle => 'La simulación falló';

  @override
  String get resultsRunStarting => 'Iniciando…';

  @override
  String get resultsRunPhasePreRun =>
      'Estabilizando SOC de la batería (precarrera)';

  @override
  String get resultsRunPhaseReporting => 'Simulando el año de referencia';

  @override
  String resultsRunPhaseConvergence(int iteration) {
    return 'Convergencia cíclica, iteración $iteration';
  }

  @override
  String get arraysTabHint =>
      'Sin llamadas PVGIS por campo: todos los módulos derivan su POA de los datos horizontales del sitio cargados en la pestaña «Irradiancia».';

  @override
  String get arraysSelectForCompass => 'Seleccionado para la brújula';

  @override
  String get dispatchPolicyTitle => 'Estrategia de despacho';

  @override
  String get dispatchPolicyKindLabel => 'Estrategia';

  @override
  String get dispatchPolicySelfConsumption => 'Autoconsumo primero';

  @override
  String get dispatchPolicySelfConsumptionDesc =>
      'El PV cubre primero la carga, el excedente carga las baterías y luego se exporta. Comportamiento por defecto, idéntico al motor previo a la fase 4.';

  @override
  String get dispatchPolicyReserve => 'Reserva de batería';

  @override
  String get dispatchPolicyReserveDesc =>
      'Como autoconsumo, pero las baterías solo se cargan hasta un techo de reserva. El excedente PV se exporta antes en vez de almacenarse por completo.';

  @override
  String get dispatchPolicyReserveSoc => 'Techo de reserva';

  @override
  String get dispatchPolicyReserveSocHelp =>
      'Fracción de la capacidad (0..1) hasta la que el excedente PV carga la batería. 0,5 = cargar solo hasta la mitad.';

  @override
  String get dispatchPolicyConstantFeed => 'Inyección continua 24 h';

  @override
  String get dispatchPolicyConstantFeedDesc =>
      'Los bancos de microinversores inyectan continuamente a su potencia objetivo mientras el SOC supere el umbral de apagado.';

  @override
  String get dispatchPolicyTimeWindow => 'Inyección por ventanas';

  @override
  String get dispatchPolicyTimeWindowDesc =>
      'Los bancos solo inyectan dentro de las ventanas horarias configuradas en cada banco.';

  @override
  String get dispatchPolicyGridAssist => 'Asistencia de red';

  @override
  String get dispatchPolicyGridAssistDesc =>
      'Como autoconsumo, pero la importación de red puede desactivarse — la carga no cubierta aparece como «carga no servida».';

  @override
  String get dispatchPolicyGridImportLabel => 'Permitir importación de red';

  @override
  String get dispatchPolicyGridImportHelp =>
      'Desactivado = modo aislado. La carga no cubierta se contabiliza como «carga no servida» en vez de importación de red.';

  @override
  String get dispatchPolicyBankHint =>
      'Sugerencia: esta estrategia solo tiene sentido con al menos un banco de microinversores configurado.';

  @override
  String get microInverterBanksTitle =>
      'Bancos de microinversores (salida de batería)';

  @override
  String microInverterBanksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bancos',
      one: '1 banco',
      zero: 'Sin bancos configurados',
    );
    return '$_temp0';
  }

  @override
  String get microInverterBanksEmpty =>
      'Sin bancos configurados. Use «Añadir» para crear una salida AC acoplada a batería.';

  @override
  String microInverterBanksHeading(int n) {
    return 'Banco $n';
  }

  @override
  String microInverterBanksDefaultLabel(int n) {
    return 'Banco $n';
  }

  @override
  String get microInverterBanksWarnPvDevice =>
      'Nota: los microinversores PV convencionales esperan curvas IV de módulo; una salida alimentada por batería requiere un dispositivo certificado por el fabricante para ese uso. La simulación no sustituye una planificación eléctrica cualificada.';

  @override
  String get microInverterBankBattery => 'Batería fuente';

  @override
  String get microInverterBankCount => 'Cantidad';

  @override
  String get microInverterBankUnitW => 'Potencia por unidad';

  @override
  String get microInverterBankShutdown => 'SOC de apagado';

  @override
  String get microInverterBankShutdownHelp =>
      'Fracción de la capacidad (0..1) por debajo de la cual el banco deja de entregar. 0 = nunca apagar.';

  @override
  String get microInverterBankEfficiency => 'Eficiencia';

  @override
  String get microInverterBankSchedule => 'Programación';

  @override
  String get microInverterBankScheduleKind => 'Tipo de programación';

  @override
  String get microInverterBankScheduleAlwaysOn => 'Siempre activo';

  @override
  String get microInverterBankScheduleTimeWindows => 'Ventanas horarias';

  @override
  String get microInverterBankScheduleHourly => 'Horaria (24 factores)';

  @override
  String get microInverterBankAddWindow => 'Ventana';

  @override
  String get microInverterBankAlwaysOn =>
      'Siempre activo: 24 h (según la estrategia de despacho).';

  @override
  String get microInverterBankWindowStart => 'Inicio (h)';

  @override
  String get microInverterBankWindowEnd => 'Fin (h)';

  @override
  String get microInverterBankWindowFactor => 'Factor';

  @override
  String microInverterBankHourlyHour(int hour) {
    return '$hour:00';
  }

  @override
  String get microInverterBankHourlyHelp =>
      'Factor por hora (0..1). 1,0 = potencia objetivo completa, 0,0 = apagado. Se aplica al objetivo del banco, no directamente al SOC.';

  @override
  String get microInverterBankHourlyReset => 'Restablecer a 1,0';

  @override
  String get resultsKpiMicroDelivered => 'Microinversor entregado';

  @override
  String get resultsKpiMicroShortfall => 'Microinversor déficit';

  @override
  String get resultsKpiUnservedLoad => 'Carga no servida';

  @override
  String microInverterBanksWarnSharedPvInverter(String inverterId) {
    return 'Aviso: el inversor «$inverterId» está configurado como microinversor PV de 800 W con módulos PV conectados. Los microinversores PV convencionales no pueden alimentarse desde una batería: la salida de batería necesita un dispositivo separado certificado por el fabricante para ese uso.';
  }

  @override
  String get bankRuntimeSectionTitle => 'Salida 24h — autonomía diaria';

  @override
  String get bankRuntimeLegendFull =>
      'Plenamente cubierto (objetivo alcanzado)';

  @override
  String get bankRuntimeLegendPartial => 'Parcial (por debajo del objetivo)';

  @override
  String get bankRuntimeLegendShortfall =>
      'Déficit (horas programadas sin entrega)';

  @override
  String bankRuntimeStatCoverage(String pct) {
    return 'Cobertura: $pct %';
  }

  @override
  String bankRuntimeStatAvgHours(String hours) {
    return 'Media $hours h/día activo';
  }

  @override
  String bankRuntimeStatDelivered(String kwh) {
    return 'Entregado: $kwh kWh';
  }

  @override
  String bankRuntimeStatShortfall(String kwh) {
    return 'Déficit: $kwh kWh';
  }

  @override
  String get topologyTitle => 'Topología';

  @override
  String get topologyEnable => 'Usar topología explícita';

  @override
  String get topologyAutoGeneratedInfo =>
      'Desactivado: el motor deriva una topología por defecto a partir de los arrays, inversores y baterías.';

  @override
  String get topologyDcBusesTitle => 'Buses DC';

  @override
  String get topologyAcBusesTitle => 'Buses AC';

  @override
  String get topologyMpptTitle => 'Nodos MPPT';

  @override
  String get topologyMpptEmpty =>
      'Sin MPPTs configurados. Use «Inicializar desde la configuración actual» para derivarlos de los inversores.';

  @override
  String get topologyEdgesTitle => 'Aristas';

  @override
  String get topologyCouplingsTitle => 'Acoplamientos de batería';

  @override
  String get topologyCouplingsEmpty => 'Sin baterías configuradas.';

  @override
  String get topologyAddDcBus => 'Bus DC';

  @override
  String get topologyAddAcBus => 'Bus AC';

  @override
  String get topologyAddEdge => 'Arista';

  @override
  String get topologyEdgeFrom => 'Desde';

  @override
  String get topologyEdgeTo => 'Hacia';

  @override
  String get topologyEdgeEfficiency => 'Eficiencia';

  @override
  String get topologyEdgeMaxPowerKw => 'Potencia máx.';

  @override
  String get topologyEdgeStandbyW => 'En espera';

  @override
  String get topologyCouplingAc => 'AC';

  @override
  String get topologyCouplingDc => 'DC';

  @override
  String get topologyCouplingDcBus => 'Bus DC';

  @override
  String get topologyCouplingInverter => 'Inversor de batería';

  @override
  String get topologyCouplingInverterNone => '— ninguno —';

  @override
  String get topologyCouplingInverterHelp =>
      'Opcional: el inversor que limita la potencia AC de la batería (Arquitectura §5.3). Vacío = `BatteryConfig.maxDischargeKw` es el límite AC.';

  @override
  String get topologySeedFromLegacy =>
      'Inicializar desde la configuración actual';

  @override
  String projectsTabCompareButton(int count) {
    return 'Comparar ($count)';
  }

  @override
  String projectsTabScenarioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count escenarios',
      one: '1 escenario',
      zero: 'Sin escenarios',
    );
    return '$_temp0';
  }

  @override
  String get projectsTabEmptyScenarios =>
      'Aún no hay escenarios en este proyecto.';

  @override
  String get projectsTabPopupNewScenario => 'Nuevo escenario';

  @override
  String get projectsTabPopupRename => 'Renombrar';

  @override
  String get projectsTabPopupDeleteProject => 'Eliminar proyecto';

  @override
  String get projectsTabDuplicateTooltip => 'Duplicar';

  @override
  String get projectsTabRenameTooltip => 'Renombrar';

  @override
  String get projectsTabExportTooltip => 'Exportar';

  @override
  String get projectsTabDeleteTooltip => 'Eliminar';

  @override
  String get projectsTabRenameProjectTitle => 'Renombrar proyecto';

  @override
  String get projectsTabRenameScenarioTitle => 'Renombrar escenario';

  @override
  String get projectsTabNewScenarioTitle => 'Nuevo escenario';

  @override
  String get projectsTabDeleteScenarioTitle => '¿Eliminar escenario?';

  @override
  String projectsTabDeleteScenarioBody(String name) {
    return '¿Eliminar \"$name\" realmente?';
  }

  @override
  String get projectsTabDialogSave => 'Guardar';

  @override
  String get projectsTabDialogCreate => 'Crear';

  @override
  String get projectsTabSuggestedScenarioName => 'Escenario';

  @override
  String get compareTitle => 'Comparación de escenarios';

  @override
  String get comparePreparing => 'Preparando…';

  @override
  String get compareEmptyHint =>
      'Selecciona al menos dos escenarios en la pestaña Proyectos.';

  @override
  String get compareKpisCard => 'KPIs';

  @override
  String get compareChartCard => 'Balance energético comparado';

  @override
  String get compareTableScenario => 'Escenario';

  @override
  String get compareTablePvAcKwh => 'FV CA (kWh)';

  @override
  String get compareTableSelfConsumption => 'Autoconsumo %';

  @override
  String get compareTableAutarky => 'Autonomía %';

  @override
  String get compareTableGridImport => 'Consumo de red (kWh)';

  @override
  String get compareTableGridExport => 'Inyección a la red (kWh)';

  @override
  String get compareTableMicroInverter => 'Microinv. (kWh)';

  @override
  String get compareTableCurtailedAc => 'Limitación CA (kWh)';

  @override
  String get compareTableSource => 'Origen';

  @override
  String get compareTableSourceCache => 'Caché';

  @override
  String get compareTableSourceFresh => 'Nuevo';

  @override
  String get compareChartPvAc => 'FV CA';

  @override
  String get compareChartSelfConsumption => 'Autocons.';

  @override
  String get compareChartGridImport => 'Cons. red';

  @override
  String get compareChartGridExport => 'Inyección';

  @override
  String get resultsEnableExpertHint => 'Activar ajustes avanzados';

  @override
  String get resultsEnableExpertHintDesc =>
      'La topología, los bancos de microinversores y las estrategias de despacho están disponibles en modo experto.';

  @override
  String get resultsAdvancedScenarioBanner =>
      'Este escenario usa funciones avanzadas (topología, bancos de microinversores o un despacho personalizado). Activa el modo experto para verlas y editarlas.';

  @override
  String get wizardTitle => 'Crear un nuevo proyecto';

  @override
  String get wizardStepSite => 'Ubicación';

  @override
  String get wizardStepArray => 'Campo FV';

  @override
  String get wizardStepBattery => 'Batería';

  @override
  String get wizardStepLoad => 'Perfil de carga';

  @override
  String get wizardStepSummary => 'Resumen';

  @override
  String get wizardProjectName => 'Nombre del proyecto';

  @override
  String get wizardLatitude => 'Latitud';

  @override
  String get wizardLongitude => 'Longitud';

  @override
  String get wizardArrayPeak => 'Potencia pico';

  @override
  String get wizardArrayAzimuth => 'Azimut (0 = norte, 180 = sur)';

  @override
  String get wizardArrayTilt => 'Inclinación';

  @override
  String get wizardAddBattery => 'Añadir una batería';

  @override
  String get wizardBatteryCapacity => 'Capacidad';

  @override
  String get wizardBatteryChargeRate => 'Pot. carga máx.';

  @override
  String get wizardBatteryDischargeRate => 'Pot. descarga máx.';

  @override
  String get wizardLoadDaily => 'Consumo diario';

  @override
  String get wizardSummaryIntro =>
      'Estos valores se aplicarán al nuevo proyecto. Puedes ajustarlos más adelante en el editor y cargar después los datos de irradiación.';

  @override
  String get wizardSummaryName => 'Proyecto';

  @override
  String get wizardSummarySite => 'Ubicación';

  @override
  String wizardSummaryArray(String peak, String azimuth, String tilt) {
    return 'FV: $peak kWp, $azimuth°/$tilt°';
  }

  @override
  String get wizardSummaryBatteryNone => 'Sin batería';

  @override
  String wizardSummaryBattery(
    String capacity,
    String charge,
    String discharge,
  ) {
    return 'Batería: $capacity kWh ($charge/$discharge kW)';
  }

  @override
  String wizardSummaryLoad(String kwh) {
    return 'Carga: $kwh kWh/día';
  }

  @override
  String get wizardCancel => 'Cancelar';

  @override
  String get wizardBack => 'Atrás';

  @override
  String get wizardContinue => 'Continuar';

  @override
  String get wizardFinish => 'Crear proyecto';

  @override
  String get warningsSectionTitle => 'Avisos de configuración';

  @override
  String warningInverterOversized(String inverter, String ratio) {
    return 'El inversor \"$inverter\" tiene una relación DC/CA de $ratio — es probable recortar potencia durante el día.';
  }

  @override
  String warningBankExceedsDischarge(
    String bank,
    String bankKw,
    String dischargeKw,
  ) {
    return 'El banco \"$bank\" demanda $bankKw kW, pero la batería solo puede entregar $dischargeKw kW — falta crónica.';
  }

  @override
  String warningBatteryMinSocHigh(String battery, String pct) {
    return 'La batería \"$battery\" reserva $pct% de su capacidad como minSOC — la energía utilizable se reduce mucho.';
  }

  @override
  String get hintIrradianceMissing =>
      'No se han cargado datos de irradiación. La simulación usará el modelo sintético de demostración — abre la pestaña Irradiación para cargar valores reales.';
}
