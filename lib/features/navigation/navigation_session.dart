import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'route_geometry.dart';
import 'tomtom_api_client.dart';
import 'tomtom_models.dart';

enum NavPhase { idle, locating, searching, routing, navigating, error }

/// Live TomTom navigation session (map + GPS + traffic routes).
/// Resources are created only while the Navigation tab is active.
class NavigationSession extends ChangeNotifier {
  NavigationSession({TomTomApiClient? client}) : _client = client ?? TomTomApiClient();

  final TomTomApiClient _client;

  NavPhase phase = NavPhase.idle;
  String? errorMessage;
  String? statusNote;

  LatLng? userPosition;
  double? userHeading;
  bool followCamera = true;

  List<TomTomSearchResult> searchResults = const [];
  TomTomSearchResult? destination;
  TomTomRouteResponse? routeResponse;
  int selectedRouteIndex = 0;
  bool routingBusy = false;

  DateTime? _lastRouteAt;
  DateTime? _lastRerouteAttempt;
  DateTime? _lastCameraNotify;
  StreamSubscription<Position>? _gpsSub;
  Timer? _searchDebounce;
  bool _disposed = false;

  static const offRouteMeters = 45.0;
  static const minRerouteSeconds = 20;
  static const trafficRefreshMinutes = 3;

  TomTomRouteOption? get activeRoute {
    final routes = routeResponse?.routes;
    if (routes == null || routes.isEmpty) return null;
    final i = selectedRouteIndex.clamp(0, routes.length - 1);
    return routes[i];
  }

  int? get remainingMeters {
    final route = activeRoute;
    final pos = userPosition;
    if (route == null || pos == null) return route?.lengthInMeters;
    final near = RouteGeometry.nearestOnRoute(route.points, pos);
    return RouteGeometry.remainingLengthMeters(route.points, near.index).round();
  }

  int? get remainingSeconds {
    final route = activeRoute;
    if (route == null) return null;
    final total = RouteGeometry.totalLengthMeters(route.points);
    final rem = remainingMeters;
    if (rem == null || total <= 0) return route.travelTimeInSeconds;
    final ratio = (rem / total).clamp(0.0, 1.0);
    return (route.travelTimeInSeconds * ratio).round();
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
    statusNote = null;
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
    _searchDebounce?.cancel();
    phase = NavPhase.idle;
  }

  void setFollowCamera(bool value) {
    followCamera = value;
    notifyListeners();
  }

  void scheduleSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_runSearch(query));
    });
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().length < 2) {
      searchResults = const [];
      notifyListeners();
      return;
    }
    phase = NavPhase.searching;
    notifyListeners();
    try {
      searchResults = await _client.searchMorocco(query);
      errorMessage = null;
    } catch (e) {
      searchResults = const [];
      errorMessage = e.toString();
    }
    if (destination == null) phase = NavPhase.idle;
    notifyListeners();
  }

  Future<void> selectDestination(TomTomSearchResult result) async {
    destination = result;
    searchResults = const [];
    selectedRouteIndex = 0;
    await _fetchRoutes(reason: 'destination');
  }

  Future<void> selectFavorite(LatLng target, String name) async {
    destination = TomTomSearchResult(
      id: 'favorite:$name',
      title: name,
      subtitle: 'Favorite',
      position: target,
    );
    selectedRouteIndex = 0;
    await _fetchRoutes(reason: 'favorite');
  }

  void selectRouteIndex(int index) {
    final routes = routeResponse?.routes;
    if (routes == null || index < 0 || index >= routes.length) return;
    selectedRouteIndex = index;
    notifyListeners();
  }

  Future<void> clearRoute() async {
    destination = null;
    routeResponse = null;
    selectedRouteIndex = 0;
    phase = userPosition == null ? NavPhase.locating : NavPhase.idle;
    statusNote = null;
    notifyListeners();
  }

  Future<void> refreshRoute() => _fetchRoutes(reason: 'manual refresh');

  Future<void> _fetchRoutes({required String reason}) async {
    final from = userPosition;
    final to = destination?.position;
    if (from == null || to == null) {
      errorMessage = 'Need GPS and a destination to route.';
      phase = NavPhase.error;
      notifyListeners();
      return;
    }
    if (routingBusy) return;
    routingBusy = true;
    phase = NavPhase.routing;
    errorMessage = null;
    statusNote = 'Requesting TomTom traffic-aware route ($reason)…';
    notifyListeners();

    try {
      final response = await _client.calculateRoutes(from: from, to: to);
      routeResponse = response;
      _lastRouteAt = response.fetchedAt;
      selectedRouteIndex = 0;
      phase = NavPhase.navigating;
      final best = response.routes.first;
      statusNote = best.hasLiveTrafficSignal
          ? 'TomTom route with traffic delay ${best.trafficDelayInSeconds}s '
              '(fetched ${response.fetchedAt.toLocal()})'
          : 'TomTom route returned; traffic delay field is 0s right now '
              '(live vs no-traffic times still shown when API provides them). '
              'Verify congestion effect on a Casablanca drive.';
    } catch (e) {
      phase = NavPhase.error;
      errorMessage = e.toString();
      statusNote = null;
    } finally {
      routingBusy = false;
      notifyListeners();
    }
  }

  void _onGps(Position pos) {
    _applyPosition(pos);
    unawaited(_maybeRerouteOrRefresh());
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

  Future<void> _maybeRerouteOrRefresh() async {
    final route = activeRoute;
    final pos = userPosition;
    if (route == null || pos == null || destination == null || routingBusy) return;

    final near = RouteGeometry.nearestOnRoute(route.points, pos);
    final now = DateTime.now();

    if (near.distanceMeters > offRouteMeters) {
      final last = _lastRerouteAttempt;
      if (last == null || now.difference(last).inSeconds >= minRerouteSeconds) {
        _lastRerouteAttempt = now;
        await _fetchRoutes(reason: 'off-route');
      }
      return;
    }

    final lastRoute = _lastRouteAt;
    if (lastRoute != null &&
        now.difference(lastRoute).inMinutes >= trafficRefreshMinutes) {
      await _fetchRoutes(reason: 'traffic refresh');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    unawaited(stop());
    _client.dispose();
    super.dispose();
  }
}
