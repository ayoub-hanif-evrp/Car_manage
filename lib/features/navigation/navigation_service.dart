import 'navigation_gate.dart';

/// Navigation provider abstraction (spec §8).
abstract class NavigationService {
  bool get isAvailable;
  String get statusMessage;
  List<String> get blockers;

  Future<void> prepare();
  Future<void> disposeSession();
}

/// TomTom-backed gate: map/GPS session is owned by [NavigationMapPage].
class TomTomNavigationService implements NavigationService {
  bool _sessionOpen = false;

  @override
  bool get isAvailable => NavigationGate.canRunPrototype;

  @override
  List<String> get blockers => NavigationGate.blockingReasons;

  @override
  String get statusMessage {
    if (!NavigationGate.hasApiKey) {
      return 'TomTom navigation is ready in code, but needs TOMTOM_API_KEY.';
    }
    return 'TomTom prototype: raster map, GPS, Morocco search, '
        'traffic-aware fastest route + alternatives. '
        'Not a full native Navigation SDK — verify ETA on the A02.';
  }

  @override
  Future<void> prepare() async {
    _sessionOpen = true;
  }

  @override
  Future<void> disposeSession() async {
    _sessionOpen = false;
  }

  bool get sessionOpen => _sessionOpen;
}
