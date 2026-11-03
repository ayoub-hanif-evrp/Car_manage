import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../data/models.dart';

class FavoritesPanel extends StatelessWidget {
  const FavoritesPanel({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Favorite destinations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Saved for later navigation. Coordinates only — no live routing yet.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (state.favorites.isEmpty)
          const Text('No favorites yet. Examples: Home, University.')
        else
          for (final place in state.favorites)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(place.name),
                subtitle: Text(
                  '${place.latitude.toStringAsFixed(5)}, '
                  '${place.longitude.toStringAsFixed(5)}',
                ),
                onTap: () => _edit(context, place: place),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, place),
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, FavoritePlace place) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete favorite?'),
        content: Text(place.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await state.deleteFavorite(place.id);
  }

  Future<void> _edit(BuildContext context, {FavoritePlace? place}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FavoriteEditPage(state: state, place: place),
      ),
    );
  }
}

class FavoriteEditPage extends StatefulWidget {
  const FavoriteEditPage({super.key, required this.state, this.place});

  final AppState state;
  final FavoritePlace? place;

  @override
  State<FavoriteEditPage> createState() => _FavoriteEditPageState();
}

class _FavoriteEditPageState extends State<FavoriteEditPage> {
  final _name = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.place;
    if (p != null) {
      _name.text = p.name;
      _lat.text = p.latitude.toString();
      _lng.text = p.longitude.toString();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final lat = double.tryParse(_lat.text.replaceAll(',', '.'));
    final lng = double.tryParse(_lng.text.replaceAll(',', '.'));
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (lat == null || lat < -90 || lat > 90) {
      setState(() => _error = 'Latitude must be between -90 and 90');
      return;
    }
    if (lng == null || lng < -180 || lng > 180) {
      setState(() => _error = 'Longitude must be between -180 and 180');
      return;
    }

    final existing = widget.place;
    await widget.state.saveFavorite(
      FavoritePlace(
        id: existing?.id ?? 0,
        name: name,
        latitude: lat,
        longitude: lng,
      ),
      isNew: existing == null,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.place == null;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'Add favorite' : 'Edit favorite')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Home, University…',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          TextField(
            controller: _lat,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Latitude',
              hintText: 'e.g. 33.5731',
            ),
          ),
          TextField(
            controller: _lng,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Longitude',
              hintText: 'e.g. -7.5898',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
