import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Local geometry helpers for progress along a TomTom polyline.
/// Does not invent traffic — only measures position vs returned geometry.
class RouteGeometry {
  RouteGeometry._();

  static const _distance = Distance();

  static double distanceMeters(LatLng a, LatLng b) => _distance(a, b);

  /// Meters from [index] to the end of [points].
  static double remainingLengthMeters(List<LatLng> points, int index) {
    if (points.length < 2) return 0;
    final start = index.clamp(0, points.length - 1);
    var sum = 0.0;
    for (var i = start; i < points.length - 1; i++) {
      sum += _distance(points[i], points[i + 1]);
    }
    return sum;
  }

  static double totalLengthMeters(List<LatLng> points) =>
      remainingLengthMeters(points, 0);

  /// Closest vertex index and perpendicular-ish distance to the polyline.
  static ({int index, double distanceMeters}) nearestOnRoute(
    List<LatLng> points,
    LatLng position,
  ) {
    if (points.isEmpty) {
      return (index: 0, distanceMeters: double.infinity);
    }
    var bestIndex = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = _distance(position, points[i]);
      if (d < bestDist) {
        bestDist = d;
        bestIndex = i;
      }
    }
    // Also sample segment midpoints for better off-route detection.
    for (var i = 0; i < points.length - 1; i++) {
      final mid = LatLng(
        (points[i].latitude + points[i + 1].latitude) / 2,
        (points[i].longitude + points[i + 1].longitude) / 2,
      );
      final d = _distance(position, mid);
      if (d < bestDist) {
        bestDist = d;
        bestIndex = i;
      }
    }
    return (index: bestIndex, distanceMeters: bestDist);
  }

  /// Bearing degrees [0,360) from a → b.
  static double bearingDegrees(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180 / math.pi;
    return (brng + 360) % 360;
  }
}
