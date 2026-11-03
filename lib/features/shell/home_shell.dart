import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../dashboard/dashboard_screen.dart';
import '../fuel/fuel_screen.dart';
import '../garage/garage_screen.dart';
import '../navigation/navigation_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});

  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _navIndex = 3;

  Future<void> _select(int i) async {
    final leavingNav = _index == _navIndex && i != _navIndex;
    final enteringNav = _index != _navIndex && i == _navIndex;
    if (leavingNav) {
      await widget.state.navigation.disposeSession();
    }
    if (enteringNav) {
      await widget.state.navigation.prepare();
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final pages = [
      DashboardScreen(state: state),
      FuelScreen(state: state),
      GarageScreen(state: state),
      NavigationScreen(state: state),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_gas_station_outlined),
            label: 'Fuel',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            label: 'Garage',
          ),
          NavigationDestination(
            icon: Icon(Icons.navigation_outlined),
            label: 'Navigation',
          ),
        ],
      ),
    );
  }
}
