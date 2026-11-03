import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models.dart';
import 'osrm_api_client.dart';
import 'osrm_models.dart';
import 'route_geometry.dart';

export '../../data/models.dart' show FavoritePlace, RecentDestination;

enum NavPhase { idle, locating, routing, navigating, error }

/// Open-source navigation session: GPS + OSRM (no live traffic).
class NavigationSession extends ChangeNotifier {
  NavigationSession({OsrmApiClient? client}) : _client = client ?? OsrmApiClient();

  final OsrmApiClient _client;

  NavPhase phase = NavPhase.idle;
  String? errorMessage;
  String? statusNote;

  LatLng? userPosition;
  double? userHeading;
  bool followCamera = true;

  LatLng? destination;
  String? destinationLabel;
  OsrmRouteResponse? routeResponse;
  int selectedRouteIndex = 0;
  bool routingBusy = false;

  DateTime? _lastRouteAt;
  DateTime? _lastRerouteAttempt;
  DateTime? _lastCameraNotify;
  StreamSubscription<Position>? _gpsSub;
  bool _disposed = false;

  static const offRouteMeters = 45.0;
  static const minRerouteSeconds = 20;

  OsrmRouteOption? get activeRoute {
    final routes = routeResponse?.routes;
    if (routes == null || routes.isEmpty) return null;
    return routes[selectedRouteIndex.clamp(0, routes.length - 1)];
  }

  OsrmManeuver? get nextManeuver {
    final route = activeRoute;
    final pos = userPosition;
    if (route == null || route.maneuvers.isEmpty) return null;
    if (pos == null) return route.maneuvers.first;
    OsrmManeuver? best;
    var bestD = double.infinity;
    for (final m in route.maneuvers) {
      if (m.type == 'depart' || m.type == 'arrive') continue;
      final d = RouteGeometry.distanceMeters(pos, m.location);
      if (d < bestD) {
        bestD = d;
        best = m;
      }
    }
    return best ?? route.maneuvers.first;
  }

  int? get remainingMeters {
    final route = activeRoute;
    final pos = userPosition;
    if (route == null) return null;
    if (pos == null) return route.distanceMeters.round();
    final near = RouteGeometry.nearestOnRoute(route.points, pos);
    return RouteGeometry.remainingLengthMeters(route.points, near.index).round();
  }

  int? get remainingSeconds {
    final route = activeRoute;
    if (route == null) return null;
    final total = RouteGeometry.totalLengthMeters(route.points);
    final rem = remainingMeters;
    if (rem == null || total <= 0) return route.durationSeconds.round();
    final ratio = (rem / total).clamp(0.0, 1.0);
    return (route.durationSeconds * ratio).round();
  }

  DateTime? get etaClock {
    final sec = remainingSeconds;
    if (sec == null) return null;
    return DateTime.now().add(Duration(seconds: sec));
  }

  Future<void> start() async {
    if (_disposed) return;
    phase = NavPhase.locating;
    errorMessage = null;
    statusNote =
        'ETA is a road-network estimate only — OSRM has no live Casablanca traffic.';
    notifyListeners();

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      phase = NavPhase.error;
      errorMessage = 'Location services are off. Enable GPS to navigate.';
      notifyListeners();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      phase = NavPhase.error;
      errorMessage = 'Location permission denied.';
      notifyListeners();
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _applyPosition(pos, forceNotify: true);
    } catch (e) {
      phase = NavPhase.error;
      errorMessage = 'Could not get GPS fix: $e';
      notifyListeners();
      return;
    }

    await _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).listen(_onGps, onError: (Object e) {
      statusNote = 'GPS stream error: $e';
      notifyListeners();
    });

    phase = destination == null ? NavPhase.idle : NavPhase.navigating;
    notifyListeners();
  }

  Future<void> stop() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    phase = NavPhase.idle;
  }

  void setFollowCamera(bool value) {
    followCamera = value;
    notifyListeners();
  }

  Future<bool> selectMapDestination(LatLng target) async {
    destination = target;
    destinationLabel = 'Dropped pin';
    selectedRouteIndex = 0;
    return _fetchRoutes(reason: 'map tap');
  }

  Future<bool> selectNamedDestination({
    required String name,
    required LatLng target,
  }) async {
    destination = target;
    destinationLabel = name;
    selectedRouteIndex = 0;
    return _fetchRoutes(reason: 'search');
  }

  Future<bool> selectFavorite(FavoritePlace place) async {
    destination = LatLng(place.latitude, place.longitude);
    destinationLabel = place.name;
    selectedRouteIndex = 0;
    return _fetchRoutes(reason: 'favorite');
  }

  Future<bool> selectRecent(RecentDestination place) async {
    destination = LatLng(place.latitude, place.longitude);
    destinationLabel = place.name;
    selectedRouteIndex = 0;
    return _fetchRoutes(reason: 'recent');
  }

  void selectRouteIndex(int index) {
    final routes = routeResponse?.routes;
    if (routes == null || index < 0 || index >= routes.length) return;
    selectedRouteIndex = index;
    notifyListeners();
  }

  Future<void> clearRoute() async {
    destination = null;
    destinationLabel = null;
    routeResponse = null;
    selectedRouteIndex = 0;
    phase = userPosition == null ? NavPhase.locating : NavPhase.idle;
    statusNote =
        'ETA is a road-network estimate only — OSRM has no live Casablanca traffic.';
    notifyListeners();
  }

  Future<bool> refreshRoute() => _fetchRoutes(reason: 'manual refresh');

  /// Returns true when at least one route was received.
  Future<bool> _fetchRoutes({required String reason}) async {
    final from = userPosition;
    final to = destination;
    if (from == null || to == null) {
      errorMessage = 'Need GPS and a destination to route.';
      phase = NavPhase.error;
      notifyListeners();
      return false;
    }
    if (routingBusy) return false;
    routingBusy = true;
    phase = NavPhase.routing;
    errorMessage = null;
    statusNote = 'Requesting OSRM driving route ($reason)…';
    notifyListeners();

    try {
      final response = await _client.calculateRoutes(from: from, to: to);
      routeResponse = response;
      _lastRouteAt = response.fetchedAt;
      selectedRouteIndex = 0;
      phase = NavPhase.navigating;
      statusNote =
          'Estimate only — no live traffic. OSRM public demo ≤1 req/s.';
      return true;
    } catch (e) {
      phase = NavPhase.error;
      errorMessage = e.toString();
      statusNote = null;
      return false;
    } finally {
      routingBusy = false;
      notifyListeners();
    }
  }

  void _onGps(Position pos) {
    _applyPosition(pos);
    unawaited(_maybeReroute());
  }

  void _applyPosition(Position pos, {bool forceNotify = false}) {
    userPosition = LatLng(pos.latitude, pos.longitude);
    if (pos.heading >= 0 && pos.speed > 0.8) {
      userHeading = pos.heading;
    } else if (activeRoute != null && userPosition != null) {
      final near = RouteGeometry.nearestOnRoute(activeRoute!.points, userPosition!);
      final i = near.index;
      if (i < activeRoute!.points.length - 1) {
        userHeading = RouteGeometry.bearingDegrees(
          activeRoute!.points[i],
          activeRoute!.points[i + 1],
        );
      }
    }

    final now = DateTime.now();
    final throttleOk = _lastCameraNotify == null ||
        now.difference(_lastCameraNotify!) > const Duration(milliseconds: 220);
    if (forceNotify || throttleOk) {
      _lastCameraNotify = now;
      notifyListeners();
    }
  }

  Future<void> _maybeReroute() async {
    final route = activeRoute;
    final pos = userPosition;
    if (route == null || pos == null || destination == null || routingBusy) return;

    final near = RouteGeometry.nearestOnRoute(route.points, pos);
    if (near.distanceMeters <= offRouteMeters) return;

    final now = DateTime.now();
    final last = _lastRerouteAttempt ?? _lastRouteAt;
    if (last != null && now.difference(last).inSeconds < minRerouteSeconds) {
      return;
    }
    _lastRerouteAttempt = now;
    await _fetchRoutes(reason: 'off-route');
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    _client.dispose();
    super.dispose();
  }
}
