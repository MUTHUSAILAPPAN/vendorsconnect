import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../providers/app_provider.dart';
import '../../widgets/confirm_dialog.dart';

class FollowerProfileScreen extends StatelessWidget {
  final AppUser follower;

  const FollowerProfileScreen({super.key, required this.follower});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Follower Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.block_outlined),
            tooltip: 'Block User',
            onPressed: () async {
              final provider = context.read<AppProvider>();
              final confirm = await showConfirmDialog(
                context: context,
                title: 'Block User',
                message: 'Are you sure you want to block ${follower.name}? They will no longer follow you or see your location.',
                confirmText: 'Block',
              );
              if (confirm) {
                try {
                  await provider.blockUser(follower.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${follower.name} blocked')),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not block user')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    follower.name.isNotEmpty ? follower.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  follower.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  follower.isContactPublic ? follower.phone : 'Contact is private',
                  style: TextStyle(
                    color: follower.isContactPublic ? colorScheme.onSurfaceVariant : colorScheme.error,
                    fontStyle: follower.isContactPublic ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Bio Section
          if (follower.bio.isNotEmpty) ...[
            _sectionLabel(context, 'Bio'),
            Text(
              follower.bio,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
          ],

          // Location Section
          if (follower.locationName.isNotEmpty) ...[
            _sectionLabel(context, 'Location'),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    follower.locationName,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Interests Section
          _sectionLabel(context, 'Interests'),
          if (follower.interests.isEmpty)
            const Text('No interests listed.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: follower.interests.map((interest) {
                return Chip(
                  label: Text(interest),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  side: BorderSide.none,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
