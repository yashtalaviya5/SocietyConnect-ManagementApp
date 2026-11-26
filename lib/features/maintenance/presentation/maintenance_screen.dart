import 'package:flutter/material.dart';

import '../../community/data/society_repository.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen(
      {required this.societyId, required this.userId, super.key});
  final String societyId;
  final String userId;

  String _period(Map<String, dynamic> item) {
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
    final month = item['month'];
    final monthName = month is int && month >= 1 && month <= 12
        ? months[month - 1]
        : month?.toString() ?? '—';
    return '$monthName ${item['year'] ?? ''}'.trim();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Maintenance')),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: societyRepository.watchMaintenance(societyId, userId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _MaintenanceState(
                icon: Icons.cloud_off_outlined,
                message:
                    'Could not load your maintenance records. Check your connection and permissions.',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data!;
            if (items.isEmpty) {
              return const _MaintenanceState(
                icon: Icons.receipt_long_outlined,
                message:
                    'No maintenance records are available yet. Your society admin can add monthly dues.',
              );
            }
            final pending =
                items.where((item) => item['status'] != 'Paid').fold<num>(
                      0,
                      (total, item) => total + ((item['amount'] as num?) ?? 0),
                    );
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pending dues',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 4),
                              Text('₹${pending.toStringAsFixed(2)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        Text('Society $societyId',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Payment history',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ...items.map((item) {
                  final paid = item['status'] == 'Paid';
                  final amount = (item['amount'] as num?) ?? 0;
                  final method = item['paymentMethod'] as String?;
                  final dateValue = item['paymentDate'];
                  final paidDate = dateValue == null
                      ? null
                      : dateValue.toDate() as DateTime?;
                  final color = paid ? Colors.green : Colors.orange.shade800;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Icon(
                              paid
                                  ? Icons.check_rounded
                                  : Icons.schedule_rounded,
                              color: color),
                        ),
                        title: Text(_period(item),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text([
                          if (paid && paidDate != null)
                            'Paid ${MaterialLocalizations.of(context).formatShortDate(paidDate)}',
                          if (paid && method != null && method.isNotEmpty)
                            method,
                          if (!paid) 'Payment pending',
                        ].join(' • ')),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(paid ? 'Paid' : 'Pending',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
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

class _MaintenanceState extends StatelessWidget {
  const _MaintenanceState({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
