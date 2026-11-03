import 'package:latlong2/latlong.dart';

class OsrmManeuver {
  const OsrmManeuver({
    required this.type,
    required this.modifier,
    required this.instruction,
    required this.location,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final String type;
  final String? modifier;
  final String instruction;
  final LatLng location;
  final double distanceMeters;
  final double durationSeconds;
}

class OsrmRouteOption {
  const OsrmRouteOption({
    required this.index,
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuvers,
  });

  final int index;
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<OsrmManeuver> maneuvers;

  /// Road-network estimate only — not live congestion.
  DateTime etaFrom(DateTime now) =>
      now.add(Duration(seconds: durationSeconds.round()));
}

class OsrmRouteResponse {
  const OsrmRouteResponse({
    required this.routes,
    required this.fetchedAt,
  });

  final List<OsrmRouteOption> routes;
  final DateTime fetchedAt;
}
