import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pv_engine/pv_engine.dart';

import '../../services/geocoding.dart';
import '../../state/project_controller.dart';
import '_field.dart';

class ProjectSection extends StatelessWidget {
  const ProjectSection({super.key, this.geocoder});

  /// Injected for tests. In production this is constructed lazily by the
  /// address-search row so we don't open an `http.Client` until the user
  /// actually triggers a lookup.
  final GeocodingService? geocoder;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final draft = controller.draft;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Projekt', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          StringField(
            label: 'Projektname',
            initialValue: controller.projectName,
            required: true,
            onChanged: (v) => controller.projectName = v,
          ),
          const SizedBox(height: 12),
          _AddressSearchRow(geocoder: geocoder),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 160, child: NumberField(
              key: const Key('latitude-field'),
              label: 'Breitengrad',
              suffix: '°',
              initialValue: draft.latitudeDeg,
              min: -90, max: 90,
              onChanged: (v) {
                if (v != null) { draft.latitudeDeg = v; controller.touch(); }
              },
            )),
            SizedBox(width: 160, child: NumberField(
              key: const Key('longitude-field'),
              label: 'Längengrad',
              suffix: '°',
              initialValue: draft.longitudeDeg,
              min: -180, max: 180,
              onChanged: (v) {
                if (v != null) { draft.longitudeDeg = v; controller.touch(); }
              },
            )),
            SizedBox(width: 160, child: IntField(
              label: 'Start-Tag im Jahr',
              initialValue: draft.startDayOfYear,
              min: 1, max: 365,
              onChanged: (v) { draft.startDayOfYear = v; controller.touch(); },
            )),
            SizedBox(width: 160, child: IntField(
              label: 'Simulationstage',
              initialValue: draft.days,
              min: 1, max: 365,
              onChanged: (v) { draft.days = v; controller.touch(); },
            )),
            SizedBox(width: 160, child: IntField(
              label: 'Vorlauf-Tage',
              initialValue: draft.preRunDays,
              min: 0, max: 365,
              onChanged: (v) { draft.preRunDays = v; controller.touch(); },
            )),
            SizedBox(width: 200, child: NumberField(
              label: 'Einspeise-Limit',
              suffix: 'kW',
              initialValue: draft.gridExportLimitKw,
              allowNull: true,
              min: 0,
              onChanged: (v) { draft.gridExportLimitKw = v; controller.touch(); },
            )),
            SizedBox(width: 220, child: DropdownButtonFormField<TimeStep>(
              isExpanded: true,
              initialValue: draft.timeStep,
              decoration: const InputDecoration(labelText: 'Zeitschritt', isDense: true),
              items: const [
                DropdownMenuItem(value: TimeStep.hourly, child: Text('Stündlich', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: TimeStep.quarterHourly, child: Text('Viertelstündlich', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) {
                if (v != null) { draft.timeStep = v; controller.touch(); }
              },
            )),
          ]),
        ]),
      ),
    );
  }
}

class _AddressSearchRow extends StatefulWidget {
  const _AddressSearchRow({this.geocoder});

  final GeocodingService? geocoder;

  @override
  State<_AddressSearchRow> createState() => _AddressSearchRowState();
}

class _AddressSearchRowState extends State<_AddressSearchRow> {
  late final TextEditingController _queryController;
  late GeocodingService _geocoder;
  bool _ownsGeocoder = false;
  bool _busy = false;
  String? _error;
  List<GeocodeResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    if (widget.geocoder != null) {
      _geocoder = widget.geocoder!;
    } else {
      _geocoder = NominatimGeocoder();
      _ownsGeocoder = true;
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    if (_ownsGeocoder && _geocoder is NominatimGeocoder) {
      (_geocoder as NominatimGeocoder).dispose();
    }
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _results = const [];
    });
    try {
      final results = await _geocoder.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) _error = 'Keine Treffer gefunden.';
      });
    } on GeocodingException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _apply(GeocodeResult result) {
    final controller = context.read<ProjectController>();
    controller.draft.latitudeDeg = double.parse(result.latitudeDeg.toStringAsFixed(5));
    controller.draft.longitudeDeg = double.parse(result.longitudeDeg.toStringAsFixed(5));
    controller.touch();
    setState(() {
      _results = const [];
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: TextField(
          key: const Key('address-search-field'),
          controller: _queryController,
          decoration: const InputDecoration(
            labelText: 'Adresse suchen (OpenStreetMap)',
            hintText: 'z.B. Marktplatz 1, Frankfurt',
            isDense: true,
          ),
          onSubmitted: (_) => _search(),
        )),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          key: const Key('address-search-button'),
          onPressed: _busy ? null : _search,
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search),
          label: const Text('Suchen'),
        ),
      ]),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      if (_results.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final r in _results)
              ListTile(
                dense: true,
                key: Key('geocode-result-${r.latitudeDeg}-${r.longitudeDeg}'),
                title: Text(r.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${r.latitudeDeg.toStringAsFixed(5)}°, ${r.longitudeDeg.toStringAsFixed(5)}°',
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => _apply(r),
              ),
          ]),
        ),
    ]);
  }
}
