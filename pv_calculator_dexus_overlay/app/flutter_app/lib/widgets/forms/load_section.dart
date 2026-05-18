import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pv_engine/pv_engine.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../persistence/file_io.dart';
import '../../state/project_controller.dart';
import '_field.dart';

class LoadSection extends StatelessWidget {
  const LoadSection({super.key});

  static final _defaultShape = const LoadProfile(dailyKwh: 0).hourlyShape;

  bool _isCustomShape(List<double> shape) {
    if (shape.length != _defaultShape.length) return true;
    for (var i = 0; i < shape.length; i++) {
      if ((shape[i] - _defaultShape[i]).abs() > 1e-9) return true;
    }
    return false;
  }

  Future<void> _importCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = context.read<ProjectController>();
    final l = AppLocalizations.of(context);
    try {
      final profile = await const FileIo().importLoadProfileCsv();
      if (profile == null) return;
      profile.validate();
      controller.draft.loadProfile.dailyKwh = profile.dailyKwh;
      controller.draft.loadProfile.hourlyShape =
          List<double>.from(profile.hourlyShape);
      controller.touch();
      messenger.showSnackBar(SnackBar(
        content: Text(l.loadCsvImportSuccess(
          profile.dailyKwh.toStringAsFixed(2),
        )),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(l.loadCsvImportError(e.toString())),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final load = controller.draft.loadProfile;
    final l = AppLocalizations.of(context);

    var peakHour = 0;
    var peakKwh = load.hourlyShape.isEmpty ? 0.0 : load.hourlyShape[0];
    for (var h = 1; h < load.hourlyShape.length; h++) {
      if (load.hourlyShape[h] > peakKwh) {
        peakKwh = load.hourlyShape[h];
        peakHour = h;
      }
    }
    final isCustom = _isCustomShape(load.hourlyShape);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.loadTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 200, child: NumberField(
              label: l.loadFieldDaily,
              suffix: 'kWh/Tag',
              initialValue: load.dailyKwh,
              min: 0,
              onChanged: (v) {
                if (v != null) { load.dailyKwh = v; controller.touch(); }
              },
            )),
            OutlinedButton.icon(
              key: const Key('load-csv-import'),
              onPressed: () => _importCsv(context),
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(l.loadCsvImportButton),
            ),
          ]),
          const SizedBox(height: 8),
          if (isCustom)
            Text(
              key: const Key('load-hourly-summary'),
              l.loadHourlySummary(peakHour, peakKwh.toStringAsFixed(2)),
              style: const TextStyle(fontSize: 12),
            )
          else
            Text(
              l.loadHourlyHint,
              style: const TextStyle(fontSize: 12),
            ),
        ]),
      ),
    );
  }
}
