import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';

class FuelScreen extends StatelessWidget {
  const FuelScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoganTheme.stone,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 88),
        children: [
          Text('Fuel', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Monthly spending = sum of amounts paid that month. '
            'Consumption uses full-to-full intervals only.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: LoganTheme.muted,
                ),
          ),
          const SizedBox(height: 14),
          if (state.fuelEntries.isEmpty)
            Text(
              'No fuel entries yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: LoganTheme.muted,
                  ),
            )
          else
            for (final e in state.fuelEntries)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: LoganTheme.paper,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  title: Text(
                    '${formatDate(e.date)} · ${formatLiters(e.liters)} · ${formatDh(e.totalPaidDh)}',
                  ),
                  subtitle: Text(
                    '${formatKm(e.odometerKm)} · ${e.dhPerLiter.toStringAsFixed(2)} DH/L'
                    '${e.isFullTank ? ' · Plein' : ''}'
                    '${e.station == null || e.station!.isEmpty ? '' : ' · ${e.station}'}',
                  ),
                  onTap: () => _openForm(context, existing: e),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, e),
                  ),
                ),
              ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        backgroundColor: LoganTheme.accent,
        foregroundColor: LoganTheme.paper,
        icon: const Icon(Icons.local_gas_station),
        label: const Text('Add fuel'),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, FuelEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete fuel entry?'),
        content: Text('${formatDate(e.date)} · ${formatDh(e.totalPaidDh)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await state.deleteFuel(e.id);
  }

  Future<void> _openForm(BuildContext context, {FuelEntry? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FuelFormPage(state: state, existing: existing),
      ),
    );
  }
}

class FuelFormPage extends StatefulWidget {
  const FuelFormPage({super.key, required this.state, this.existing});

  final AppState state;
  final FuelEntry? existing;

  @override
  State<FuelFormPage> createState() => _FuelFormPageState();
}

class _FuelFormPageState extends State<FuelFormPage> {
  late DateTime _date;
  final _liters = TextEditingController();
  final _paid = TextEditingController();
  final _odometer = TextEditingController();
  final _station = TextEditingController();
  // Spec: default true only if owner confirms plein habit — keep false until then.
  bool _fullTank = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? DateTime.now();
    if (e != null) {
      _liters.text = e.liters.toString();
      _paid.text = e.totalPaidDh.toString();
      _odometer.text = e.odometerKm.toStringAsFixed(0);
      _station.text = e.station ?? '';
      _fullTank = e.isFullTank;
    }
  }

  @override
  void dispose() {
    _liters.dispose();
    _paid.dispose();
    _odometer.dispose();
    _station.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final liters = double.tryParse(_liters.text.replaceAll(',', '.'));
    final paid = double.tryParse(_paid.text.replaceAll(',', '.'));
    final odo = double.tryParse(_odometer.text.replaceAll(',', '.'));
    if (liters == null || liters <= 0) {
      setState(() => _error = 'Liters must be a positive number');
      return;
    }
    if (paid == null || paid < 0) {
      setState(() => _error = 'Total paid must be ≥ 0');
      return;
    }
    if (odo == null) {
      setState(() => _error = 'Odometer is required');
      return;
    }
    final odoError = widget.state.validateFuelOdometer(odo, excludeId: widget.existing?.id);
    if (odoError != null) {
      setState(() => _error = odoError);
      return;
    }

    final entry = FuelEntry(
      id: widget.existing?.id ?? 0,
      date: _date,
      liters: liters,
      totalPaidDh: paid,
      odometerKm: odo,
      isFullTank: _fullTank,
      station: _station.text.trim().isEmpty ? null : _station.text.trim(),
    );
    await widget.state.saveFuel(entry, isNew: widget.existing == null);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final previewDhL = () {
      final liters = double.tryParse(_liters.text.replaceAll(',', '.'));
      final paid = double.tryParse(_paid.text.replaceAll(',', '.'));
      if (liters == null || paid == null || liters <= 0) return '—';
      return '${(paid / liters).toStringAsFixed(2)} DH/L';
    }();

    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Add fuel' : 'Edit fuel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(formatDate(_date)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          TextField(
            controller: _liters,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Liters purchased'),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _paid,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Total paid (DH)'),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _odometer,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Odometer (km)'),
          ),
          TextField(
            controller: _station,
            decoration: const InputDecoration(labelText: 'Station (optional)'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Full tank / Plein'),
            subtitle: const Text('Default off until you confirm this habit'),
            value: _fullTank,
            onChanged: (v) => setState(() => _fullTank = v),
          ),
          Text('Calculated: $previewDhL'),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
