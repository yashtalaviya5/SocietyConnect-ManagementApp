import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/dialog_text_controller_owner.dart';
import '../../community/data/society_repository.dart';

class AdminMaintenanceScreen extends StatefulWidget {
  const AdminMaintenanceScreen({required this.societyId, super.key});
  final String societyId;

  @override
  State<AdminMaintenanceScreen> createState() => _AdminMaintenanceScreenState();
}

class _AdminMaintenanceScreenState extends State<AdminMaintenanceScreen> {
  String _statusFilter = 'Pending';

  Future<void> _generate(BuildContext context) async {
    final now = DateTime.now();
    final formKey = GlobalKey<FormState>();
    var month = now.month;
    var year = now.year;
    var amountText = '';
    final generated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DialogTextControllerOwner(
        count: 1,
        builder: (context, controllers) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Generate monthly dues'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: month,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: List.generate(12, (index) => index + 1)
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(_monthName(value)),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() => month = value!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: year,
                    decoration: const InputDecoration(labelText: 'Year'),
                    items: List.generate(4, (index) => now.year + index)
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.toString()),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() => year = value!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: controllers[0],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount per occupied flat',
                      prefixText: '₹ ',
                    ),
                    validator: (value) {
                      final parsed = num.tryParse(value?.trim() ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'Enter an amount greater than zero.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Existing dues for this month are kept unchanged; only missing flat dues are generated.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
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
                    amountText = controllers[0].text;
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const Text('Generate'),
              ),
            ],
          ),
        ),
      ),
    );
    if (generated == true && context.mounted) {
      try {
        final result = await societyRepository.generateMonthlyDues(
          societyId: widget.societyId,
          month: month,
          year: year,
          amount: num.parse(amountText.trim()),
          adminId: FirebaseAuth.instance.currentUser!.uid,
        );
        if (!context.mounted) return;
        final messages = <String>[];
        if (result.created > 0) {
          messages.add('Generated dues for ${result.created} flat(s).');
        }
        if (result.alreadyGenerated > 0) {
          messages.add(
            'Dues already existed for ${result.alreadyGenerated} flat(s) this month.',
          );
        }
        if (result.unassignedFlats.isNotEmpty) {
          messages.add(
            'Could not bill ${result.unassignedFlats.join(', ')}: assign a resident profile to each occupied flat, then retry.',
          );
        }
        if (messages.isEmpty) {
          messages.add('No occupied flats were found for this society.');
        }
        _show(context, messages.join(' '));
      } on SocietyDataException catch (error) {
        if (context.mounted) _show(context, error.message);
      }
    }
  }

  Future<void> _changePayment(
      BuildContext context, Map<String, dynamic> item) async {
    var method = item['paymentMethod'] as String? ?? 'Cash';
    var paid = item['status'] == 'Paid';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update payment status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Paid'),
                value: paid,
                onChanged: (value) => setDialogState(() => paid = value),
              ),
              if (paid) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration:
                      const InputDecoration(labelText: 'Payment method'),
                  items: const ['Cash', 'UPI', 'Bank transfer', 'Cheque']
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) => setDialogState(() => method = value!),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      try {
        await societyRepository.recordMaintenancePayment(
          maintenanceId: item['id'] as String,
          societyId: widget.societyId,
          adminId: FirebaseAuth.instance.currentUser!.uid,
          paid: paid,
          paymentMethod: method,
        );
      } on SocietyDataException catch (error) {
        if (context.mounted) _show(context, error.message);
      }
    }
  }

  void _show(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Maintenance management'),
          actions: [
            IconButton(
              tooltip: 'Generate monthly dues',
              onPressed: () => _generate(context),
              icon: const Icon(Icons.add_card_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _generate(context),
          icon: const Icon(Icons.add_card_rounded),
          label: const Text('Generate dues'),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: societyRepository.watchSocietyMaintenance(widget.societyId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _Empty(
                  message:
                      'Could not load dues. Check your connection and Firestore rules.');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final allRecords = snapshot.data!;
            if (allRecords.isEmpty) {
              return const _Empty(
                  message:
                      'No maintenance dues yet. Generate a month to create records for occupied flats.');
            }
            final paid =
                allRecords.where((item) => item['status'] == 'Paid').length;
            final pendingAmount = allRecords
                .where((item) => item['status'] != 'Paid')
                .fold<num>(0,
                    (total, item) => total + ((item['amount'] as num?) ?? 0));
            final records = allRecords
                .where((item) => _statusFilter == 'All'
                    ? true
                    : (item['status'] == 'Paid') == (_statusFilter == 'Paid'))
                .toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        Text('Paid  $paid / ${allRecords.length}',
                            style: Theme.of(context).textTheme.titleSmall),
                        Text('Pending  ₹${pendingAmount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: ['Pending', 'Paid', 'All']
                      .map((status) => ChoiceChip(
                            label: Text(status),
                            selected: _statusFilter == status,
                            onSelected: (_) =>
                                setState(() => _statusFilter = status),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                if (records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No records match this payment status.'),
                  ),
                ...records.map((item) {
                  final isPaid = item['status'] == 'Paid';
                  final amount = (item['amount'] as num?) ?? 0;
                  final method = item['paymentMethod'] as String?;
                  final dateValue = item['paymentDate'];
                  final paymentDate = dateValue == null
                      ? null
                      : dateValue.toDate() as DateTime?;
                  final color = isPaid ? Colors.green : Colors.orange.shade800;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Icon(
                              isPaid
                                  ? Icons.check_rounded
                                  : Icons.schedule_rounded,
                              color: color),
                        ),
                        title: Text(
                            'Flat ${item['flatNumber'] ?? '—'}  •  ${_monthName(item['month'] as int? ?? 0)} ${item['year'] ?? ''}'),
                        subtitle: Text(isPaid
                            ? 'Paid${paymentDate == null ? '' : ' on ${MaterialLocalizations.of(context).formatShortDate(paymentDate)}'}${method == null ? '' : ' • $method'}'
                            : 'Payment pending'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₹${amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            IconButton(
                              tooltip: 'Update payment status',
                              onPressed: () => _changePayment(context, item),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      );
}

String _monthName(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return month >= 1 && month <= 12 ? months[month - 1] : 'Month';
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}
