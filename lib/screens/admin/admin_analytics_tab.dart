import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/firestore_service.dart';

class AdminAnalyticsTab extends StatelessWidget {
  const AdminAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<AppUser>>(
      stream: firestoreService.usersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final users = snapshot.data!;
        if (users.isEmpty) return const Center(child: Text('No data to analyze.'));

        // ── Aggregations ────────────────────────
        final roleCounts = <String, int>{};
        final locationCounts = <String, int>{};
        final categoryCounts = <String, int>{};
        final vehicleCounts = <String, int>{};
        final interestCounts = <String, int>{};

        for (final u in users) {
          roleCounts[u.role] = (roleCounts[u.role] ?? 0) + 1;
          
          if (u.locationName.isNotEmpty) {
            // Extract locality/city from locationName (simple split)
            final locality = u.locationName.split(',').first.trim();
            locationCounts[locality] = (locationCounts[locality] ?? 0) + 1;
          }

          if (u.role == 'vendor') {
            for (final cat in u.interests) {
              categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
            }
            if (u.vehicle.isNotEmpty) {
              vehicleCounts[u.vehicle] = (vehicleCounts[u.vehicle] ?? 0) + 1;
            }
          } else if (u.role == 'resident') {
            for (final interest in u.interests) {
              interestCounts[interest] = (interestCounts[interest] ?? 0) + 1;
            }
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _AnalyticsSection(
              title: 'Users by Role',
              counts: roleCounts,
              total: users.length,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 24),
            _AnalyticsSection(
              title: 'Users by Location',
              counts: locationCounts,
              total: users.length,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            _AnalyticsSection(
              title: 'Vendor Categories',
              counts: categoryCounts,
              total: users.where((u) => u.role == 'vendor').length,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            _AnalyticsSection(
              title: 'Vendor Vehicles',
              counts: vehicleCounts,
              total: users.where((u) => u.role == 'vendor').length,
              color: Colors.teal,
            ),
            const SizedBox(height: 24),
            _AnalyticsSection(
              title: 'Resident Interests',
              counts: interestCounts,
              total: users.where((u) => u.role == 'resident').length,
              color: Colors.purple,
            ),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }
}

class _AnalyticsSection extends StatelessWidget {
  final String title;
  final Map<String, int> counts;
  final int total;
  final Color color;

  const _AnalyticsSection({
    required this.title,
    required this.counts,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Sort counts descending
    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                letterSpacing: 1,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (counts.isEmpty)
          const Text('No data available.', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic))
        else
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: sortedEntries.take(10).map((e) {
                  final percent = total > 0 ? e.value / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                            Text('${e.value} (${(percent * 100).toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: percent,
                          backgroundColor: color.withValues(alpha: 0.1),
                          color: color,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}
