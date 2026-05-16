import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One match returned by a geocoder.
class GeocodeResult {
  const GeocodeResult({
    required this.displayName,
    required this.latitudeDeg,
    required this.longitudeDeg,
  });

  final String displayName;
  final double latitudeDeg;
  final double longitudeDeg;
}

abstract class GeocodingService {
  /// Look up up to [limit] address matches. Implementations must
  /// surface usage-policy and network errors via [GeocodingException].
  Future<List<GeocodeResult>> search(String query, {int limit = 5});
}

class GeocodingException implements Exception {
  GeocodingException(this.message);
  final String message;
  @override
  String toString() => 'GeocodingException: $message';
}

/// OpenStreetMap Nominatim adapter.
///
/// Compliance notes — read the [usage policy](https://operations.osmfoundation.org/policies/nominatim/)
/// before changing this:
///
/// * **User-Agent** — Nominatim requires every request to identify
///   the calling application. We pass a project-specific UA so OSM
///   operators can reach us if we ever misbehave.
/// * **Rate limit** — at most one request per second. This class
///   enforces a per-instance minimum delay so accidental double-taps
///   don't burst the public endpoint.
/// * **No autocomplete-on-keystroke** — only call [search] from an
///   explicit user action (button press or submit), never from an
///   onChanged handler.
/// * **No bulk geocoding** — the public endpoint is for interactive
///   use; batch jobs need a self-hosted instance.
class NominatimGeocoder implements GeocodingService {
  NominatimGeocoder({
    http.Client? client,
    this.userAgent =
        'pv-calculator/0.3 (+https://github.com/Dexus/pv-calculator)',
    this.endpoint = 'https://nominatim.openstreetmap.org/search',
    this.minimumInterval = const Duration(seconds: 1),
    this.requestTimeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String userAgent;
  final String endpoint;
  final Duration minimumInterval;
  final Duration requestTimeout;

  DateTime _nextAllowedAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<List<GeocodeResult>> search(String query, {int limit = 5}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    await _respectRateLimit();

    final uri = Uri.parse(endpoint).replace(queryParameters: {
      'q': trimmed,
      'format': 'jsonv2',
      'limit': limit.clamp(1, 20).toString(),
      'addressdetails': '0',
    });

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {
            'User-Agent': userAgent,
            'Accept': 'application/json',
            'Accept-Language': 'de,en',
          })
          .timeout(requestTimeout);
    } on TimeoutException {
      throw GeocodingException('Zeitüberschreitung bei der Adresssuche.');
    } catch (e) {
      throw GeocodingException('Netzwerkfehler: $e');
    }

    if (response.statusCode == 429) {
      throw GeocodingException(
        'Nominatim hat das Limit erreicht (429). Bitte einen Moment warten.',
      );
    }
    if (response.statusCode != 200) {
      throw GeocodingException(
        'Nominatim antwortete mit Status ${response.statusCode}.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw GeocodingException('Antwort von Nominatim ist kein gültiges JSON.');
    }
    if (decoded is! List) {
      throw GeocodingException('Unerwartetes Antwortformat von Nominatim.');
    }

    final results = <GeocodeResult>[];
    for (final raw in decoded) {
      if (raw is! Map) continue;
      final entry = raw.cast<String, dynamic>();
      final display = entry['display_name'];
      final lat = double.tryParse('${entry['lat']}');
      final lon = double.tryParse('${entry['lon']}');
      if (display is String && lat != null && lon != null) {
        results.add(GeocodeResult(
          displayName: display,
          latitudeDeg: lat,
          longitudeDeg: lon,
        ));
      }
    }
    return results;
  }

  Future<void> _respectRateLimit() async {
    final now = DateTime.now();
    if (now.isBefore(_nextAllowedAt)) {
      await Future<void>.delayed(_nextAllowedAt.difference(now));
    }
    _nextAllowedAt = DateTime.now().add(minimumInterval);
  }

  void dispose() => _client.close();
}
