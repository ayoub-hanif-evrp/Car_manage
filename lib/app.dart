import 'package:flutter/material.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'features/shell/home_shell.dart';

class MyLoganApp extends StatelessWidget {
  const MyLoganApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Logan',
      debugShowCheckedModeBanner: false,
      theme: LoganTheme.light(),
      home: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          if (state.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (state.error != null) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Startup error: ${state.error}'),
                ),
              ),
            );
          }
          return HomeShell(state: state);
        },
      ),
    );
  }
}
