import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../reminders/reminders_panel.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final month = state.dashboardMonth;
    final fuel = state.monthFuelSpend(month);
    final repairs = state.monthRepairSpend(month);
    final total = fuel + repairs;
    final fuelings = state.monthFuelCount(month);
    final consumption = state.consumption;
    final months = state.lastMonths();
    final maxBar = months
        .map((m) => m.fuel + m.repairs)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final recent = state.recentTransactions();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed: () => state.shiftDashboardMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                formatMonth(month),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: () => state.shiftDashboardMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        _StatCard(
          title: 'This month total',
          value: formatDh(total),
          detail: 'Fuel ${formatDh(fuel)} · Repairs ${formatDh(repairs)} · '
              '$fuelings fueling${fuelings == 1 ? '' : 's'}',
        ),
        const SizedBox(height: 8),
        _StatCard(
          title: 'All-time spending',
          value: formatDh(state.lifetimeSpend),
          detail: 'Fuel purchases + repair entries only',
        ),
        const SizedBox(height: 8),
        _StatCard(
          title: 'Latest odometer (manual)',
          value: state.latestOdometer == null
              ? 'No reading yet'
              : formatKm(state.latestOdometer!),
          detail: 'Not a live vehicle reading',
        ),
        const SizedBox(height: 8),
        _StatCard(
          title: 'Fuel consumption',
          value: consumption.hasReliableData
              ? formatLPer100(consumption.averageLitersPer100Km)
              : 'Not enough data',
          detail: consumption.hasReliableData
              ? 'Cost/km: ${formatCostPerKm(consumption.averageCostPerKm)} '
                  '(full-to-full estimate)'
              : 'Needs two successive full-tank (Plein) records with valid odometer.',
        ),
        const SizedBox(height: 16),
        Text('Last 6 months', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in months)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: _MonthBar(
                              fuel: m.fuel,
                              repairs: m.repairs,
                              maxTotal: maxBar <= 0 ? 1 : maxBar,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.month.month.toString().padLeft(2, '0'),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Green = fuel · Brown = repairs',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 16),
        Text('Reminders', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        RemindersPanel(state: state),
        const SizedBox(height: 16),
        Text('Recent transactions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          const Text('No transactions yet.')
        else
          for (final t in recent)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(t.isFuel ? Icons.local_gas_station : Icons.build),
              title: Text(t.label),
              subtitle: Text(formatDate(t.date)),
              trailing: Text(formatDh(t.amountDh)),
            ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.fuel,
    required this.repairs,
    required this.maxTotal,
  });

  final double fuel;
  final double repairs;
  final double maxTotal;

  @override
  Widget build(BuildContext context) {
    final total = fuel + repairs;
    final height = 100 * (total / maxTotal);
    final fuelH = total <= 0 ? 0.0 : height * (fuel / total);
    final repairH = total <= 0 ? 0.0 : height * (repairs / total);
    return SizedBox(
      height: height.clamp(2, 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(height: repairH, color: const Color(0xFF8B5E3C)),
          Container(height: fuelH, color: const Color(0xFF1B4D3E)),
        ],
      ),
    );
  }
}
