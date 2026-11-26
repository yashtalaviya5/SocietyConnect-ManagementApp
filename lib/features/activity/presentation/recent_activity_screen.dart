import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../community/data/society_repository.dart';

class RecentActivityScreen extends StatelessWidget {
  const RecentActivityScreen({required this.societyId, super.key});

  final String societyId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Recent activity')),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: societyRepository.watchRecentActivity(societyId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Activity is unavailable.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final entries = snapshot.data!;
            if (entries.isEmpty) {
              return const Center(
                child: Text('No society activity has been recorded yet.'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.history_rounded),
                  ),
                  title: Text(entry['description'] as String? ??
                      entry['action'] as String? ??
                      'Activity'),
                  subtitle: Text(_activityTime(entry['createdAt'])),
                );
              },
            );
          },
        ),
      );

  String _activityTime(Object? value) {
    if (value is! Timestamp) return 'Just now';
    final date = value.toDate();
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}
