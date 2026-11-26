import 'package:flutter/material.dart';

import '../../../features/community/data/society_repository.dart';

class FlatsScreen extends StatelessWidget {
  const FlatsScreen({required this.societyId, super.key});
  final String societyId;

  Future<void> _addFlat(BuildContext context) async {
    final details = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _AddFlatDialog(),
    );
    if (details != null && context.mounted) {
      try {
        await societyRepository.createFlat(
          societyId: societyId,
          flatNumber: details['flatNumber']!,
          block: details['block']!,
          floor: details['floor']!,
        );
        if (!context.mounted) return;
        _message(context, 'Flat added.');
      } on SocietyDataException catch (error) {
        if (context.mounted) _message(context, error.message);
      }
    }
  }

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Flat management')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addFlat(context),
          icon: const Icon(Icons.add_home_work_outlined),
          label: const Text('Add flat'),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: societyRepository.watchFlats(societyId),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const _LoadError();
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final flats = snapshot.data!;
            if (flats.isEmpty) {
              return const _EmptyState(
                icon: Icons.apartment_outlined,
                title: 'No flats yet',
                message:
                    'Add flats so residents can join using their Society ID.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: flats.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final flat = flats[index];
                final occupied = flat['status'] == 'Occupied';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: occupied
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.door_front_door_outlined),
                    ),
                    title: Text('Flat ${flat['flatNumber'] ?? ''}'),
                    subtitle: Text([
                      if ((flat['block'] as String? ?? '').isNotEmpty)
                        'Block ${flat['block']}',
                      if ((flat['floor'] as String? ?? '').isNotEmpty)
                        'Floor ${flat['floor']}',
                    ].join('  •  ')),
                    trailing: Chip(
                      label: Text(occupied ? 'Occupied' : 'Vacant'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

class _AddFlatDialog extends StatefulWidget {
  const _AddFlatDialog();

  @override
  State<_AddFlatDialog> createState() => _AddFlatDialogState();
}

class _AddFlatDialogState extends State<_AddFlatDialog> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _block = TextEditingController();
  final _floor = TextEditingController();

  @override
  void dispose() {
    _number.dispose();
    _block.dispose();
    _floor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add a flat'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _number,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Flat number'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a flat number.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _block,
                decoration:
                    const InputDecoration(labelText: 'Block (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _floor,
                decoration:
                    const InputDecoration(labelText: 'Floor (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(context, {
                'flatNumber': _number.text,
                'block': _block.text,
                'floor': _floor.text,
              });
            },
            child: const Text('Add flat'),
          ),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 42, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
              'Could not load flats. Check your connection and Firestore permissions.'),
        ),
      );
}
