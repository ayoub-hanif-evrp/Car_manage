import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_logan/features/navigation/route_geometry.dart';

void main() {
  test('remaining length decreases along the polyline', () {
    final points = [
      const LatLng(33.57, -7.59),
      const LatLng(33.58, -7.59),
      const LatLng(33.59, -7.59),
    ];
    final total = RouteGeometry.totalLengthMeters(points);
    final rem = RouteGeometry.remainingLengthMeters(points, 1);
    expect(total, greaterThan(rem));
    expect(rem, greaterThan(0));
  });

  test('nearest index finds closest vertex', () {
    final points = [
      const LatLng(33.57, -7.59),
      const LatLng(33.58, -7.59),
      const LatLng(33.59, -7.59),
    ];
    final near = RouteGeometry.nearestOnRoute(
      points,
      const LatLng(33.5801, -7.5901),
    );
    expect(near.index, anyOf(0, 1, 2));
    expect(near.distanceMeters, lessThan(200));
  });
}
