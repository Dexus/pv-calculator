import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/geocoding.dart';
import '../state/config_draft.dart';
import '../state/project_controller.dart';
import '../widgets/azimuth_compass.dart';
import '../widgets/irradiance_chart.dart';

/// Einstrahlung tab — site picker (map + Nominatim search) + year picker +
/// "Lade Daten" button + annual horizontal-irradiance chart.
///
/// One PVGIS call per (lat, lon, year). The compass overlay in the
/// bottom-right writes azimuth back to whichever array is selected on
/// the PV-Arrays tab; it's hidden until an array is selected.
class IrradianceTab extends StatefulWidget {
  const IrradianceTab({super.key, this.geocoder});

  /// Injection point for tests; production uses [NominatimGeocoder]
  /// lazily on first search.
  final GeocodingService? geocoder;

  @override
  State<IrradianceTab> createState() => _IrradianceTabState();
}

class _IrradianceTabState extends State<IrradianceTab> {
  late final MapController _mapController;
  GeocodingService? _geocoder;
  bool _ownsGeocoder = false;
  final TextEditingController _searchController = TextEditingController();
  bool _searchBusy = false;
  String? _searchError;
  List<GeocodeResult> _searchResults = const [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.geocoder != null) {
      _geocoder = widget.geocoder;
    }
  }

  GeocodingService _ensureGeocoder() {
    final existing = _geocoder;
    if (existing != null) return existing;
    final fresh = NominatimGeocoder();
    _geocoder = fresh;
    _ownsGeocoder = true;
    return fresh;
  }

  @override
  void dispose() {
    _searchController.dispose();
    final g = _geocoder;
    if (_ownsGeocoder && g is NominatimGeocoder) {
      g.dispose();
    }
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _searchBusy) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _searchBusy = true;
      _searchError = null;
      _searchResults = const [];
    });
    try {
      final results = await _ensureGeocoder().search(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        if (results.isEmpty) _searchError = l.projectAddressNoResults;
      });
    } on GeocodingException catch (e) {
      if (!mounted) return;
      setState(() => _searchError = formatGeocodingException(l, e));
    } finally {
      if (mounted) setState(() => _searchBusy = false);
    }
  }

  void _applyResult(GeocodeResult result) {
    final controller = context.read<ProjectController>();
    final lat = double.parse(result.latitudeDeg.toStringAsFixed(5));
    final lon = double.parse(result.longitudeDeg.toStringAsFixed(5));
    controller.draft.latitudeDeg = lat;
    controller.draft.longitudeDeg = lon;
    // Loaded samples are no longer correct for the new location.
    controller.draft.siteIrradiance.samples = null;
    controller.draft.siteIrradiance.loadedFromCache = null;
    // A previous load error belongs to the old location; clear it so the
    // error card doesn't linger after the user picks a different site.
    controller.clearIrradianceError();
    controller.touch();
    _mapController.move(LatLng(lat, lon), _mapController.camera.zoom);
    setState(() {
      _searchResults = const [];
      _searchError = null;
    });
  }

  void _onMapTap(LatLng point) {
    final controller = context.read<ProjectController>();
    controller.draft.latitudeDeg = double.parse(point.latitude.toStringAsFixed(5));
    controller.draft.longitudeDeg = double.parse(point.longitude.toStringAsFixed(5));
    controller.draft.siteIrradiance.samples = null;
    controller.draft.siteIrradiance.loadedFromCache = null;
    controller.clearIrradianceError();
    controller.touch();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = context.watch<ProjectController>();
    final draft = controller.draft;
    final pin = LatLng(draft.latitudeDeg, draft.longitudeDeg);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchBar(
            controller: _searchController,
            onSubmit: _search,
            busy: _searchBusy,
            error: _searchError,
            results: _searchResults,
            onResultTap: _applyResult,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 360,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: pin,
                      initialZoom: 16,
                      // Disable map rotation so the compass overlay's
                      // tick angles never get ambiguous.
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onTap: (_, point) => _onMapTap(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        // Required by the OSM tile usage policy. Sent
                        // as a real User-Agent on native platforms; the
                        // browser strips it on web, but the package
                        // also uses it as the Referer where possible.
                        userAgentPackageName: 'de.dexus.pvcalc',
                      ),
                      // OSM tile usage policy requires visible attribution.
                      const SimpleAttributionWidget(
                        source: Text('© OpenStreetMap contributors'),
                      ),
                      MarkerLayer(markers: [
                        Marker(
                          point: pin,
                          width: 36,
                          height: 36,
                          alignment: Alignment.topCenter,
                          child: Icon(
                            Icons.location_pin,
                            size: 36,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ]),
                    ],
                  ),
                  if (controller.selectedArrayIndex != null)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: AzimuthCompass(
                        azimuthDeg: draft.arrays[controller.selectedArrayIndex!].azimuthDeg,
                        onChanged: controller.setSelectedArrayAzimuth,
                      ),
                    ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${draft.latitudeDeg.toStringAsFixed(3)}°, '
                        '${draft.longitudeDeg.toStringAsFixed(3)}°',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.irradianceMapHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _LoadRow(),
          const SizedBox(height: 16),
          _ChartArea(),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onSubmit,
    required this.busy,
    required this.error,
    required this.results,
    required this.onResultTap,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool busy;
  final String? error;
  final List<GeocodeResult> results;
  final ValueChanged<GeocodeResult> onResultTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('irradiance-search-field'),
              controller: controller,
              decoration: InputDecoration(
                labelText: l.projectAddressSearch,
                hintText: l.projectAddressHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            key: const Key('irradiance-search-button'),
            onPressed: busy ? null : onSubmit,
            icon: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search),
            label: Text(l.commonSearch),
          ),
        ]),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in results)
                  ListTile(
                    dense: true,
                    key: Key('irradiance-result-${r.latitudeDeg}-${r.longitudeDeg}'),
                    title: Text(r.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${r.latitudeDeg.toStringAsFixed(5)}°, ${r.longitudeDeg.toStringAsFixed(5)}°',
                    ),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => onResultTap(r),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LoadRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = context.watch<ProjectController>();
    final site = controller.draft.siteIrradiance;
    final yearOptions = [for (var y = 2023; y >= 2005; y--) y];
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int>(
            key: const Key('irradiance-year-field'),
            initialValue: yearOptions.contains(site.year) ? site.year : 2022,
            decoration: InputDecoration(
              labelText: l.irradianceYearLabel,
              isDense: true,
            ),
            items: [
              for (final y in yearOptions)
                DropdownMenuItem<int>(value: y, child: Text('$y')),
            ],
            onChanged: (v) {
              if (v == null) return;
              site.year = v;
              site.samples = null;
              site.loadedFromCache = null;
              controller.clearIrradianceError();
              controller.touch();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String?>(
            key: const Key('irradiance-raddatabase-field'),
            isExpanded: true,
            initialValue: pvgisRadDatabaseOptions.contains(site.radDatabase)
                ? site.radDatabase
                : null,
            decoration: InputDecoration(
              labelText: l.projectRadDatabase,
              isDense: true,
            ),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(l.projectRadDatabaseAuto)),
              const DropdownMenuItem<String?>(value: 'PVGIS-SARAH3', child: Text('PVGIS-SARAH3')),
              const DropdownMenuItem<String?>(value: 'PVGIS-SARAH2', child: Text('PVGIS-SARAH2')),
              const DropdownMenuItem<String?>(value: 'PVGIS-ERA5', child: Text('PVGIS-ERA5')),
              const DropdownMenuItem<String?>(value: 'PVGIS-NSRDB', child: Text('PVGIS-NSRDB')),
            ],
            onChanged: (v) {
              site.radDatabase = v;
              site.samples = null;
              site.loadedFromCache = null;
              controller.clearIrradianceError();
              controller.touch();
            },
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          key: const Key('irradiance-load-button'),
          onPressed: controller.loadingIrradiance
              ? null
              : () => controller.loadSiteIrradiance(),
          icon: controller.loadingIrradiance
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cloud_download),
          label: Text(l.irradianceLoadButton),
        ),
      ],
    );
  }
}

class _ChartArea extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = context.watch<ProjectController>();
    final site = controller.draft.siteIrradiance;
    final error = controller.lastIrradianceError;
    final scheme = Theme.of(context).colorScheme;

    if (controller.loadingIrradiance) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(l.irradianceLoadingHint),
        ]),
      );
    }

    if (error != null) {
      return Card(
        color: scheme.errorContainer,
        child: ListTile(
          leading: Icon(Icons.error_outline, color: scheme.onErrorContainer),
          title: Text(l.irradianceErrorTitle, style: TextStyle(color: scheme.onErrorContainer)),
          subtitle: Text(error, style: TextStyle(color: scheme.onErrorContainer)),
        ),
      );
    }

    final samples = site.samples;
    if (samples == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Icon(Icons.wb_sunny_outlined, size: 64, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            l.irradianceEmpty,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ]),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IrradianceChart(series: samples),
            const SizedBox(height: 8),
            Row(children: [
              Icon(
                switch (site.loadedFromCache) {
                  true => Icons.cached,
                  false => Icons.cloud_download_outlined,
                  null => Icons.public,
                },
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                [
                  samples.radDatabase ?? l.projectRadDatabaseAuto,
                  if (site.loadedFromCache == true) l.irradianceCacheHit,
                  if (site.loadedFromCache == false) l.irradianceCacheMiss,
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
