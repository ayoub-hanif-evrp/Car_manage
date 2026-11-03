import 'package:latlong2/latlong.dart';

class TomTomSearchResult {
  const TomTomSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.position,
  });

  final String id;
  final String title;
  final String subtitle;
  final LatLng position;
}

class TomTomRouteOption {
  const TomTomRouteOption({
    required this.index,
    required this.points,
    required this.lengthInMeters,
    required this.travelTimeInSeconds,
    required this.trafficDelayInSeconds,
    required this.noTrafficTravelTimeInSeconds,
    required this.liveTrafficTravelTimeInSeconds,
  });

  final int index;
  final List<LatLng> points;
  final int lengthInMeters;
  final int travelTimeInSeconds;
  final int trafficDelayInSeconds;
  final int? noTrafficTravelTimeInSeconds;
  final int? liveTrafficTravelTimeInSeconds;

  bool get hasLiveTrafficSignal {
    if (liveTrafficTravelTimeInSeconds == null) {
      return trafficDelayInSeconds > 0;
    }
    final noTraffic = noTrafficTravelTimeInSeconds;
    if (noTraffic == null) return trafficDelayInSeconds > 0;
    return liveTrafficTravelTimeInSeconds != noTraffic ||
        trafficDelayInSeconds > 0;
  }

  DateTime etaFrom(DateTime now) =>
      now.add(Duration(seconds: travelTimeInSeconds));
}

class TomTomRouteResponse {
  const TomTomRouteResponse({
    required this.routes,
    required this.fetchedAt,
  });

  final List<TomTomRouteOption> routes;
  final DateTime fetchedAt;
}
