import 'tomtom_config.dart';

/// Gates for TomTom navigation prototype.
/// Live claims require a key + on-device Casablanca verification.
class NavigationGate {
  NavigationGate._();

  /// Official pricing lists free monthly quotas (no card to start).
  /// Pay-as-you-grow overage is NOT enabled without owner permission.
  static const bool freeTierDocumented = true;

  /// TomTom consumer traffic coverage lists Morocco; developer Routing uses
  /// traffic=true. Casablanca ETA quality still needs a release-drive proof.
  static const bool moroccoTrafficListedByTomTom = true;

  /// Set true only after a release-build A02 drive test passes.
  static const bool galaxyA02PerformanceVerified = false;

  static bool get hasApiKey => TomTomConfig.hasApiKey;

  static bool get canRunPrototype => hasApiKey && freeTierDocumented;

  static List<String> get blockingReasons {
    final reasons = <String>[];
    if (!hasApiKey) {
      reasons.add(
        'No TomTom API key. Build/run with '
        '--dart-define=TOMTOM_API_KEY=your_key (never commit the key).',
      );
    }
    if (!galaxyA02PerformanceVerified) {
      reasons.add(
        'Galaxy A02 release-build navigation performance has not been '
        'verified on a real Casablanca drive yet.',
      );
    }
    return reasons;
  }
}
