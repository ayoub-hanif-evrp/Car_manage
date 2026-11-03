import 'navigation_gate.dart';

abstract class NavigationService {
  bool get isAvailable;
  String get statusMessage;
  List<String> get blockers;

  Future<void> prepare();
  Future<void> disposeSession();
}

class OpenMapNavigationService implements NavigationService {
  bool _sessionOpen = false;

  @override
  bool get isAvailable => NavigationGate.canRunPrototype;

  @override
  List<String> get blockers => const [];

  @override
  String get statusMessage =>
      'OpenFreeMap + OSRM prototype (no account). '
      'Live traffic: unavailable. ${NavigationGate.notices.last}';

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
