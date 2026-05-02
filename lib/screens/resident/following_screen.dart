import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import 'notifications_screen.dart';
import 'vendor_profile_screen.dart';

class FollowingScreen extends StatelessWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AppProvider>().currentUser;
    final firestoreService = FirestoreService();
    final colorScheme = Theme.of(context).colorScheme;

    if (currentUser == null) {
      return const Center(child: Text('Please login'));
    }

    return ListView(
      children: [
        // ── Followed vendors ──────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'FOLLOWED VENDORS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        StreamBuilder<List<AppUser>>(
          stream: firestoreService.vendorsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final followed = snapshot.data!
                .where((vendor) => currentUser.following.contains(vendor.id))
                .where((vendor) => !currentUser.blockedUserIds.contains(vendor.id))
                .toList();

            if (followed.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.favorite_border, size: 20, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text('You are not following any vendors yet.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              );
            }

            return Column(
              children: followed.map((vendor) {
                final initial = vendor.name.isEmpty ? '?' : vendor.name[0].toUpperCase();
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: vendor.isAvailable
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    child: Text(initial,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: vendor.isAvailable ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        )),
                  ),
                  title: Text(vendor.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Row(
                    children: [
                      Icon(
                        vendor.isAvailable ? Icons.circle : Icons.circle_outlined,
                        size: 10,
                        color: vendor.isAvailable ? Colors.green : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vendor.isAvailable ? 'Available' : 'Not available',
                        style: TextStyle(
                          color: vendor.isAvailable ? Colors.green.shade700 : colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => VendorProfileScreen(vendor: vendor)),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const Divider(height: 32),

        // ── Notifications ─────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'NOTIFICATIONS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.secondaryContainer,
            child: Icon(Icons.notifications, color: colorScheme.secondary),
          ),
          title: const Text('Notification Settings / Notifications'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
