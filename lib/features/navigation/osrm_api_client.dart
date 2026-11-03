import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'osrm_config.dart';
import 'osrm_models.dart';

class OsrmApiException implements Exception {
  OsrmApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thin OSRM Route client against the public demo server.
class OsrmApiClient {
  OsrmApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;
  DateTime? _lastRequestAt;

  void dispose() => _http.close();

  Future<void> _throttle() async {
    final last = _lastRequestAt;
    if (last != null) {
      final wait = const Duration(milliseconds: 1100) - DateTime.now().difference(last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastRequestAt = DateTime.now();
  }

  Future<OsrmRouteResponse> calculateRoutes({
    required LatLng from,
    required LatLng to,
  }) async {
    await _throttle();
    final uri = OsrmConfig.route(
      fromLon: from.longitude,
      fromLat: from.latitude,
      toLon: to.longitude,
      toLat: to.latitude,
    );

    final res = await _http
        .get(
          uri,
          headers: {
            'User-Agent': OsrmConfig.userAgent,
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 429) {
      throw OsrmApiException(
        'OSRM rate limited (HTTP 429). Wait and retry — public demo allows ~1 req/s.',
        statusCode: 429,
      );
    }
    if (res.statusCode != 200) {
      throw OsrmApiException(
        'OSRM routing failed (HTTP ${res.statusCode}). Public demo may be down.',
        statusCode: res.statusCode,
      );
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final code = json['code'] as String? ?? '';
    if (code != 'Ok') {
      throw OsrmApiException(
        'OSRM error: $code ${json['message'] ?? ''}'.trim(),
      );
    }

    final routesJson = json['routes'] as List<dynamic>? ?? const [];
    if (routesJson.isEmpty) {
      throw OsrmApiException('OSRM returned no routes.');
    }

    final routes = <OsrmRouteOption>[];
    for (var i = 0; i < routesJson.length; i++) {
      final route = routesJson[i] as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'] as List<dynamic>? ?? const [];
      final points = <LatLng>[];
      for (final c in coords) {
        final pair = c as List<dynamic>;
        points.add(
          LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
        );
      }
      if (points.length < 2) continue;

      final maneuvers = <OsrmManeuver>[];
      final legs = route['legs'] as List<dynamic>? ?? const [];
      for (final leg in legs) {
        final steps = (leg as Map<String, dynamic>)['steps'] as List<dynamic>? ??
            const [];
        for (final step in steps) {
          final s = step as Map<String, dynamic>;
          final man = s['maneuver'] as Map<String, dynamic>? ?? const {};
          final loc = man['location'] as List<dynamic>?;
          if (loc == null || loc.length < 2) continue;
          final type = man['type'] as String? ?? 'turn';
          final modifier = man['modifier'] as String?;
          final name = s['name'] as String? ?? '';
          maneuvers.add(
            OsrmManeuver(
              type: type,
              modifier: modifier,
              instruction: _instruction(type, modifier, name),
              location: LatLng(
                (loc[1] as num).toDouble(),
                (loc[0] as num).toDouble(),
              ),
              distanceMeters: (s['distance'] as num?)?.toDouble() ?? 0,
              durationSeconds: (s['duration'] as num?)?.toDouble() ?? 0,
            ),
          );
        }
      }

      routes.add(
        OsrmRouteOption(
          index: i,
          points: points,
          distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
          durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
          maneuvers: maneuvers,
        ),
      );
    }

    if (routes.isEmpty) {
      throw OsrmApiException('OSRM routes had no geometry.');
    }

    return OsrmRouteResponse(routes: routes, fetchedAt: DateTime.now());
  }

  static String _instruction(String type, String? modifier, String road) {
    final mod = modifier == null ? '' : ' $modifier';
    final onto = road.isEmpty ? '' : ' onto $road';
    return '$type$mod$onto'.trim();
  }
}
