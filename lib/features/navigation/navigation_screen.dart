import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../favorites/favorites_panel.dart';
import 'darija_voice_player.dart';
import 'navigation_gate.dart';
import 'navigation_map_page.dart';

class NavigationScreen extends StatelessWidget {
  const NavigationScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (NavigationGate.canRunPrototype) {
      return NavigationMapPage(appState: state);
    }
    return _BlockedNavigation(state: state);
  }
}

class _BlockedNavigation extends StatelessWidget {
  const _BlockedNavigation({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final reasons = NavigationGate.blockingReasons;
    final theme = Theme.of(context);
    final voice = state.voice;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Navigation', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(state.navigation.statusMessage, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TomTom key required for live map / routing',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final reason in reasons) ...[
                  Text('• $reason'),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FavoritesPanel(state: state),
        const SizedBox(height: 16),
        Text('Darija voice (later milestone)', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Voice prompts on'),
          value: voice.enabled,
          onChanged: state.setVoiceEnabled,
        ),
        for (final e in DarijaVoicePlayer.requiredClips.entries)
          Text('• ${e.key}.mp3 — ${e.value}'),
        const SizedBox(height: 16),
        const Text(
          'See docs/TOMTOM.md. Provide a free-tier TomTom API key, then rebuild:\n'
          'flutter build apk --release --dart-define=TOMTOM_API_KEY=...',
        ),
      ],
    );
  }
}
