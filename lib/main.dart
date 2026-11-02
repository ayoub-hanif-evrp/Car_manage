import 'package:flutter/material.dart';

void main() {
  runApp(const MyLoganApp());
}

/// Milestone 0 placeholder only. No navigation SDK or car features yet.
class MyLoganApp extends StatelessWidget {
  const MyLoganApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Logan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B4D3E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MilestoneZeroScreen(),
    );
  }
}

class MilestoneZeroScreen extends StatelessWidget {
  const MilestoneZeroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Logan', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Personal car companion for a Dacia Logan in Morocco.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Text('Milestone 0', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Project skeleton and feasibility only.\n'
                'Navigation, fuel, garage, and dashboard are not implemented yet.',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
