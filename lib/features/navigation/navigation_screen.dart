import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import 'darija_voice_player.dart';
import 'navigation_gate.dart';
import 'navigation_map_page.dart';

class NavigationScreen extends StatelessWidget {
  const NavigationScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    // MapLibre page owns GPS; keep a thin banner of honesty above via the map HUD.
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              NavigationGate.notices.join(' '),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
        Expanded(child: NavigationMapPage(appState: state)),
        // Darija clips remain checklist-only until wired to OSRM maneuvers.
        ExpansionTile(
          title: const Text('Darija clips (later)'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (final e in DarijaVoicePlayer.requiredClips.entries)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('• ${e.key}.mp3 — ${e.value}'),
              ),
          ],
        ),
      ],
    );
  }
}
