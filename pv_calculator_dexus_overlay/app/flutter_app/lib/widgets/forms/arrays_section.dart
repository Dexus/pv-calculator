import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pv_engine/pv_engine.dart';

import '../../config.dart';
import '../../persistence/file_io.dart';
import '../../services/pvgis_api.dart';
import '../../state/config_draft.dart';
import '../../state/project_controller.dart';
import '_field.dart';

class ArraysSection extends StatefulWidget {
  const ArraysSection({super.key, this.fileIo, this.pvgisApi});

  /// Injected for tests. Defaults to the production [FileIo] when null.
  final FileIo? fileIo;

  /// Injected for tests. Defaults to a section-wide production
  /// [PvgisApiService] created lazily on first API click. Sharing one
  /// service across array rows is what makes [PvgisApiService]'s
  /// minimum-interval rate limit actually apply across arrays — a
  /// per-row service would silently fire concurrent requests.
  final PvgisApiService? pvgisApi;

  @override
  State<ArraysSection> createState() => _ArraysSectionState();
}

class _ArraysSectionState extends State<ArraysSection> {
  PvgisApiService? _ownedApi;

  /// Returns the API service this section should hand down to its
  /// rows. When the caller injected one, use it as-is. Otherwise
  /// create a single shared default on first access so the rate
  /// limiter inside [PvgisApiService] serializes requests across rows.
  PvgisApiService _apiService() {
    final injected = widget.pvgisApi;
    if (injected != null) return injected;
    return _ownedApi ??= PvgisApiService(endpoint: pvgisProxyEndpoint);
  }

  @override
  void dispose() {
    _ownedApi?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final draft = controller.draft;
    final inverterIds = draft.inverters.map((i) => i.id).where((id) => id.isNotEmpty).toList();
    final io = widget.fileIo ?? const FileIo();

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
              pvgisApiBuilder: _apiService,
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
    required this.pvgisApiBuilder,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final PvArrayDraft array;
  final List<String> inverterIds;
  final FileIo fileIo;
  final PvgisApiService Function() pvgisApiBuilder;
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
            // attached across every transition, including the common
            // edit flow where the field passes through an empty value
            // (select-all, delete, retype). renameArrayWeather is a
            // no-op when there's no series under [oldId].
            draft.renameArrayWeather(oldId, v);
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
        pvgisApiBuilder: pvgisApiBuilder,
        onChanged: onChanged,
      ),
    ]);
  }
}

class _PvgisRow extends StatefulWidget {
  const _PvgisRow({
    super.key,
    required this.arrayId,
    required this.fileIo,
    required this.pvgisApiBuilder,
    required this.onChanged,
  });

  final String arrayId;
  final FileIo fileIo;

  /// Resolves to the section-wide [PvgisApiService] on demand. Going
  /// through a builder (instead of a value) keeps rows from forcing a
  /// production service to spin up before any user actually taps
  /// fetch.
  final PvgisApiService Function() pvgisApiBuilder;

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
    // The simulator looks up samples by the *exact* PvArray.id string,
    // so the storage key must be identical to widget.arrayId — not a
    // trimmed copy. Trim only for the empty-check.
    if (widget.arrayId.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Bitte zuerst eine Modulfeld-ID vergeben.'),
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      final imported = await widget.fileIo.importPvgisJson();
      // Picker is asynchronous — bail if the user closed the editor
      // before they finished choosing a file.
      if (!mounted) return;
      if (imported == null) return;
      _applyImport(
        controller: controller,
        sourceLabel: imported.sourceLabel,
        data: imported.data,
      );
      widget.onChanged();
      messenger.showSnackBar(SnackBar(
        content: Text('PVGIS-Daten für "${widget.arrayId}" importiert (${imported.data.entries.length} Werte).'),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('PVGIS-Import fehlgeschlagen: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fetchFromApi() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final controller = context.read<ProjectController>();
    final draft = controller.draft;
    if (widget.arrayId.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Bitte zuerst eine Modulfeld-ID vergeben.'),
      ));
      return;
    }
    final array = _findArray(draft, widget.arrayId);
    if (array == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Modulfeld nicht gefunden.'),
      ));
      return;
    }
    final PvgisRequest request;
    try {
      request = _buildRequestFor(draft, array);
    } on ArgumentError catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('PVGIS-Abfrage ungültig: ${e.message ?? e.toString()}'),
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await widget.pvgisApiBuilder().fetch(request);
      if (!mounted) return;
      _applyImport(
        controller: controller,
        sourceLabel:
            'PVGIS-API ${request.startYear}–${request.endYear}',
        data: data,
      );
      widget.onChanged();
      messenger.showSnackBar(SnackBar(
        content: Text(
          'PVGIS-API-Daten für "${widget.arrayId}" geladen (${data.entries.length} Werte).',
        ),
      ));
    } on PvgisApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('PVGIS-API-Abfrage fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyImport({
    required ProjectController controller,
    required String sourceLabel,
    required PvgisHourlyData data,
  }) {
    final samples = data.toAveragedYear();
    final years = (data.entries.map((e) => e.timestampUtc.year).toSet().toList()
      ..sort());
    controller.draft.setArrayWeather(
      widget.arrayId,
      samples,
      PvgisImportInfo(
        sourceLabel: sourceLabel,
        entryCount: data.entries.length,
        coveredYears: List<int>.unmodifiable(years),
        latitudeDeg: data.latitudeDeg,
        longitudeDeg: data.longitudeDeg,
        slopeDeg: data.slopeDeg,
        appAzimuthDeg: data.appAzimuthDeg,
      ),
    );
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
    final mismatch = hasData ? _orientationMismatch(info, draft, widget.arrayId) : null;

    final status = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(
        hasData ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
        color: hasData ? scheme.primary : scheme.outline,
      ),
      const SizedBox(width: 10),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasData ? 'PVGIS-Daten geladen' : 'Wetterquelle: synthetisches Demo-Modell',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (hasData) ...[
              const SizedBox(height: 2),
              Text(
                '${info.sourceLabel} · ${info.entryCount} Stunden · '
                'Jahre ${info.coveredYears.isEmpty ? "?" : info.coveredYears.join(", ")} · '
                'PVGIS-Lage ${info.latitudeDeg.toStringAsFixed(3)}°/${info.longitudeDeg.toStringAsFixed(3)}°'
                '${_orientationSuffix(info)}',
                style: Theme.of(context).textTheme.bodySmall,
                softWrap: true,
              ),
              if (mismatch != null) ...[
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: scheme.error),
                  const SizedBox(width: 4),
                  Flexible(child: Text(
                    mismatch,
                    key: Key('pvgis-orientation-warning-${widget.arrayId}'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.error),
                    softWrap: true,
                  )),
                ]),
              ],
              const SizedBox(height: 4),
              Text(
                'Hinweis: PVGIS-Importe gelten nur für diese Sitzung — sie werden nicht im Projekt-JSON gespeichert.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                softWrap: true,
              ),
            ],
          ],
        ),
      ),
    ]);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      // Wrap lets the action buttons drop below the status block on
      // narrow editor widths instead of overflowing the row.
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          status,
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (hasData)
              TextButton.icon(
                key: Key('pvgis-remove-${widget.arrayId}'),
                onPressed: _busy ? null : _remove,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Entfernen'),
              ),
            FilledButton.icon(
              key: Key('pvgis-fetch-api-${widget.arrayId}'),
              onPressed: _busy ? null : _fetchFromApi,
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_download_outlined, size: 18),
              label: Text(hasData ? 'API neu laden' : 'Von PVGIS-API laden'),
            ),
            FilledButton.tonalIcon(
              key: Key('pvgis-import-${widget.arrayId}'),
              onPressed: _busy ? null : _import,
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('JSON importieren'),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Tilt/azimuth fragment appended to the metadata line. Empty when
/// neither was carried in the PVGIS document.
String _orientationSuffix(PvgisImportInfo info) {
  final tilt = info.slopeDeg;
  final az = info.appAzimuthDeg;
  if (tilt == null && az == null) return '';
  final parts = <String>[];
  if (tilt != null) parts.add('Neigung ${tilt.toStringAsFixed(0)}°');
  if (az != null) parts.add('Azimut ${az.toStringAsFixed(0)}°');
  return ' · ${parts.join(", ")}';
}

/// Returns a warning string when the PVGIS request orientation drifts
/// far enough from the array's configured orientation to materially
/// change yield (5° tilt or 15° azimuth). `null` when the PVGIS file
/// carries no mounting metadata or both values are within tolerance.
String? _orientationMismatch(PvgisImportInfo info, ConfigDraft draft, String arrayId) {
  final array = _findArray(draft, arrayId);
  if (array == null) return null;
  final tiltDelta = info.slopeDeg == null ? null : (info.slopeDeg! - array.tiltDeg).abs();
  final az = info.appAzimuthDeg;
  final azDelta = az == null ? null : _azimuthDelta(az, array.azimuthDeg);
  final issues = <String>[];
  if (tiltDelta != null && tiltDelta > 5) {
    issues.add('Neigung ${info.slopeDeg!.toStringAsFixed(0)}° vs ${array.tiltDeg.toStringAsFixed(0)}°');
  }
  if (azDelta != null && azDelta > 15) {
    issues.add('Azimut ${az!.toStringAsFixed(0)}° vs ${array.azimuthDeg.toStringAsFixed(0)}°');
  }
  if (issues.isEmpty) return null;
  return 'PVGIS-Ausrichtung weicht ab (${issues.join("; ")}). '
      'Die importierten POA-Werte gelten für die PVGIS-Ausrichtung, '
      'nicht für die hier eingestellte.';
}

PvArrayDraft? _findArray(ConfigDraft draft, String id) {
  for (final a in draft.arrays) {
    if (a.id == id) return a;
  }
  return null;
}

/// Builds a [PvgisRequest] for one array using the draft's site
/// coordinates and PVGIS-window settings plus the array's own
/// orientation/loss/peak fields.
PvgisRequest _buildRequestFor(ConfigDraft draft, PvArrayDraft array) {
  return PvgisRequest(
    latitudeDeg: draft.latitudeDeg,
    longitudeDeg: draft.longitudeDeg,
    peakKw: array.peakKw,
    tiltDeg: array.tiltDeg,
    appAzimuthDeg: array.azimuthDeg,
    lossFactor: array.lossFactor,
    startYear: draft.pvgisStartYear,
    endYear: draft.pvgisEndYear,
    radDatabase: draft.pvgisRadDatabase,
  );
}

/// Shortest absolute distance between two azimuths on the 0–360° circle.
double _azimuthDelta(double a, double b) {
  final diff = (a - b).abs() % 360.0;
  return diff > 180.0 ? 360.0 - diff : diff;
}
