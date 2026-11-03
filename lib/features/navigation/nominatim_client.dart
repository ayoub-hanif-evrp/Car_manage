import 'dart:convert';

import 'package:http/http.dart' as http;

class NominatimPlace {
  const NominatimPlace({
    required this.name,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String subtitle;
  final double latitude;
  final double longitude;
}

class NominatimException implements Exception {
  NominatimException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Public Nominatim search — submit-on-search only (no autocomplete).
/// Policy: https://operations.osmfoundation.org/policies/nominatim/
class NominatimClient {
  NominatimClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;
  DateTime? _lastRequestAt;
  final Map<String, List<NominatimPlace>> _cache = {};

  static const userAgent =
      'MyLogan/0.1 (personal Android navigation; Galaxy A02)';

  void dispose() => _http.close();

  Future<List<NominatimPlace>> search(String query, {int limit = 6}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final cacheKey = trimmed.toLowerCase();
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    await _throttle();

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': trimmed,
      'format': 'json',
      'addressdetails': '0',
      'limit': '$limit',
      'countrycodes': 'ma',
      'accept-language': 'fr,ar,en',
    });

    final res = await _http
        .get(
          uri,
          headers: {
            'User-Agent': userAgent,
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 429) {
      throw NominatimException(
        'Search rate limited. Wait a second and try again.',
      );
    }
    if (res.statusCode != 200) {
      throw NominatimException('Search failed (HTTP ${res.statusCode}).');
    }

    final list = jsonDecode(res.body) as List<dynamic>;
    final out = <NominatimPlace>[];
    for (final raw in list) {
      final item = raw as Map<String, dynamic>;
      final lat = double.tryParse('${item['lat']}');
      final lon = double.tryParse('${item['lon']}');
      if (lat == null || lon == null) continue;
      final display = (item['display_name'] as String?) ?? 'Place';
      final parts = display.split(',').map((e) => e.trim()).toList();
      final name = parts.isNotEmpty ? parts.first : display;
      final subtitle = parts.length > 1
          ? parts.skip(1).take(3).join(', ')
          : 'Morocco';
      out.add(
        NominatimPlace(
          name: name,
          subtitle: subtitle,
          latitude: lat,
          longitude: lon,
        ),
      );
    }

    _cache[cacheKey] = out;
    return out;
  }

  Future<void> _throttle() async {
    final last = _lastRequestAt;
    if (last != null) {
      final wait =
          const Duration(milliseconds: 1100) - DateTime.now().difference(last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastRequestAt = DateTime.now();
  }
}
