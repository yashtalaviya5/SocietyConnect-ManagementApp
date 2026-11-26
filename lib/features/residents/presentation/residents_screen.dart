import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../community/data/society_repository.dart';

class ResidentsScreen extends StatefulWidget {
  const ResidentsScreen({required this.societyId, super.key});
  final String societyId;

  @override
  State<ResidentsScreen> createState() => _ResidentsScreenState();
}

class _ResidentsScreenState extends State<ResidentsScreen> {
  String _search = '';

  Future<void> _assignFlat(Map<String, dynamic> resident) async {
    try {
      final flats = await societyRepository.listVacantFlats(widget.societyId);
      if (!mounted) return;
      if (flats.isEmpty) {
        _show('No vacant flats are available.');
        return;
      }
      var selected = flats.first['id'] as String;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Assign a flat to ${resident['fullName']}'),
            content: DropdownButtonFormField<String>(
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'Vacant flat'),
              items: flats
                  .map((flat) => DropdownMenuItem(
                        value: flat['id'] as String,
                        child: Text('Flat ${flat['flatNumber']}'),
                      ))
                  .toList(),
              onChanged: (value) => setDialogState(() => selected = value!),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Assign'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
      await societyRepository.assignResidentFlat(
        societyId: widget.societyId,
        residentId: resident['id'] as String,
        flatId: selected,
        adminId: FirebaseAuth.instance.currentUser!.uid,
      );
      if (mounted) _show('Flat assignment updated.');
    } on SocietyDataException catch (error) {
      if (mounted) _show(error.message);
    }
  }

  Future<void> _unassignFlat(Map<String, dynamic> resident) async {
    try {
      await societyRepository.unassignResidentFlat(
        societyId: widget.societyId,
        residentId: resident['id'] as String,
        adminId: FirebaseAuth.instance.currentUser!.uid,
      );
      if (mounted) _show('Flat unassigned.');
    } on SocietyDataException catch (error) {
      if (mounted) _show(error.message);
    }
  }

  Future<void> _setActive(Map<String, dynamic> resident, bool active) async {
    try {
      await societyRepository.setResidentActive(
        residentId: resident['id'] as String,
        societyId: widget.societyId,
        adminId: FirebaseAuth.instance.currentUser!.uid,
        isActive: active,
      );
      if (mounted) {
        _show(active
            ? 'Resident account activated.'
            : 'Resident account deactivated.');
      }
    } on SocietyDataException catch (error) {
      if (mounted) _show(error.message);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Residents')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: TextField(
                onChanged: (value) =>
                    setState(() => _search = value.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search by name, flat, email or mobile',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: societyRepository.watchResidents(widget.societyId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text(
                            'Could not load residents. Check your connection and Firestore permissions.'),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final residents = snapshot.data!.where((resident) {
                    final values = [
                      resident['fullName'],
                      resident['email'],
                      resident['mobile'],
                      resident['flatNumber'],
                    ].whereType<String>().join(' ').toLowerCase();
                    return values.contains(_search);
                  }).toList();
                  if (residents.isEmpty) {
                    return Center(
                      child: Text(_search.isEmpty
                          ? 'No residents are registered yet.'
                          : 'No residents match your search.'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    itemCount: residents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final resident = residents[index];
                      final active = resident['isActive'] == true;
                      final flatNumber = resident['flatNumber'] as String?;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text((resident['fullName'] as String? ?? '?')
                                .characters
                                .first
                                .toUpperCase()),
                          ),
                          title: Text(
                              resident['fullName'] as String? ?? 'Resident'),
                          subtitle: Text([
                            resident['email'] as String? ?? '',
                            if ((resident['mobile'] as String? ?? '')
                                .isNotEmpty)
                              resident['mobile'],
                            if (flatNumber != null && flatNumber.isNotEmpty)
                              'Flat $flatNumber',
                            if (!active) 'Account inactive',
                          ].where((value) => value.isNotEmpty).join('  •  ')),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) {
                              switch (action) {
                                case 'assign':
                                  _assignFlat(resident);
                                  break;
                                case 'unassign':
                                  _unassignFlat(resident);
                                  break;
                                case 'activate':
                                  _setActive(resident, true);
                                  break;
                                case 'deactivate':
                                  _setActive(resident, false);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'assign',
                                child: Text(flatNumber == null
                                    ? 'Assign flat'
                                    : 'Change flat'),
                              ),
                              if (flatNumber != null)
                                const PopupMenuItem(
                                    value: 'unassign',
                                    child: Text('Unassign flat')),
                              PopupMenuItem(
                                value: active ? 'deactivate' : 'activate',
                                child: Text(active
                                    ? 'Deactivate account'
                                    : 'Activate account'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
}
