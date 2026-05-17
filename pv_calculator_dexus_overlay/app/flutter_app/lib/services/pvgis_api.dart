import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pv_engine/pv_engine.dart';

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
      // PVGIS returns a JSON `message` field on errors; surface it
      // verbatim so the user sees the actual cause (e.g. coordinates
      // outside the radiation-database coverage).
      throw PvgisApiException(
        PvgisApiFailureKind.badStatus,
        statusCode: response.statusCode,
        detail: _extractErrorMessage(response.body),
      );
    }

    try {
      return parsePvgisHourlyJson(response.body);
    } on FormatException catch (e) {
      throw PvgisApiException(
        PvgisApiFailureKind.parseFailed,
        detail: e.message,
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

  /// Best-effort excerpt from a PVGIS error response.
  ///
  /// PVGIS documents JSON error payloads of the shape
  /// `{"message": "...", ...}` (sometimes `error` or nested `errors`
  /// arrays). When the body parses as JSON, prefer the first such
  /// human-readable field so users see "outside coverage" instead of
  /// `{"message":"outside coverage","status":400}`. Falls back to a
  /// 200-char excerpt of the raw body when JSON parsing fails or no
  /// known message field is present.
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
