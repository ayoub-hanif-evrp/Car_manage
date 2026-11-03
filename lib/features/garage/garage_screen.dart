import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../data/models.dart';

class GarageScreen extends StatelessWidget {
  const GarageScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthTotal = state.monthRepairSpend(DateTime(now.year, now.month));
    final lifetime = state.repairs.fold<double>(0, (s, e) => s + e.totalPriceDh);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          Text('Garage', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('This month: ${formatDh(monthTotal)} · All time: ${formatDh(lifetime)}'),
          const SizedBox(height: 12),
          if (state.repairs.isEmpty)
            const Text('No repairs yet.')
          else
            for (final e in state.repairs)
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(e.description),
                  subtitle: Text('${formatDate(e.date)} · ${formatDh(e.totalPriceDh)}'),
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
        icon: const Icon(Icons.build),
        label: const Text('Add repair'),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, RepairEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete repair?'),
        content: Text(e.description),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await state.deleteRepair(e.id);
  }

  Future<void> _openForm(BuildContext context, {RepairEntry? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RepairFormPage(state: state, existing: existing),
      ),
    );
  }
}

class RepairFormPage extends StatefulWidget {
  const RepairFormPage({super.key, required this.state, this.existing});

  final AppState state;
  final RepairEntry? existing;

  @override
  State<RepairFormPage> createState() => _RepairFormPageState();
}

class _RepairFormPageState extends State<RepairFormPage> {
  late DateTime _date;
  final _description = TextEditingController();
  final _price = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? DateTime.now();
    if (e != null) {
      _description.text = e.description;
      _price.text = e.totalPriceDh.toString();
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final desc = _description.text.trim();
    final price = double.tryParse(_price.text.replaceAll(',', '.'));
    if (desc.isEmpty) {
      setState(() => _error = 'Description is required');
      return;
    }
    if (price == null || price < 0) {
      setState(() => _error = 'Price must be ≥ 0');
      return;
    }
    await widget.state.saveRepair(
      RepairEntry(
        id: widget.existing?.id ?? 0,
        date: _date,
        description: desc,
        totalPriceDh: price,
      ),
      isNew: widget.existing == null,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Add repair' : 'Edit repair')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(formatDate(_date)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          TextField(
            controller: _description,
            decoration: const InputDecoration(
              labelText: 'Cause / short description',
              hintText: 'Plaquettes de frein',
            ),
          ),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Total price (DH)'),
          ),
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
