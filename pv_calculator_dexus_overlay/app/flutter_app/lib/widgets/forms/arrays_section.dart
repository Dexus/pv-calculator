import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../persistence/file_io.dart';
import '../../state/config_draft.dart';
import '../../state/project_controller.dart';
import '_field.dart';

class ArraysSection extends StatelessWidget {
  const ArraysSection({super.key, this.fileIo});

  /// Injected for tests. Defaults to the production [FileIo] when null.
  final FileIo? fileIo;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final draft = controller.draft;
    final inverterIds = draft.inverters.map((i) => i.id).where((id) => id.isNotEmpty).toList();
    final io = fileIo ?? const FileIo();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('PV-Module', style: Theme.of(context).textTheme.titleMedium)),
            FilledButton.tonalIcon(
              onPressed: () {
                final n = draft.arrays.length + 1;
                draft.arrays.add(PvArrayDraft(
                  id: 'array-$n',
                  label: 'Modulfeld $n',
                  inverterId: inverterIds.isNotEmpty ? inverterIds.first : '',
                ));
                controller.touch();
              },
              icon: const Icon(Icons.add),
              label: const Text('Hinzufügen'),
            ),
          ]),
          if (draft.arrays.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Mindestens ein Modulfeld ist erforderlich.'),
            ),
          for (var i = 0; i < draft.arrays.length; i++) ...[
            const Divider(height: 24),
            _ArrayEditor(
              key: ValueKey('array-${draft.arrays[i].id}-$i'),
              index: i,
              array: draft.arrays[i],
              inverterIds: inverterIds,
              fileIo: io,
              onChanged: controller.touch,
              onRemove: () {
                draft.clearArrayWeather(draft.arrays[i].id);
                draft.arrays.removeAt(i);
                controller.touch();
              },
            ),
          ],
        ]),
      ),
    );
  }
}

class _ArrayEditor extends StatelessWidget {
  const _ArrayEditor({
    super.key,
    required this.index,
    required this.array,
    required this.inverterIds,
    required this.fileIo,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final PvArrayDraft array;
  final List<String> inverterIds;
  final FileIo fileIo;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Modulfeld ${index + 1}', style: Theme.of(context).textTheme.titleSmall)),
        IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline), tooltip: 'Entfernen'),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 180, child: StringField(
          label: 'ID', initialValue: array.id, required: true,
          onChanged: (v) {
            final draft = context.read<ProjectController>().draft;
            final oldId = array.id;
            array.id = v;
            // PVGIS series are keyed by array id — keep the import
            // attached when the user renames an array.
            if (oldId.isNotEmpty) {
              draft.renameArrayWeather(oldId, v);
            }
            onChanged();
          },
        )),
        SizedBox(width: 220, child: StringField(
          label: 'Bezeichnung', initialValue: array.label,
          onChanged: (v) { array.label = v; onChanged(); },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Spitzenleistung', suffix: 'kWp', initialValue: array.peakKw, min: 0.001,
          onChanged: (v) { if (v != null) { array.peakKw = v; onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Azimut', suffix: '°', initialValue: array.azimuthDeg, min: 0, max: 360,
          onChanged: (v) { if (v != null) { array.azimuthDeg = v; onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Neigung', suffix: '°', initialValue: array.tiltDeg, min: 0, max: 90,
          onChanged: (v) { if (v != null) { array.tiltDeg = v; onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Verluste', suffix: '0..1', initialValue: array.lossFactor, min: 0, max: 0.999,
          onChanged: (v) { if (v != null) { array.lossFactor = v; onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Verschattung', suffix: '0..1', initialValue: array.shadingFactor, min: 0, max: 0.999,
          onChanged: (v) { if (v != null) { array.shadingFactor = v; onChanged(); } },
        )),
        SizedBox(width: 200, child: NumberField(
          label: 'Temperaturkoeff.', suffix: '%/°C',
          initialValue: array.temperatureCoefficientPctPerC, min: -2, max: 0,
          onChanged: (v) { if (v != null) { array.temperatureCoefficientPctPerC = v; onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'NOCT', suffix: '°C',
          initialValue: array.nominalOperatingCellTempC, min: 20, max: 70,
          onChanged: (v) { if (v != null) { array.nominalOperatingCellTempC = v; onChanged(); } },
        )),
        SizedBox(width: 220, child: DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: inverterIds.contains(array.inverterId) ? array.inverterId : null,
          decoration: const InputDecoration(labelText: 'Wechselrichter', isDense: true),
          items: [
            for (final id in inverterIds)
              DropdownMenuItem(value: id, child: Text(id, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) { if (v != null) { array.inverterId = v; onChanged(); } },
          validator: (v) => (v == null || v.isEmpty) ? 'Wechselrichter auswählen' : null,
        )),
      ]),
      const SizedBox(height: 12),
      _PvgisRow(
        key: Key('pvgis-row-${array.id}'),
        arrayId: array.id,
        fileIo: fileIo,
        onChanged: onChanged,
      ),
    ]);
  }
}

class _PvgisRow extends StatefulWidget {
  const _PvgisRow({super.key, required this.arrayId, required this.fileIo, required this.onChanged});

  final String arrayId;
  final FileIo fileIo;
  final VoidCallback onChanged;

  @override
  State<_PvgisRow> createState() => _PvgisRowState();
}

class _PvgisRowState extends State<_PvgisRow> {
  bool _busy = false;

  Future<void> _import() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final controller = context.read<ProjectController>();
    final id = widget.arrayId.trim();
    if (id.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Bitte zuerst eine Modulfeld-ID vergeben.'),
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      final imported = await widget.fileIo.importPvgisJson();
      if (imported == null) return;
      final samples = imported.data.toAveragedYear();
      final years = (imported.data.entries.map((e) => e.timestampUtc.year).toSet().toList()..sort());
      controller.draft.setArrayWeather(
        id,
        samples,
        PvgisImportInfo(
          sourceLabel: imported.sourceLabel,
          entryCount: imported.data.entries.length,
          coveredYears: List<int>.unmodifiable(years),
          latitudeDeg: imported.data.latitudeDeg,
          longitudeDeg: imported.data.longitudeDeg,
        ),
      );
      widget.onChanged();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('PVGIS-Daten für "$id" importiert (${imported.data.entries.length} Werte).'),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('PVGIS-Import fehlgeschlagen: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove() {
    final controller = context.read<ProjectController>();
    controller.draft.clearArrayWeather(widget.arrayId);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<ProjectController>().draft;
    final info = draft.weatherInfoFor(widget.arrayId);
    final hasData = info != null;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Icon(
          hasData ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
          color: hasData ? scheme.primary : scheme.outline,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              hasData ? 'PVGIS-Daten geladen' : 'Wetterquelle: synthetisches Demo-Modell',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (hasData) ...[
              const SizedBox(height: 2),
              Text(
                '${info.sourceLabel} · ${info.entryCount} Stunden · '
                'Jahre ${info.coveredYears.isEmpty ? "?" : info.coveredYears.join(", ")} · '
                'PVGIS-Lage ${info.latitudeDeg.toStringAsFixed(3)}°/${info.longitudeDeg.toStringAsFixed(3)}°',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ]),
        ),
        const SizedBox(width: 12),
        if (hasData)
          TextButton.icon(
            key: Key('pvgis-remove-${widget.arrayId}'),
            onPressed: _busy ? null : _remove,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Entfernen'),
          ),
        const SizedBox(width: 4),
        FilledButton.tonalIcon(
          key: Key('pvgis-import-${widget.arrayId}'),
          onPressed: _busy ? null : _import,
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.file_upload_outlined, size: 18),
          label: Text(hasData ? 'Ersetzen' : 'PVGIS-JSON importieren'),
        ),
      ]),
    );
  }
}
