import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'tomtom_config.dart';
import 'tomtom_models.dart';

class TomTomApiException implements Exception {
  TomTomApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thin TomTom REST client (Search + Calculate Route).
/// Does not invent traffic or routes when the API fails.
class TomTomApiClient {
  TomTomApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  void dispose() => _http.close();

  Future<List<TomTomSearchResult>> searchMorocco(String query) async {
    if (!TomTomConfig.hasApiKey) {
      throw TomTomApiException('Missing TOMTOM_API_KEY');
    }
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final res = await _http.get(TomTomConfig.fuzzySearch(trimmed)).timeout(
          const Duration(seconds: 12),
        );
    if (res.statusCode == 403 || res.statusCode == 401) {
      throw TomTomApiException(
        'TomTom rejected the API key (HTTP ${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }
    if (res.statusCode == 429) {
      throw TomTomApiException(
        'TomTom quota/rate limit hit (HTTP 429). Stay on free tier; do not enable paid overage without approval.',
        statusCode: 429,
      );
    }
    if (res.statusCode != 200) {
      throw TomTomApiException(
        'Search failed (HTTP ${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>? ?? const [];
    final out = <TomTomSearchResult>[];
    for (final raw in results) {
      final item = raw as Map<String, dynamic>;
      final pos = item['position'] as Map<String, dynamic>?;
      if (pos == null) continue;
      final poi = item['poi'] as Map<String, dynamic>?;
      final address = item['address'] as Map<String, dynamic>?;
      final title = (poi?['name'] as String?) ??
          (address?['freeformAddress'] as String?) ??
          'Place';
      final subtitle = (address?['freeformAddress'] as String?) ??
          (address?['municipality'] as String?) ??
          '';
      out.add(
        TomTomSearchResult(
          id: (item['id'] as String?) ?? '${pos['lat']},${pos['lon']}',
          title: title,
          subtitle: subtitle,
          position: LatLng(
            (pos['lat'] as num).toDouble(),
            (pos['lon'] as num).toDouble(),
          ),
        ),
      );
    }
    return out;
  }

  Future<TomTomRouteResponse> calculateRoutes({
    required LatLng from,
    required LatLng to,
    int maxAlternatives = 2,
  }) async {
    if (!TomTomConfig.hasApiKey) {
      throw TomTomApiException('Missing TOMTOM_API_KEY');
    }

    final res = await _http
        .get(
          TomTomConfig.calculateRoute(
            fromLat: from.latitude,
            fromLon: from.longitude,
            toLat: to.latitude,
            toLon: to.longitude,
            maxAlternatives: maxAlternatives,
          ),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 403 || res.statusCode == 401) {
      throw TomTomApiException(
        'TomTom rejected the API key (HTTP ${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }
    if (res.statusCode == 429) {
      throw TomTomApiException(
        'TomTom quota/rate limit hit (HTTP 429).',
        statusCode: 429,
      );
    }
    if (res.statusCode != 200) {
      throw TomTomApiException(
        'Routing failed (HTTP ${res.statusCode}): ${res.body.length > 180 ? '${res.body.substring(0, 180)}…' : res.body}',
        statusCode: res.statusCode,
      );
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final routesJson = json['routes'] as List<dynamic>? ?? const [];
    if (routesJson.isEmpty) {
      throw TomTomApiException('TomTom returned no routes.');
    }

    final routes = <TomTomRouteOption>[];
    for (var i = 0; i < routesJson.length; i++) {
      final route = routesJson[i] as Map<String, dynamic>;
      final summary = route['summary'] as Map<String, dynamic>? ?? const {};
      final legs = route['legs'] as List<dynamic>? ?? const [];
      final points = <LatLng>[];
      for (final leg in legs) {
        final legMap = leg as Map<String, dynamic>;
        final pts = legMap['points'] as List<dynamic>? ?? const [];
        for (final p in pts) {
          final pm = p as Map<String, dynamic>;
          points.add(
            LatLng(
              (pm['latitude'] as num).toDouble(),
              (pm['longitude'] as num).toDouble(),
            ),
          );
        }
      }
      if (points.length < 2) continue;
      routes.add(
        TomTomRouteOption(
          index: i,
          points: points,
          lengthInMeters: (summary['lengthInMeters'] as num?)?.toInt() ?? 0,
          travelTimeInSeconds:
              (summary['travelTimeInSeconds'] as num?)?.toInt() ?? 0,
          trafficDelayInSeconds:
              (summary['trafficDelayInSeconds'] as num?)?.toInt() ?? 0,
          noTrafficTravelTimeInSeconds:
              (summary['noTrafficTravelTimeInSeconds'] as num?)?.toInt(),
          liveTrafficTravelTimeInSeconds:
              (summary['liveTrafficIncidentsTravelTimeInSeconds'] as num?)
                  ?.toInt(),
        ),
      );
    }

    if (routes.isEmpty) {
      throw TomTomApiException('TomTom routes had no geometry.');
    }

    return TomTomRouteResponse(routes: routes, fetchedAt: DateTime.now());
  }
}
