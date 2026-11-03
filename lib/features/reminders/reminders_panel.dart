import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../data/models.dart';

class RemindersPanel extends StatelessWidget {
  const RemindersPanel({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final odo = state.latestOdometer;

    return Column(
      children: [
        for (final r in state.reminders)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(r.kind.labelFr),
              subtitle: Text(_subtitle(r, today, odo)),
              trailing: Text(
                _statusLabel(r.status(today: today, latestOdometerKm: odo)),
              ),
              onTap: () => _edit(context, r),
            ),
          ),
      ],
    );
  }

  String _subtitle(ReminderEntry r, DateTime today, double? odo) {
    final parts = <String>[];
    if (r.dueDate != null) parts.add('Due ${formatDate(r.dueDate!)}');
    if (r.dueOdometerKm != null) {
      parts.add('At ${formatKm(r.dueOdometerKm!)}');
    }
    if (r.intervalMonths != null) {
      parts.add('Every ${r.intervalMonths} mo');
    }
    if (r.intervalKm != null) {
      parts.add('Every ${r.intervalKm!.toStringAsFixed(0)} km');
    }
    if (parts.isEmpty) return 'Not configured';
    return parts.join(' · ');
  }

  String _statusLabel(ReminderStatus s) => switch (s) {
        ReminderStatus.upcoming => 'Upcoming',
        ReminderStatus.due => 'Due',
        ReminderStatus.overdue => 'Overdue',
      };

  Future<void> _edit(BuildContext context, ReminderEntry r) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReminderEditPage(state: state, entry: r),
      ),
    );
  }
}

class ReminderEditPage extends StatefulWidget {
  const ReminderEditPage({super.key, required this.state, required this.entry});

  final AppState state;
  final ReminderEntry entry;

  @override
  State<ReminderEditPage> createState() => _ReminderEditPageState();
}

class _ReminderEditPageState extends State<ReminderEditPage> {
  DateTime? _dueDate;
  final _dueOdo = TextEditingController();
  final _lead = TextEditingController();
  final _intervalMonths = TextEditingController();
  final _intervalKm = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dueDate = widget.entry.dueDate;
    if (widget.entry.dueOdometerKm != null) {
      _dueOdo.text = widget.entry.dueOdometerKm!.toStringAsFixed(0);
    }
    _lead.text = widget.entry.leadDays.toString();
    if (widget.entry.intervalMonths != null) {
      _intervalMonths.text = widget.entry.intervalMonths.toString();
    }
    if (widget.entry.intervalKm != null) {
      _intervalKm.text = widget.entry.intervalKm!.toStringAsFixed(0);
    }
    _notes.text = widget.entry.notes ?? '';
  }

  @override
  void dispose() {
    _dueOdo.dispose();
    _lead.dispose();
    _intervalMonths.dispose();
    _intervalKm.dispose();
    _notes.dispose();
    super.dispose();
  }

  ReminderEntry _buildEntry({bool markRenewed = false}) {
    final lead = int.tryParse(_lead.text) ?? 7;
    final dueOdo = _dueOdo.text.trim().isEmpty
        ? null
        : double.tryParse(_dueOdo.text.replaceAll(',', '.'));
    final intervalMonths = _intervalMonths.text.trim().isEmpty
        ? null
        : int.tryParse(_intervalMonths.text);
    final intervalKm = _intervalKm.text.trim().isEmpty
        ? null
        : double.tryParse(_intervalKm.text.replaceAll(',', '.'));

    final base = ReminderEntry(
      id: widget.entry.id,
      kind: widget.entry.kind,
      dueDate: _dueDate,
      dueOdometerKm: dueOdo,
      lastCompletedDate: widget.entry.lastCompletedDate,
      lastCompletedOdometerKm: widget.entry.lastCompletedOdometerKm,
      leadDays: lead < 0 ? 0 : lead,
      intervalMonths: intervalMonths != null && intervalMonths > 0
          ? intervalMonths
          : null,
      intervalKm: intervalKm != null && intervalKm > 0 ? intervalKm : null,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );

    if (!markRenewed) return base;
    return base.renew(
      completedAt: DateTime.now(),
      completedOdometerKm: widget.state.latestOdometer,
    );
  }

  Future<void> _save({bool markRenewed = false}) async {
    await widget.state.saveReminder(_buildEntry(markRenewed: markRenewed));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final last = widget.entry;
    return Scaffold(
      appBar: AppBar(title: Text(widget.entry.kind.labelFr)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (last.lastCompletedDate != null ||
              last.lastCompletedOdometerKm != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Last done: '
                '${last.lastCompletedDate == null ? '—' : formatDate(last.lastCompletedDate!)}'
                '${last.lastCompletedOdometerKm == null ? '' : ' · ${formatKm(last.lastCompletedOdometerKm!)}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Due date'),
            subtitle: Text(_dueDate == null ? 'Not set' : formatDate(_dueDate!)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_dueDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
                const Icon(Icons.calendar_today),
              ],
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dueDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
          ),
          if (widget.entry.kind == ReminderKind.oilChange) ...[
            TextField(
              controller: _dueOdo,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Due odometer (km, optional)',
              ),
            ),
            TextField(
              controller: _intervalMonths,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Interval months (optional)',
                helperText: 'Used when you mark renewed',
              ),
            ),
            TextField(
              controller: _intervalKm,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Interval km (optional)',
                helperText: 'Added to current odometer on renew',
              ),
            ),
          ],
          TextField(
            controller: _lead,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Notify lead days'),
          ),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => _save(), child: const Text('Save')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _save(markRenewed: true),
            child: const Text('Mark renewed / completed'),
          ),
          const SizedBox(height: 8),
          Text(
            'Renew sets last-done to now (and latest odometer for oil). '
            'If an interval is set, the next due is calculated automatically; '
            'otherwise due fields are cleared so you can set the next target.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
