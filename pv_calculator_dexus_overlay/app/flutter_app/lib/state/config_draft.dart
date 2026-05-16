import 'package:pv_engine/pv_engine.dart';

/// Mutable working copy of [SimulationConfig] for UI editing.
///
/// Engine types are immutable; the editor needs fields the user can mutate
/// before re-building a fresh [SimulationConfig] for simulation/persistence.
/// No dispatch logic lives here.
class ConfigDraft {
  ConfigDraft({
    this.startDayOfYear = 1,
    this.days = 365,
    this.timeStep = TimeStep.hourly,
    this.preRunDays = 0,
    this.gridExportLimitKw,
    this.latitudeDeg = 50.0,
    List<PvArrayDraft>? arrays,
    List<InverterDraft>? inverters,
    List<BatteryDraft>? batteries,
    LoadProfileDraft? loadProfile,
  })  : arrays = arrays ?? <PvArrayDraft>[],
        inverters = inverters ?? <InverterDraft>[],
        batteries = batteries ?? <BatteryDraft>[],
        loadProfile = loadProfile ?? LoadProfileDraft();

  int startDayOfYear;
  int days;
  TimeStep timeStep;
  int preRunDays;
  double? gridExportLimitKw;
  double latitudeDeg;
  final List<PvArrayDraft> arrays;
  final List<InverterDraft> inverters;
  final List<BatteryDraft> batteries;
  LoadProfileDraft loadProfile;

  SimulationConfig build() => SimulationConfig(
        arrays: arrays.map((a) => a.build()).toList(growable: false),
        inverters: inverters.map((i) => i.build()).toList(growable: false),
        batteries: batteries.map((b) => b.build()).toList(growable: false),
        loadProfile: loadProfile.build(),
        startDayOfYear: startDayOfYear,
        days: days,
        timeStep: timeStep,
        preRunDays: preRunDays,
        gridExportLimitKw: gridExportLimitKw,
        latitudeDeg: latitudeDeg,
      );

  String? validationError() {
    try {
      build().validate();
      return null;
    } on ArgumentError catch (e) {
      return e.message?.toString() ?? e.toString();
    }
  }

  static ConfigDraft fromConfig(SimulationConfig config) => ConfigDraft(
        startDayOfYear: config.startDayOfYear,
        days: config.days,
        timeStep: config.timeStep,
        preRunDays: config.preRunDays,
        gridExportLimitKw: config.gridExportLimitKw,
        latitudeDeg: config.latitudeDeg,
        arrays: config.arrays.map(PvArrayDraft.fromArray).toList(),
        inverters: config.inverters.map(InverterDraft.fromInverter).toList(),
        batteries: config.batteries.map(BatteryDraft.fromBattery).toList(),
        loadProfile: LoadProfileDraft.fromProfile(config.loadProfile),
      );

  static ConfigDraft demo() => ConfigDraft(
        arrays: [
          PvArrayDraft(id: 'south-roof', label: 'Süddach', peakKw: 4.8, azimuthDeg: 180, tiltDeg: 35, inverterId: 'main'),
        ],
        inverters: [
          InverterDraft(id: 'main', label: 'Hauptwechselrichter', maxAcKw: 5.0),
        ],
        batteries: [
          BatteryDraft(id: 'main', label: 'Hauptspeicher', capacityKwh: 7.5, maxChargeKw: 3.0, maxDischargeKw: 3.0, minSocKwh: 0.5),
        ],
        loadProfile: LoadProfileDraft(dailyKwh: 10.5),
        days: 365,
        preRunDays: 365,
        gridExportLimitKw: 6.0,
        latitudeDeg: 50.1,
      );
}

class PvArrayDraft {
  PvArrayDraft({
    required this.id,
    this.label = '',
    this.peakKw = 1.0,
    this.azimuthDeg = 180,
    this.tiltDeg = 35,
    this.inverterId = '',
    this.lossFactor = 0.14,
    this.shadingFactor = 0.0,
    this.temperatureCoefficientPctPerC = 0.0,
    this.nominalOperatingCellTempC = 45.0,
  });

  String id;
  String label;
  double peakKw;
  double azimuthDeg;
  double tiltDeg;
  String inverterId;
  double lossFactor;
  double shadingFactor;
  double temperatureCoefficientPctPerC;
  double nominalOperatingCellTempC;

  PvArray build() => PvArray(
        id: id,
        label: label,
        peakKw: peakKw,
        azimuthDeg: azimuthDeg,
        tiltDeg: tiltDeg,
        inverterId: inverterId,
        lossFactor: lossFactor,
        shadingFactor: shadingFactor,
        temperatureCoefficientPctPerC: temperatureCoefficientPctPerC,
        nominalOperatingCellTempC: nominalOperatingCellTempC,
      );

  static PvArrayDraft fromArray(PvArray a) => PvArrayDraft(
        id: a.id,
        label: a.label,
        peakKw: a.peakKw,
        azimuthDeg: a.azimuthDeg,
        tiltDeg: a.tiltDeg,
        inverterId: a.inverterId,
        lossFactor: a.lossFactor,
        shadingFactor: a.shadingFactor,
        temperatureCoefficientPctPerC: a.temperatureCoefficientPctPerC,
        nominalOperatingCellTempC: a.nominalOperatingCellTempC,
      );
}

class InverterDraft {
  InverterDraft({
    required this.id,
    this.label = '',
    this.maxAcKw = 5.0,
    this.role = InverterRole.grid,
    this.efficiency = 0.965,
    this.maxDcInputKw,
  });

  String id;
  String label;
  double maxAcKw;
  InverterRole role;
  double efficiency;
  double? maxDcInputKw;

  Inverter build() => Inverter(
        id: id, label: label, maxAcKw: maxAcKw, role: role, efficiency: efficiency,
        maxDcInputKw: maxDcInputKw,
      );

  static InverterDraft fromInverter(Inverter i) => InverterDraft(
        id: i.id, label: i.label, maxAcKw: i.maxAcKw, role: i.role, efficiency: i.efficiency,
        maxDcInputKw: i.maxDcInputKw,
      );
}

class BatteryDraft {
  BatteryDraft({
    required this.id,
    this.label = '',
    this.capacityKwh = 5.0,
    this.maxChargeKw = 2.5,
    this.maxDischargeKw = 2.5,
    this.roundTripEfficiency = 0.9,
    this.minSocKwh = 0.0,
    this.initialSocKwh,
  });

  String id;
  String label;
  double capacityKwh;
  double maxChargeKw;
  double maxDischargeKw;
  double roundTripEfficiency;
  double minSocKwh;
  double? initialSocKwh;

  BatteryConfig build() => BatteryConfig(
        id: id,
        label: label,
        capacityKwh: capacityKwh,
        maxChargeKw: maxChargeKw,
        maxDischargeKw: maxDischargeKw,
        roundTripEfficiency: roundTripEfficiency,
        minSocKwh: minSocKwh,
        initialSocKwh: initialSocKwh,
      );

  static BatteryDraft fromBattery(BatteryConfig b) => BatteryDraft(
        id: b.id,
        label: b.label,
        capacityKwh: b.capacityKwh,
        maxChargeKw: b.maxChargeKw,
        maxDischargeKw: b.maxDischargeKw,
        roundTripEfficiency: b.roundTripEfficiency,
        minSocKwh: b.minSocKwh,
        initialSocKwh: b.initialSocKwh,
      );
}

class LoadProfileDraft {
  LoadProfileDraft({this.dailyKwh = 10.0, List<double>? hourlyShape})
      : hourlyShape = hourlyShape ?? List<double>.from(const LoadProfile(dailyKwh: 0).hourlyShape);

  double dailyKwh;
  List<double> hourlyShape;

  LoadProfile build() => LoadProfile(dailyKwh: dailyKwh, hourlyShape: List.unmodifiable(hourlyShape));

  static LoadProfileDraft fromProfile(LoadProfile p) =>
      LoadProfileDraft(dailyKwh: p.dailyKwh, hourlyShape: List<double>.from(p.hourlyShape));
}
