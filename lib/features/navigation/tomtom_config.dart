/// TomTom credentials and endpoints.
/// Key is injected at build/run time — never commit a real key.
class TomTomConfig {
  TomTomConfig._();

  static const apiKey = String.fromEnvironment('TOMTOM_API_KEY');

  static bool get hasApiKey => apiKey.isNotEmpty;

  static const baseUrl = 'https://api.tomtom.com';

  /// Raster basic map tiles (Map Display API v1) for flutter_map.
  static String rasterTileUrlTemplate(String key) =>
      '$baseUrl/map/1/tile/basic/main/{z}/{x}/{y}.png?key=$key';

  static Uri fuzzySearch(String query, {int limit = 8}) {
    final q = Uri.encodeComponent(query);
    return Uri.parse(
      '$baseUrl/search/2/search/$q.json'
      '?key=$apiKey'
      '&countrySet=MA'
      '&limit=$limit'
      '&typeahead=true'
      '&language=fr-FR',
    );
  }

  static Uri calculateRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    int maxAlternatives = 2,
  }) {
    return Uri.parse(
      '$baseUrl/routing/1/calculateRoute/'
      '$fromLat,$fromLon:$toLat,$toLon/json'
      '?key=$apiKey'
      '&traffic=true'
      '&travelMode=car'
      '&routeType=fastest'
      '&maxAlternatives=$maxAlternatives'
      '&sectionType=traffic'
      '&computeTravelTimeFor=all'
      '&routeRepresentation=polyline',
    );
  }
}
