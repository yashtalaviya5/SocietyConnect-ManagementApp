import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/dialog_text_controller_owner.dart';
import '../../community/data/society_repository.dart';

class AmenityRequestsScreen extends StatelessWidget {
  const AmenityRequestsScreen({
    required this.societyId,
    required this.isAdmin,
    required this.flatNumber,
    required this.residentName,
    super.key,
  });

  final String societyId;
  final bool isAdmin;
  final String flatNumber;
  final String residentName;

  String get _userId => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Amenity bookings')),
        floatingActionButton: isAdmin
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showRequestForm(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Request a booking'),
              ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: societyRepository.watchAmenityRequests(
            societyId: societyId,
            isAdmin: isAdmin,
            userId: _userId,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _MessageState(
                icon: Icons.cloud_off_outlined,
                message:
                    'Bookings are unavailable. Check your connection and try again.',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final requests = snapshot.data!;
            if (requests.isEmpty) {
              return const _MessageState(
                icon: Icons.meeting_room_outlined,
                message: 'No amenity bookings yet.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _RequestCard(
                request: requests[index],
                isAdmin: isAdmin,
                onReview: isAdmin
                    ? (status) => _review(context, requests[index], status)
                    : null,
              ),
            );
          },
        ),
      );

  Future<void> _showRequestForm(BuildContext context) async {
    final result = await showModalBottomSheet<_BookingDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _BookingForm(),
    );
    if (result == null || !context.mounted) return;
    try {
      await societyRepository.createAmenityRequest(
        societyId: societyId,
        residentId: _userId,
        residentName: residentName,
        flatNumber: flatNumber,
        amenity: result.amenity,
        startAt: result.startAt,
        endAt: result.endAt,
        purpose: result.purpose,
        notes: result.notes,
      );
      if (context.mounted) _showMessage(context, 'Booking request sent.');
    } on SocietyDataException catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'Could not send the request. Please try again.');
      }
    }
  }

  Future<void> _review(
    BuildContext context,
    Map<String, dynamic> request,
    String status,
  ) async {
    final response = await showDialog<String>(
      context: context,
      builder: (dialogContext) => DialogTextControllerOwner(
        count: 1,
        initialValues: [request['adminResponse'] as String? ?? ''],
        builder: (context, controllers) => AlertDialog(
          title: Text('$status booking?'),
          content: TextField(
            controller: controllers[0],
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Message to resident (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, controllers[0].text),
                child: Text(status)),
          ],
        ),
      ),
    );
    if (response == null) return;
    try {
      await societyRepository.updateAmenityRequest(
        requestId: request['id'] as String,
        societyId: societyId,
        adminId: _userId,
        status: status,
        response: response,
      );
      if (context.mounted) _showMessage(context, 'Booking updated.');
    } on SocietyDataException catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    } catch (_) {
      if (context.mounted) {
        _showMessage(
            context, 'Could not update this booking. Please try again.');
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BookingDraft {
  const _BookingDraft(
      {required this.amenity,
      required this.startAt,
      required this.endAt,
      required this.purpose,
      required this.notes});
  final String amenity;
  final DateTime startAt;
  final DateTime endAt;
  final String purpose;
  final String notes;
}

class _BookingForm extends StatefulWidget {
  const _BookingForm();
  @override
  State<_BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<_BookingForm> {
  static const _amenities = [
    'Party Hall',
    'Community Hall',
    'Garden',
    'Club House',
    'Other'
  ];
  final _formKey = GlobalKey<FormState>();
  final _purpose = TextEditingController();
  final _notes = TextEditingController();
  String _amenity = _amenities.first;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _start = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 11, minute: 0);

  @override
  void dispose() {
    _purpose.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime _dateTime(TimeOfDay time) =>
      DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Request an amenity',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: _amenity,
                  decoration: const InputDecoration(
                      labelText: 'Amenity', border: OutlineInputBorder()),
                  items: _amenities
                      .map((item) =>
                          DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _amenity = value ?? _amenity),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)));
                    if (selected != null) {
                      setState(() => _date = selected);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                      'Date  •  ${_date.day}/${_date.month}/${_date.year}'),
                ),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () async {
                            final selected = await showTimePicker(
                                context: context, initialTime: _start);
                            if (selected != null) {
                              setState(() => _start = selected);
                            }
                          },
                          child: Text('From  ${_start.format(context)}'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () async {
                            final selected = await showTimePicker(
                                context: context, initialTime: _end);
                            if (selected != null) {
                              setState(() => _end = selected);
                            }
                          },
                          child: Text('Until  ${_end.format(context)}'))),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _purpose,
                    maxLength: 100,
                    decoration: const InputDecoration(
                        labelText: 'Purpose', border: OutlineInputBorder()),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter the purpose'
                        : null),
                const SizedBox(height: 12),
                TextField(
                    controller: _notes,
                    maxLines: 2,
                    maxLength: 300,
                    decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    final start = _dateTime(_start);
                    final end = _dateTime(_end);
                    if (_start.minute % 30 != 0 || _end.minute % 30 != 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Choose times on a 30-minute boundary.')),
                      );
                      return;
                    }
                    if (!start.isBefore(end)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('End time must be after start time.')));
                      return;
                    }
                    Navigator.pop(
                        context,
                        _BookingDraft(
                            amenity: _amenity,
                            startAt: start,
                            endAt: end,
                            purpose: _purpose.text.trim(),
                            notes: _notes.text.trim()));
                  },
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Send request'),
                ),
                const SizedBox(height: 8),
                Text(
                    'Bookings use 30-minute blocks. Pending and approved requests reserve the selected time.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard(
      {required this.request, required this.isAdmin, this.onReview});
  final Map<String, dynamic> request;
  final bool isAdmin;
  final ValueChanged<String>? onReview;

  @override
  Widget build(BuildContext context) {
    final startValue = request['startAt'];
    final endValue = request['endAt'];
    final start = startValue is Timestamp ? startValue.toDate() : null;
    final end = endValue is Timestamp ? endValue.toDate() : null;
    final date = start == null
        ? 'Date unavailable'
        : '${start.day}/${start.month}/${start.year}  ${TimeOfDay.fromDateTime(start).format(context)}–${TimeOfDay.fromDateTime(end ?? start).format(context)}';
    final status = request['status'] as String? ?? 'Pending';
    final color = switch (status) {
      'Approved' => Colors.green,
      'Rejected' => Colors.red,
      'Completed' => Theme.of(context).colorScheme.secondary,
      _ => Colors.orange,
    };
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(request['amenity'] as String? ?? 'Amenity',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700))),
          Chip(
              label: Text(status),
              side: BorderSide.none,
              backgroundColor: color.withValues(alpha: 0.12),
              labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700))
        ]),
        Text(date, style: Theme.of(context).textTheme.bodyMedium),
        if (isAdmin)
          Text(
              '${request['residentName'] ?? 'Resident'}  •  Flat ${request['flatNumber'] ?? '—'}'),
        const SizedBox(height: 8),
        Text(request['purpose'] as String? ?? ''),
        if ((request['notes'] as String? ?? '').isNotEmpty)
          Text(request['notes'] as String),
        if ((request['adminResponse'] as String? ?? '').isNotEmpty) ...[
          const Divider(height: 20),
          Text('Admin response: ${request['adminResponse']}'),
        ],
        if (isAdmin && (status == 'Pending' || status == 'Approved')) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            if (status == 'Pending')
              OutlinedButton(
                  onPressed: () => onReview?.call('Rejected'),
                  child: const Text('Reject')),
            FilledButton(
                onPressed: () => onReview
                    ?.call(status == 'Pending' ? 'Approved' : 'Completed'),
                child: Text(status == 'Pending' ? 'Approve' : 'Complete')),
          ]),
        ],
      ]),
    ));
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center)
          ])));
}
