import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/config_draft.dart';
import 'forms/_field.dart';

/// Outcome of [showQuickStartWizard]. Holds the chosen project name and
/// the populated draft so the caller can hand them to its repository in
/// the same way as the legacy "+ Neues Projekt" path used to.
class QuickStartResult {
  const QuickStartResult({required this.projectName, required this.draft});

  final String projectName;
  final ConfigDraft draft;
}

/// Signature used by [ProjectsTab] to launch the wizard. Production code
/// uses [showQuickStartWizard]; widget tests substitute a stub that
/// returns a canned [QuickStartResult] without pumping the dialog.
typedef QuickStartWizardLauncher = Future<QuickStartResult?> Function(
    BuildContext context);

/// Opens the modal Stepper that walks a new user through site →
/// PV array → optional battery → daily load → summary. Returns `null`
/// when the user cancels (no project is created); a populated
/// [QuickStartResult] when they hit "Projekt anlegen".
Future<QuickStartResult?> showQuickStartWizard(BuildContext context) {
  return showDialog<QuickStartResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Dialog.fullscreen(child: _QuickStartWizard()),
  );
}

class _QuickStartWizard extends StatefulWidget {
  const _QuickStartWizard();

  @override
  State<_QuickStartWizard> createState() => _QuickStartWizardState();
}

class _QuickStartWizardState extends State<_QuickStartWizard> {
  int _currentStep = 0;

  // Step 1 — site
  String _projectName = '';
  double _latitudeDeg = 50.1;
  double _longitudeDeg = 8.6;

  // Step 2 — array
  double _peakKw = 4.8;
  double _azimuthDeg = 180;
  double _tiltDeg = 35;

  // Step 3 — battery
  bool _addBattery = true;
  double _batteryCapacityKwh = 7.5;
  double _batteryChargeKw = 3.0;
  double _batteryDischargeKw = 3.0;

  // Step 4 — load
  double _dailyKwh = 10.5;

  /// Whether the user can advance past [_currentStep]. The wizard
  /// gates `Weiter` on the same rules the engine would later enforce
  /// in `SimulationConfig.validate()`, so the user never reaches the
  /// summary with an invalid draft.
  bool _canContinue() {
    switch (_currentStep) {
      case 0:
        return _projectName.trim().isNotEmpty &&
            _latitudeDeg.abs() <= 90 &&
            _longitudeDeg.abs() <= 180;
      case 1:
        return _peakKw > 0 &&
            _azimuthDeg >= 0 &&
            _azimuthDeg <= 360 &&
            _tiltDeg >= 0 &&
            _tiltDeg <= 90;
      case 2:
        if (!_addBattery) return true;
        return _batteryCapacityKwh > 0 &&
            _batteryChargeKw > 0 &&
            _batteryDischargeKw > 0;
      case 3:
        return _dailyKwh >= 0;
      case 4:
        return true;
      default:
        return false;
    }
  }

  void _onContinue() {
    if (!_canContinue()) return;
    if (_currentStep == 4) {
      _finish();
      return;
    }
    setState(() => _currentStep += 1);
  }

  void _onCancelStep() {
    if (_currentStep == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _currentStep -= 1);
  }

  void _finish() {
    final draft = ConfigDraft(
      arrays: [
        PvArrayDraft(
          id: 'array-1',
          label: '',
          peakKw: _peakKw,
          azimuthDeg: _azimuthDeg,
          tiltDeg: _tiltDeg,
          inverterId: 'main',
        ),
      ],
      inverters: [
        InverterDraft(id: 'main', label: '', maxAcKw: _peakKw.clamp(0.4, 30.0)),
      ],
      batteries: _addBattery
          ? [
              BatteryDraft(
                id: 'main',
                label: '',
                capacityKwh: _batteryCapacityKwh,
                maxChargeKw: _batteryChargeKw,
                maxDischargeKw: _batteryDischargeKw,
                minSocKwh: 0.5,
              ),
            ]
          : <BatteryDraft>[],
      loadProfile: LoadProfileDraft(dailyKwh: _dailyKwh),
      latitudeDeg: _latitudeDeg,
      longitudeDeg: _longitudeDeg,
      days: 365,
      preRunDays: 365,
      gridExportLimitKw: 6.0,
    );
    Navigator.of(context).pop(
      QuickStartResult(projectName: _projectName.trim(), draft: draft),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.wizardTitle),
        leading: IconButton(
          key: const Key('wizard-close'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: _canContinue() ? _onContinue : null,
        onStepCancel: _onCancelStep,
        controlsBuilder: (context, details) {
          final stepIndex = details.stepIndex;
          final isLast = stepIndex == 4;
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(children: [
              FilledButton(
                key: Key('wizard-continue-$stepIndex'),
                onPressed: details.onStepContinue,
                child: Text(isLast ? l.wizardFinish : l.wizardContinue),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: Key('wizard-back-$stepIndex'),
                onPressed: details.onStepCancel,
                child: Text(stepIndex == 0 ? l.wizardCancel : l.wizardBack),
              ),
            ]),
          );
        },
        steps: [
          Step(
            title: Text(l.wizardStepSite),
            isActive: _currentStep >= 0,
            content: _SiteStep(
              initialName: _projectName,
              initialLat: _latitudeDeg,
              initialLon: _longitudeDeg,
              onChanged: (name, lat, lon) => setState(() {
                _projectName = name;
                _latitudeDeg = lat;
                _longitudeDeg = lon;
              }),
            ),
          ),
          Step(
            title: Text(l.wizardStepArray),
            isActive: _currentStep >= 1,
            content: _ArrayStep(
              initialPeak: _peakKw,
              initialAzimuth: _azimuthDeg,
              initialTilt: _tiltDeg,
              onChanged: (peak, az, tilt) => setState(() {
                _peakKw = peak;
                _azimuthDeg = az;
                _tiltDeg = tilt;
              }),
            ),
          ),
          Step(
            title: Text(l.wizardStepBattery),
            isActive: _currentStep >= 2,
            content: _BatteryStep(
              addBattery: _addBattery,
              capacity: _batteryCapacityKwh,
              chargeKw: _batteryChargeKw,
              dischargeKw: _batteryDischargeKw,
              onChanged: (add, cap, ch, dis) => setState(() {
                _addBattery = add;
                _batteryCapacityKwh = cap;
                _batteryChargeKw = ch;
                _batteryDischargeKw = dis;
              }),
            ),
          ),
          Step(
            title: Text(l.wizardStepLoad),
            isActive: _currentStep >= 3,
            content: _LoadStep(
              initial: _dailyKwh,
              onChanged: (v) => setState(() => _dailyKwh = v),
            ),
          ),
          Step(
            title: Text(l.wizardStepSummary),
            isActive: _currentStep >= 4,
            content: _SummaryStep(
              projectName: _projectName,
              latitudeDeg: _latitudeDeg,
              longitudeDeg: _longitudeDeg,
              peakKw: _peakKw,
              azimuthDeg: _azimuthDeg,
              tiltDeg: _tiltDeg,
              addBattery: _addBattery,
              batteryCapacityKwh: _batteryCapacityKwh,
              batteryChargeKw: _batteryChargeKw,
              batteryDischargeKw: _batteryDischargeKw,
              dailyKwh: _dailyKwh,
            ),
          ),
        ],
      ),
    );
  }
}

class _SiteStep extends StatelessWidget {
  const _SiteStep({
    required this.initialName,
    required this.initialLat,
    required this.initialLon,
    required this.onChanged,
  });

  final String initialName;
  final double initialLat;
  final double initialLon;
  final void Function(String name, double lat, double lon) onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextFormField(
        key: const Key('wizard-name'),
        initialValue: initialName,
        decoration: InputDecoration(labelText: l.wizardProjectName, isDense: true),
        onChanged: (v) => onChanged(v, initialLat, initialLon),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: NumberField(
            key: const Key('wizard-latitude'),
            label: l.wizardLatitude,
            initialValue: initialLat,
            min: -90, max: 90,
            onChanged: (v) {
              if (v != null) onChanged(initialName, v, initialLon);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: NumberField(
            key: const Key('wizard-longitude'),
            label: l.wizardLongitude,
            initialValue: initialLon,
            min: -180, max: 180,
            onChanged: (v) {
              if (v != null) onChanged(initialName, initialLat, v);
            },
          ),
        ),
      ]),
    ]);
  }
}

class _ArrayStep extends StatelessWidget {
  const _ArrayStep({
    required this.initialPeak,
    required this.initialAzimuth,
    required this.initialTilt,
    required this.onChanged,
  });

  final double initialPeak;
  final double initialAzimuth;
  final double initialTilt;
  final void Function(double peak, double azimuth, double tilt) onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      NumberField(
        key: const Key('wizard-array-peak'),
        label: l.wizardArrayPeak,
        suffix: 'kWp',
        initialValue: initialPeak,
        min: 0.1, max: 100,
        onChanged: (v) {
          if (v != null) onChanged(v, initialAzimuth, initialTilt);
        },
      ),
      const SizedBox(height: 12),
      NumberField(
        key: const Key('wizard-array-azimuth'),
        label: l.wizardArrayAzimuth,
        suffix: '°',
        initialValue: initialAzimuth,
        min: 0, max: 360,
        onChanged: (v) {
          if (v != null) onChanged(initialPeak, v, initialTilt);
        },
      ),
      const SizedBox(height: 12),
      NumberField(
        key: const Key('wizard-array-tilt'),
        label: l.wizardArrayTilt,
        suffix: '°',
        initialValue: initialTilt,
        min: 0, max: 90,
        onChanged: (v) {
          if (v != null) onChanged(initialPeak, initialAzimuth, v);
        },
      ),
    ]);
  }
}

class _BatteryStep extends StatelessWidget {
  const _BatteryStep({
    required this.addBattery,
    required this.capacity,
    required this.chargeKw,
    required this.dischargeKw,
    required this.onChanged,
  });

  final bool addBattery;
  final double capacity;
  final double chargeKw;
  final double dischargeKw;
  final void Function(bool add, double cap, double charge, double discharge)
      onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        key: const Key('wizard-add-battery'),
        contentPadding: EdgeInsets.zero,
        title: Text(l.wizardAddBattery),
        value: addBattery,
        onChanged: (v) => onChanged(v, capacity, chargeKw, dischargeKw),
      ),
      if (addBattery) ...[
        const SizedBox(height: 8),
        NumberField(
          key: const Key('wizard-battery-capacity'),
          label: l.wizardBatteryCapacity,
          suffix: 'kWh',
          initialValue: capacity,
          min: 0.1, max: 200,
          onChanged: (v) {
            if (v != null) onChanged(addBattery, v, chargeKw, dischargeKw);
          },
        ),
        const SizedBox(height: 12),
        NumberField(
          key: const Key('wizard-battery-charge'),
          label: l.wizardBatteryChargeRate,
          suffix: 'kW',
          initialValue: chargeKw,
          min: 0.1, max: 50,
          onChanged: (v) {
            if (v != null) onChanged(addBattery, capacity, v, dischargeKw);
          },
        ),
        const SizedBox(height: 12),
        NumberField(
          key: const Key('wizard-battery-discharge'),
          label: l.wizardBatteryDischargeRate,
          suffix: 'kW',
          initialValue: dischargeKw,
          min: 0.1, max: 50,
          onChanged: (v) {
            if (v != null) onChanged(addBattery, capacity, chargeKw, v);
          },
        ),
      ],
    ]);
  }
}

class _LoadStep extends StatelessWidget {
  const _LoadStep({required this.initial, required this.onChanged});

  final double initial;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return NumberField(
      key: const Key('wizard-load-daily'),
      label: l.wizardLoadDaily,
      suffix: 'kWh/d',
      initialValue: initial,
      min: 0, max: 200,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _SummaryStep extends StatelessWidget {
  const _SummaryStep({
    required this.projectName,
    required this.latitudeDeg,
    required this.longitudeDeg,
    required this.peakKw,
    required this.azimuthDeg,
    required this.tiltDeg,
    required this.addBattery,
    required this.batteryCapacityKwh,
    required this.batteryChargeKw,
    required this.batteryDischargeKw,
    required this.dailyKwh,
  });

  final String projectName;
  final double latitudeDeg;
  final double longitudeDeg;
  final double peakKw;
  final double azimuthDeg;
  final double tiltDeg;
  final bool addBattery;
  final double batteryCapacityKwh;
  final double batteryChargeKw;
  final double batteryDischargeKw;
  final double dailyKwh;

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.wizardSummaryIntro,
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      Text('${l.wizardSummaryName}: $projectName', style: style),
      Text(
        '${l.wizardSummarySite}: ${_fmt(latitudeDeg)}°, ${_fmt(longitudeDeg)}°',
        style: style,
      ),
      Text(
        l.wizardSummaryArray(
            _fmt(peakKw), _fmt(azimuthDeg), _fmt(tiltDeg)),
        style: style,
      ),
      Text(
        addBattery
            ? l.wizardSummaryBattery(_fmt(batteryCapacityKwh),
                _fmt(batteryChargeKw), _fmt(batteryDischargeKw))
            : l.wizardSummaryBatteryNone,
        style: style,
      ),
      Text(l.wizardSummaryLoad(_fmt(dailyKwh)), style: style),
    ]);
  }
}
