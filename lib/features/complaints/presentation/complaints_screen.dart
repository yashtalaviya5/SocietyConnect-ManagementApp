import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/dialog_text_controller_owner.dart';
import '../../community/data/society_repository.dart';

class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({
    required this.societyId,
    required this.userId,
    required this.isAdmin,
    required this.flatNumber,
    super.key,
  });

  final String societyId;
  final String userId;
  final bool isAdmin;
  final String flatNumber;

  Future<void> _newComplaint(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    var category = 'Maintenance';
    var titleText = '';
    var descriptionText = '';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DialogTextControllerOwner(
        count: 2,
        builder: (context, controllers) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('New complaint'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: controllers[0],
                      maxLength: 100,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter a title.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        'Water',
                        'Electricity',
                        'Security',
                        'Cleaning',
                        'Maintenance',
                        'Parking',
                        'Other',
                      ]
                          .map((value) => DropdownMenuItem(
                              value: value, child: Text(value)))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => category = value!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers[1],
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                          labelText: 'Describe the issue'),
                      validator: (value) =>
                          value == null || value.trim().length < 10
                              ? 'Add at least 10 characters of detail.'
                              : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    titleText = controllers[0].text;
                    descriptionText = controllers[1].text;
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
    if (submitted == true && context.mounted) {
      try {
        await societyRepository.createComplaint(
          societyId: societyId,
          userId: userId,
          flatNumber: flatNumber,
          title: titleText,
          description: descriptionText,
          category: category,
        );
        if (!context.mounted) return;
        _message(
            context, 'Complaint submitted. You can track its status here.');
      } on SocietyDataException catch (error) {
        if (context.mounted) _message(context, error.message);
      }
    }
  }

  Future<void> _updateComplaint(
      BuildContext context, Map<String, dynamic> complaint) async {
    var responseText = complaint['adminResponse'] as String? ?? '';
    var status = complaint['status'] as String? ?? 'Pending';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DialogTextControllerOwner(
        count: 1,
        initialValues: [responseText],
        builder: (context, controllers) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Update complaint'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    'Pending',
                    'In Progress',
                    'Resolved',
                    'Rejected'
                  ]
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) => setDialogState(() => status = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controllers[0],
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration:
                      const InputDecoration(labelText: 'Response to resident'),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () {
                    responseText = controllers[0].text;
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
    if (saved == true && context.mounted) {
      try {
        await societyRepository.updateComplaint(
          complaintId: complaint['id'] as String,
          societyId: societyId,
          adminId: FirebaseAuth.instance.currentUser!.uid,
          status: status,
          adminResponse: responseText,
        );
      } on SocietyDataException catch (error) {
        if (context.mounted) _message(context, error.message);
      }
    }
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Complaints')),
        floatingActionButton: isAdmin
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _newComplaint(context),
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('New complaint'),
              ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: societyRepository.watchComplaints(
            societyId: societyId,
            isAdmin: isAdmin,
            userId: userId,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _ComplaintEmpty(
                  message:
                      'Could not load complaints. Check your connection and permissions.');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final complaints = snapshot.data!;
            if (complaints.isEmpty) {
              return _ComplaintEmpty(
                  message: isAdmin
                      ? 'There are no complaints yet.'
                      : 'You have not submitted a complaint.');
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
              itemCount: complaints.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = complaints[index];
                final status = item['status'] as String? ?? 'Pending';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item['title'] as String? ?? 'Complaint',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (isAdmin)
                              IconButton(
                                tooltip: 'Update status',
                                onPressed: () =>
                                    _updateComplaint(context, item),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(item['description'] as String? ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(height: 1.4)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Chip(
                                label: Text(status),
                                visualDensity: VisualDensity.compact),
                            Chip(
                                label: Text(
                                    item['category'] as String? ?? 'Other'),
                                visualDensity: VisualDensity.compact),
                            if (isAdmin)
                              Chip(
                                  label:
                                      Text('Flat ${item['flatNumber'] ?? '—'}'),
                                  visualDensity: VisualDensity.compact),
                          ],
                        ),
                        if ((item['adminResponse'] as String? ?? '')
                            .isNotEmpty) ...[
                          const Divider(height: 22),
                          Text('Admin response',
                              style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 4),
                          Text(item['adminResponse'] as String),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

class _ComplaintEmpty extends StatelessWidget {
  const _ComplaintEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}
