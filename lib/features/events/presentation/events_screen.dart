import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/dialog_text_controller_owner.dart';
import '../../community/data/society_repository.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({
    required this.societyId,
    required this.isAdmin,
    super.key,
  });
  final String societyId;
  final bool isAdmin;

  Future<void> _editEvent(BuildContext context,
      [Map<String, dynamic>? event]) async {
    final formKey = GlobalKey<FormState>();
    final timestamp = event?['startAt'];
    var startAt = timestamp == null
        ? DateTime.now().add(const Duration(days: 1))
        : timestamp.toDate() as DateTime;
    var category = event?['category'] as String? ?? 'Meeting';
    var busy = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DialogTextControllerOwner(
        count: 3,
        initialValues: [
          event?['title'] as String? ?? '',
          event?['description'] as String? ?? '',
          event?['location'] as String? ?? '',
        ],
        builder: (context, controllers) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(event == null ? 'Create an event' : 'Edit event'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: controllers[0],
                      maxLength: 100,
                      decoration:
                          const InputDecoration(labelText: 'Event name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter an event name.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        'Meeting',
                        'Festival',
                        'Community',
                        'Maintenance',
                        'Other'
                      ]
                          .map((value) => DropdownMenuItem(
                              value: value, child: Text(value)))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => category = value!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers[2],
                      decoration: const InputDecoration(labelText: 'Location'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter a location.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers[1],
                      maxLines: 4,
                      maxLength: 1200,
                      decoration: const InputDecoration(
                          labelText: 'Details (optional)'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final selected = await showDatePicker(
                                context: context,
                                initialDate: startAt.isBefore(DateTime.now())
                                    ? DateTime.now()
                                    : startAt,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365 * 5)),
                              );
                              if (selected != null) {
                                setDialogState(() {
                                  startAt = DateTime(
                                      selected.year,
                                      selected.month,
                                      selected.day,
                                      startAt.hour,
                                      startAt.minute);
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(MaterialLocalizations.of(context)
                                .formatShortDate(startAt)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final selected = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(startAt),
                            );
                            if (selected != null) {
                              setDialogState(() {
                                startAt = DateTime(
                                    startAt.year,
                                    startAt.month,
                                    startAt.day,
                                    selected.hour,
                                    selected.minute);
                              });
                            }
                          },
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text(
                              TimeOfDay.fromDateTime(startAt).format(context)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed:
                      busy ? null : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        if (!startAt.isAfter(DateTime.now())) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Choose a future date and time.')));
                          return;
                        }
                        setDialogState(() => busy = true);
                        try {
                          await societyRepository.saveEvent(
                            eventId: event?['id'] as String?,
                            societyId: societyId,
                            adminId: FirebaseAuth.instance.currentUser!.uid,
                            title: controllers[0].text,
                            description: controllers[1].text,
                            location: controllers[2].text,
                            category: category,
                            startAt: startAt,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } on SocietyDataException catch (error) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(error.message)));
                            setDialogState(() => busy = false);
                          }
                        }
                      },
                child: Text(event == null ? 'Publish' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(event == null ? 'Event published.' : 'Event updated.')));
    }
  }

  Future<void> _removeEvent(BuildContext context, String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this event?'),
        content:
            const Text('Residents will no longer see it in the events list.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await societyRepository.deactivateEvent(
        eventId: eventId,
        societyId: societyId,
        adminId: FirebaseAuth.instance.currentUser!.uid,
      );
    } on SocietyDataException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Events and meetings')),
        floatingActionButton: isAdmin
            ? FloatingActionButton.extended(
                onPressed: () => _editEvent(context),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('New event'),
              )
            : null,
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: societyRepository.watchEvents(societyId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _Empty(
                  message:
                      'Could not load events. Check your connection and Firestore permissions.');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final events = isAdmin
                ? snapshot.data!
                : snapshot.data!
                    .where(
                        (event) => _eventStart(event).isAfter(DateTime.now()))
                    .toList();
            if (events.isEmpty) {
              return const _Empty(message: 'No events are scheduled yet.');
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final event = events[index];
                final startAt = _eventStart(event);
                return Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    leading: Container(
                      width: 54,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                              MaterialLocalizations.of(context)
                                  .formatShortMonthDay(startAt),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(TimeOfDay.fromDateTime(startAt).format(context),
                              style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                    ),
                    title: Text(event['title'] as String? ?? 'Event',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                          '${event['category'] ?? 'Event'} • ${event['location'] ?? ''}${(event['description'] as String? ?? '').isEmpty ? '' : '\n${event['description']}'}'),
                    ),
                    isThreeLine: true,
                    trailing: isAdmin
                        ? PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editEvent(context, event);
                              }
                              if (value == 'remove') {
                                _removeEvent(context, event['id'] as String);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                  value: 'remove', child: Text('Remove')),
                            ],
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      );
}

DateTime _eventStart(Map<String, dynamic> event) {
  final value = event['startAt'];
  return value is DateTime ? value : (value as dynamic).toDate() as DateTime;
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}
