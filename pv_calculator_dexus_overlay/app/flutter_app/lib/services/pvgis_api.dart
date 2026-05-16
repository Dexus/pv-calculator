import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:pv_engine/pv_engine.dart';

/// Raised when the PVGIS API call fails or returns unusable data.
///
/// Wraps every non-success branch so the UI only needs one catch-all
/// `on PvgisApiException`: network errors, HTTP non-200, malformed
/// JSON, and PVGIS's documented `message` error payloads all funnel
/// here.
class PvgisApiException implements Exception {
  PvgisApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'PvgisApiException: $message';
}

/// Thin HTTP wrapper around the PVGIS `seriescalc` endpoint.
///
/// Notes:
/// * **CORS** — the public PVGIS host serves
///   `Access-Control-Allow-Origin: *`, so this works from Flutter web
///   in most browsers. If CORS does fail in a managed environment,
///   point [endpoint] at a self-hosted reverse proxy.
/// * **Rate limit** — PVGIS publishes no hard rate limit, but each
///   `seriescalc` call processes a multi-year hourly file. We enforce
///   a small per-instance minimum delay so accidental double-taps
///   don't open two simultaneous requests.
/// * **Caching** — none here. The caller (Flutter app) stores the
///   parsed series on the [ConfigDraft] so re-running the simulation
///   doesn't re-fetch.
class PvgisApiService {
  PvgisApiService({
    http.Client? client,
    this.endpoint,
    this.minimumInterval = const Duration(milliseconds: 500),
    this.requestTimeout = const Duration(seconds: 60),
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// Override the PVGIS endpoint URL. `null` uses the public host from
  /// [pvgisSeriesCalcEndpoint].
  final String? endpoint;

  final Duration minimumInterval;

  /// Per-request timeout. PVGIS multi-year hourly requests can take
  /// 10–30 s under load, so we default to a minute.
  final Duration requestTimeout;

  DateTime _nextAllowedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Issues a `seriescalc` request and returns the parsed hourly
  /// series. Throws [PvgisApiException] on any failure.
  Future<PvgisHourlyData> fetch(PvgisRequest request) async {
    final Uri url;
    try {
      url = buildPvgisSeriesCalcUrl(request, endpoint: endpoint);
    } on ArgumentError catch (e) {
      throw PvgisApiException(
        'Ungültige PVGIS-Anfrage: ${e.message ?? e.toString()}',
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
      throw PvgisApiException('Zeitüberschreitung bei PVGIS-Abfrage.');
    } catch (e) {
      throw PvgisApiException('Netzwerkfehler bei PVGIS-Abfrage: $e');
    }

    if (response.statusCode != 200) {
      // PVGIS returns a JSON `message` field on errors; surface it
      // verbatim so the user sees the actual cause (e.g. coordinates
      // outside the radiation-database coverage).
      throw PvgisApiException(
        'PVGIS antwortete mit Status ${response.statusCode}. '
        '${_extractErrorMessage(response.body)}',
        statusCode: response.statusCode,
      );
    }

    try {
      return parsePvgisHourlyJson(response.body);
    } on FormatException catch (e) {
      throw PvgisApiException(
        'PVGIS-Antwort konnte nicht gelesen werden: ${e.message}',
      );
    }
  }

  Future<void> _respectRateLimit() async {
    final now = DateTime.now();
    if (now.isBefore(_nextAllowedAt)) {
      await Future<void>.delayed(_nextAllowedAt.difference(now));
    }
    _nextAllowedAt = DateTime.now().add(minimumInterval);
  }

  /// Best-effort excerpt from a PVGIS error response. Returns the
  /// first 200 chars of the body when JSON parsing fails so callers
  /// can still see what came back.
  String _extractErrorMessage(String body) {
    if (body.isEmpty) return '';
    final lower = body.trim();
    if (lower.length > 200) return lower.substring(0, 200);
    return lower;
  }

  void dispose() => _client.close();
}
