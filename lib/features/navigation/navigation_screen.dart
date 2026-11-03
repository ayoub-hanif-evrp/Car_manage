import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import 'navigation_map_page.dart';

class NavigationScreen extends StatelessWidget {
  const NavigationScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    // Full-bleed map + plan/drive HUD. Traffic honesty lives in the HUD.
    return NavigationMapPage(appState: state);
  }
}
