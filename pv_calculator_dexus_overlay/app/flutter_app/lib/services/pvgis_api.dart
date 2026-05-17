import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pv_engine/pv_engine.dart';

import '../config.dart';
import '../l10n/generated/app_localizations.dart';

/// Classifies a PVGIS-API failure so the UI can render a localized
/// message.
enum PvgisApiFailureKind { invalidRequest, timeout, network, badStatus, parseFailed }

/// Raised when the PVGIS API call fails or returns unusable data.
///
/// Wraps every non-success branch so the UI only needs one catch-all
/// `on PvgisApiException`: network errors, HTTP non-200, malformed
/// JSON, and PVGIS's documented `message` error payloads all funnel
/// here.
class PvgisApiException implements Exception {
  PvgisApiException(this.kind, {this.statusCode, this.detail, String? message})
      : message = message ?? _fallbackMessage(kind, statusCode, detail);

  final PvgisApiFailureKind kind;
  final int? statusCode;
  final String? detail;

  /// English fallback for `toString()` / un-localized contexts. UI
  /// should use [formatPvgisApiException] for user-facing text.
  final String message;

  static String _fallbackMessage(PvgisApiFailureKind kind, int? code, String? detail) {
    switch (kind) {
      case PvgisApiFailureKind.invalidRequest:
        return 'Invalid PVGIS request: ${detail ?? ''}';
      case PvgisApiFailureKind.timeout:
        return 'PVGIS request timed out.';
      case PvgisApiFailureKind.network:
        return 'Network error on PVGIS request: ${detail ?? ''}';
      case PvgisApiFailureKind.badStatus:
        return 'PVGIS responded with status $code. ${detail ?? ''}';
      case PvgisApiFailureKind.parseFailed:
        return 'Could not read PVGIS response: ${detail ?? ''}';
    }
  }

  @override
  String toString() => 'PvgisApiException: $message';
}

/// Renders a [PvgisApiException] in the current locale.
String formatPvgisApiException(AppLocalizations l, PvgisApiException e) {
  switch (e.kind) {
    case PvgisApiFailureKind.invalidRequest:
      return l.pvgisApiInvalidRequest(e.detail ?? '');
    case PvgisApiFailureKind.timeout:
      return l.pvgisApiTimeout;
    case PvgisApiFailureKind.network:
      return l.pvgisApiNetworkError(e.detail ?? '');
    case PvgisApiFailureKind.badStatus:
      return l.pvgisApiBadStatus(e.statusCode ?? 0, e.detail ?? '');
    case PvgisApiFailureKind.parseFailed:
      return l.pvgisApiParseFailed(e.detail ?? '');
  }
}

/// Result of a successful horizontal-series fetch: the parsed series
/// plus whether the proxy answered from cache (when the proxy is in use).
class PvgisHorizontalFetchResult {
  const PvgisHorizontalFetchResult({required this.series, required this.fromCache});

  final HorizontalIrradianceSeries series;

  /// `true` if the upstream Cloudflare worker returned `X-Cache: HIT`,
  /// `false` if it was `MISS`, `null` if no cache header was present
  /// (direct PVGIS call, or proxy not in use).
  final bool? fromCache;
}

/// Thin HTTP wrapper around the PVGIS `seriescalc` endpoint, configured
/// for the redesigned app's **site-level horizontal** workflow.
///
/// Notes:
/// * **Endpoint** — defaults to the value of `--dart-define=PVGIS_PROXY`
///   (see `lib/config.dart`) when set, so the Cloudflare R2 cache fronts
///   the public host. Without the define, talks to PVGIS directly.
/// * **CORS** — the public PVGIS host serves
///   `Access-Control-Allow-Origin: *`, so Flutter web works without the
///   proxy too. Use the proxy to avoid per-user rate hits and to bring
///   repeat lookups down to ~50 ms.
/// * **Rate limit** — PVGIS publishes no hard rate limit; this class
///   enforces a small per-instance minimum delay so accidental
///   double-taps don't open two simultaneous requests.
/// * **Caching** — none in-process. The proxy/R2 handles repeat queries;
///   the [ProjectController] caches the parsed series for the lifetime
///   of the working draft.
class PvgisApiService {
  PvgisApiService({
    http.Client? client,
    String? endpoint,
    this.minimumInterval = const Duration(milliseconds: 500),
    this.requestTimeout = const Duration(seconds: 60),
  })  : _client = client ?? http.Client(),
        endpoint = endpoint ?? pvgisProxyEndpoint;

  final http.Client _client;

  /// PVGIS endpoint (proxy or direct). `null` falls back to the engine's
  /// public default.
  final String? endpoint;

  final Duration minimumInterval;

  /// Per-request timeout. Cold PVGIS responses can take 10–30 s under
  /// load, so default to a minute.
  final Duration requestTimeout;

  DateTime _nextAllowedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Fetches one year of horizontal global + diffuse irradiance for the
  /// given site. Returns the parsed [HorizontalIrradianceSeries] plus
  /// the cache-hit flag from the proxy (when applicable).
  Future<PvgisHorizontalFetchResult> fetchHorizontalSeries({
    required double latitudeDeg,
    required double longitudeDeg,
    required int year,
    String? radDatabase,
  }) async {
    final Uri url;
    try {
      url = pvgisHorizontalSeriesUrl(
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg,
        year: year,
        radDatabase: radDatabase,
        endpoint: endpoint,
      );
    } on ArgumentError catch (e) {
      throw PvgisApiException(
        PvgisApiFailureKind.invalidRequest,
        detail: e.message?.toString() ?? e.toString(),
      );
    }
    await _respectRateLimit();

    final http.Response response;
    try {
      response = await _client.get(
        url,
        headers: const {'Accept': 'application/json'},
      ).timeout(requestTimeout);
    } on TimeoutException {
      throw PvgisApiException(PvgisApiFailureKind.timeout);
    } catch (e) {
      throw PvgisApiException(PvgisApiFailureKind.network, detail: e.toString());
    }

    if (response.statusCode != 200) {
      throw PvgisApiException(
        PvgisApiFailureKind.badStatus,
        statusCode: response.statusCode,
        detail: _extractErrorMessage(response.body),
      );
    }

    final HorizontalIrradianceSeries series;
    try {
      series = parsePvgisHorizontalSeries(response.body, year: year);
    } on FormatException catch (e) {
      throw PvgisApiException(
        PvgisApiFailureKind.parseFailed,
        detail: e.message,
      );
    }

    // The Cloudflare worker sets `X-Cache: HIT|MISS`. Lowercase the key
    // before lookup because http.Headers normalises to lower-case keys.
    final cacheHeader = response.headers['x-cache']?.toUpperCase();
    final bool? fromCache = switch (cacheHeader) {
      'HIT' => true,
      'MISS' => false,
      _ => null,
    };
    return PvgisHorizontalFetchResult(series: series, fromCache: fromCache);
  }

  Future<void> _respectRateLimit() async {
    final now = DateTime.now();
    if (now.isBefore(_nextAllowedAt)) {
      await Future<void>.delayed(_nextAllowedAt.difference(now));
    }
    _nextAllowedAt = DateTime.now().add(minimumInterval);
  }

  /// Best-effort excerpt from a PVGIS error response. PVGIS documents
  /// JSON error payloads of the shape `{"message": "...", ...}`;
  /// surface that verbatim so users see e.g. "outside coverage" instead
  /// of the raw envelope.
  static String _extractErrorMessage(String body) {
    if (body.isEmpty) return '';
    final trimmed = body.trim();
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        for (final key in const ['message', 'error', 'detail']) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
        final errors = decoded['errors'];
        if (errors is List && errors.isNotEmpty) {
          final first = errors.first;
          if (first is String && first.trim().isNotEmpty) return first.trim();
          if (first is Map) {
            for (final key in const ['message', 'error', 'detail']) {
              final value = first[key];
              if (value is String && value.trim().isNotEmpty) {
                return value.trim();
              }
            }
          }
        }
      }
    } on FormatException {
      // Body wasn't JSON — fall through to the raw excerpt.
    }
    return trimmed.length > 200 ? trimmed.substring(0, 200) : trimmed;
  }

  void dispose() => _client.close();
}
