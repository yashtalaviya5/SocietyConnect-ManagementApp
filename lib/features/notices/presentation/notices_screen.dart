import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/dialog_text_controller_owner.dart';
import '../../community/data/society_repository.dart';

class NoticesScreen extends StatelessWidget {
  const NoticesScreen({
    required this.societyId,
    required this.isAdmin,
    super.key,
  });

  final String societyId;
  final bool isAdmin;

  Future<void> _createNotice(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    var category = 'General';
    var titleText = '';
    var bodyText = '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DialogTextControllerOwner(
        count: 2,
        builder: (context, controllers) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Publish a notice'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: controllers[0],
                      maxLength: 90,
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
                        'General',
                        'Maintenance',
                        'Emergency',
                        'Meeting',
                        'Event',
                        'Important',
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
                      maxLength: 1800,
                      decoration:
                          const InputDecoration(labelText: 'Notice details'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter the notice details.'
                              : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    titleText = controllers[0].text;
                    bodyText = controllers[1].text;
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const Text('Publish'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true && context.mounted) {
      try {
        await societyRepository.createNotice(
          societyId: societyId,
          title: titleText,
          body: bodyText,
          category: category,
          userId: FirebaseAuth.instance.currentUser!.uid,
        );
        if (!context.mounted) return;
        _show(context, 'Notice published.');
      } on SocietyDataException catch (error) {
        if (context.mounted) _show(context, error.message);
      }
    }
  }

  Future<void> _deactivateNotice(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this notice?'),
        content:
            const Text('Residents will no longer see it in the notices list.'),
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
      await societyRepository.deactivateNotice(
        noticeId: id,
        societyId: societyId,
        adminId: FirebaseAuth.instance.currentUser!.uid,
      );
    } on SocietyDataException catch (error) {
      if (context.mounted) _show(context, error.message);
    }
  }

  void _show(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notices')),
        floatingActionButton: isAdmin
            ? FloatingActionButton.extended(
                onPressed: () => _createNotice(context),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('New notice'),
              )
            : null,
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: societyRepository.watchNotices(societyId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _NoticeState(
                  message:
                      'Could not load notices. Check your connection and permissions.');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final notices = snapshot.data!;
            if (notices.isEmpty) {
              return const _NoticeState(
                  message: 'No notices have been published yet.');
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
              itemCount: notices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notice = notices[index];
                final category = notice['category'] as String? ?? 'General';
                final timestamp = notice['createdAt'];
                final date = timestamp is DateTime
                    ? timestamp
                    : timestamp?.toDate() as DateTime?;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notice['title'] as String? ?? 'Notice',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (isAdmin)
                              IconButton(
                                tooltip: 'Remove notice',
                                onPressed: () => _deactivateNotice(
                                    context, notice['id'] as String),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(notice['body'] as String? ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(height: 1.5)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Chip(
                                label: Text(category),
                                visualDensity: VisualDensity.compact),
                            const Spacer(),
                            if (date != null)
                              Text(
                                MaterialLocalizations.of(context)
                                    .formatShortDate(date),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
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

class _NoticeState extends StatelessWidget {
  const _NoticeState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}
