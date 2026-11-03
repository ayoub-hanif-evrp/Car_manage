/// Public FOSSGIS / Project-OSRM demo routing (no API key).
/// Policy: identifying User-Agent, ≤1 request/second, personal/demo use only.
/// No uptime guarantee — not a production SLA.
class OsrmConfig {
  OsrmConfig._();

  static const baseUrl = 'https://router.project-osrm.org';
  static const userAgent = 'MyLogan/0.1 (personal Android; Galaxy A02; contact: local)';

  /// OpenFreeMap Liberty style for MapLibre (no account / no key).
  static const openFreeMapLiberty = 'https://tiles.openfreemap.org/styles/liberty';

  static Uri route({
    required double fromLon,
    required double fromLat,
    required double toLon,
    required double toLat,
    bool alternatives = true,
  }) {
    return Uri.parse(
      '$baseUrl/route/v1/driving/'
      '$fromLon,$fromLat;$toLon,$toLat'
      '?overview=full'
      '&geometries=geojson'
      '&steps=true'
      '&alternatives=${alternatives ? 'true' : 'false'}'
      '&annotations=false',
    );
  }
}
