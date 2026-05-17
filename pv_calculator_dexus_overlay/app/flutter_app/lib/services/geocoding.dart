import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../l10n/generated/app_localizations.dart';

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

/// Classifies a geocoding failure so the UI can render a localized
/// message. [detail] carries the raw exception text for `network`; for
/// `badStatus`, [statusCode] holds the HTTP code.
enum GeocodingFailureKind { timeout, network, rateLimit, badStatus, invalidJson, invalidFormat }

class GeocodingException implements Exception {
  GeocodingException(this.kind, {this.statusCode, this.detail, String? message})
      : message = message ?? _fallbackMessage(kind, statusCode, detail);

  final GeocodingFailureKind kind;
  final int? statusCode;
  final String? detail;

  /// English fallback used for `toString()` / un-localized contexts
  /// (tests, logs). The UI should call [formatGeocodingException]
  /// instead so the user-facing text follows the current locale.
  final String message;

  static String _fallbackMessage(GeocodingFailureKind kind, int? code, String? detail) {
    switch (kind) {
      case GeocodingFailureKind.timeout:
        return 'Address lookup timed out.';
      case GeocodingFailureKind.network:
        return 'Network error: ${detail ?? ''}';
      case GeocodingFailureKind.rateLimit:
        return 'Rate limit hit (429).';
      case GeocodingFailureKind.badStatus:
        return 'Bad status: $code';
      case GeocodingFailureKind.invalidJson:
        return 'Invalid JSON response.';
      case GeocodingFailureKind.invalidFormat:
        return 'Unexpected response format.';
    }
  }

  @override
  String toString() => 'GeocodingException: $message';
}

/// Renders a [GeocodingException] in the current locale.
String formatGeocodingException(AppLocalizations l, GeocodingException e) {
  switch (e.kind) {
    case GeocodingFailureKind.timeout:
      return l.geocodingTimeout;
    case GeocodingFailureKind.network:
      return l.geocodingNetworkError(e.detail ?? '');
    case GeocodingFailureKind.rateLimit:
      return l.geocodingRateLimit;
    case GeocodingFailureKind.badStatus:
      return l.geocodingBadStatus(e.statusCode ?? 0);
    case GeocodingFailureKind.invalidJson:
      return l.geocodingInvalidJson;
    case GeocodingFailureKind.invalidFormat:
      return l.geocodingInvalidFormat;
  }
}

/// OpenStreetMap Nominatim adapter.
///
/// Compliance notes — read the [usage policy](https://operations.osmfoundation.org/policies/nominatim/)
/// before changing this:
///
/// * **User-Agent** — Nominatim requires every request to identify
///   the calling application. On native targets we set a
///   project-specific UA so OSM operators can reach us. **On Flutter
///   web** the browser ignores the supplied header (User-Agent is on
///   the Fetch spec's forbidden-header list and Chrome/Firefox strip
///   it silently), so we additionally send `Referer` which Nominatim
///   accepts as a fallback identifier. For higher-volume web use,
///   deploy a thin server-side proxy that can set User-Agent freely
///   or run a self-hosted Nominatim instance.
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
    this.referer = 'https://github.com/Dexus/pv-calculator',
    this.minimumInterval = const Duration(seconds: 1),
    this.requestTimeout = const Duration(seconds: 10),
    bool? isWeb,
  })  : _client = client ?? http.Client(),
        _isWeb = isWeb ?? kIsWeb;

  final http.Client _client;
  final String userAgent;
  final String endpoint;
  final String referer;
  final Duration minimumInterval;
  final Duration requestTimeout;
  final bool _isWeb;

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

    final headers = <String, String>{
      'Accept': 'application/json',
      'Accept-Language': 'de,en',
    };
    if (_isWeb) {
      // Browsers strip User-Agent. Send Referer instead so Nominatim
      // can still see where the request originates.
      headers['Referer'] = referer;
    } else {
      headers['User-Agent'] = userAgent;
    }

    final http.Response response;
    try {
      response = await _client.get(uri, headers: headers).timeout(requestTimeout);
    } on TimeoutException {
      throw GeocodingException(GeocodingFailureKind.timeout);
    } catch (e) {
      throw GeocodingException(GeocodingFailureKind.network, detail: e.toString());
    }

    if (response.statusCode == 429) {
      throw GeocodingException(GeocodingFailureKind.rateLimit, statusCode: 429);
    }
    if (response.statusCode != 200) {
      throw GeocodingException(GeocodingFailureKind.badStatus, statusCode: response.statusCode);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw GeocodingException(GeocodingFailureKind.invalidJson);
    }
    if (decoded is! List) {
      throw GeocodingException(GeocodingFailureKind.invalidFormat);
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
