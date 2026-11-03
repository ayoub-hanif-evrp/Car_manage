/// Gates for the open-source navigation prototype (no API keys).
class NavigationGate {
  NavigationGate._();

  /// Public OSRM demo is for personal/demo use (≤1 req/s). Not a traffic provider.
  static const bool usesPublicOsrmDemo = true;

  /// Live congestion is intentionally unavailable with OSRM + OpenFreeMap.
  static const bool liveTrafficAvailable = false;

  static bool get canRunPrototype => true;

  static List<String> get notices => const [
        'No TomTom / Mapbox / Magic Lane / Google keys — OpenFreeMap + public OSRM.',
        'ETA is a road-network estimate only. Not real-time Casablanca congestion.',
        'Public OSRM: ≤1 request/second, no uptime guarantee (FOSSGIS demo policy).',
      ];
}
