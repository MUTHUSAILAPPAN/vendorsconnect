import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../resident/resident_home_screen.dart';
import '../vendor/vendor_home_screen.dart';
import 'admin_vendor_approval_screen.dart';
import 'config_admin_screen.dart';
import 'reports_admin_screen.dart';
import 'requests_admin_screen.dart';

class AdminDashboardTab extends StatelessWidget {
  final Function(String? role) onFilterUsers;

  const AdminDashboardTab({super.key, required this.onFilterUsers});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final firestoreService = FirestoreService();
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Preview Mode ────────────────────────
        Text(
          'PREVIEW MODE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('View as user role', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'resident', label: Text('Resident'), icon: Icon(Icons.person)),
                    ButtonSegment(value: 'vendor', label: Text('Vendor'), icon: Icon(Icons.store)),
                  ],
                  selected: {provider.adminViewRole},
                  onSelectionChanged: (value) => provider.switchAdminView(value.first),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: Text('Open ${provider.adminViewRole[0].toUpperCase()}${provider.adminViewRole.substring(1)} UI'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => provider.adminViewRole == 'vendor'
                              ? const VendorHomeScreen()
                              : const ResidentHomeScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Summary Stats ───────────────────────
        Text(
          'SUMMARY',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<AppUser>>(
          stream: firestoreService.usersStream(),
          builder: (context, snapshot) {
            final users = snapshot.data ?? [];
            final vendors = users.where((u) => u.role == 'vendor').toList();
            final residents = users.where((u) => u.role == 'resident').toList();

            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatCard(
                  label: 'Total Users',
                  value: users.length.toString(),
                  icon: Icons.people,
                  color: colorScheme.primary,
                  onTap: () => onFilterUsers(null),
                ),
                _StatCard(
                  label: 'Vendors',
                  value: vendors.length.toString(),
                  icon: Icons.store,
                  color: Colors.orange,
                  onTap: () => onFilterUsers('vendor'),
                ),
                _StatCard(
                  label: 'Residents',
                  value: residents.length.toString(),
                  icon: Icons.person,
                  color: Colors.blue,
                  onTap: () => onFilterUsers('resident'),
                ),
                StreamBuilder(
                  stream: firestoreService.pendingVendorsStream(),
                  builder: (context, snap) {
                    final count = snap.data?.length ?? 0;
                    return _StatCard(
                      label: 'Pending',
                      value: count.toString(),
                      icon: Icons.pending_actions,
                      color: Colors.amber,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminVendorApprovalScreen())),
                    );
                  },
                ),
                StreamBuilder(
                  stream: firestoreService.reportsStream(),
                  builder: (context, snap) {
                    final count = (snap.data?.docs.length) ?? 0;
                    return _StatCard(
                      label: 'Reports',
                      value: count.toString(),
                      icon: Icons.report,
                      color: colorScheme.error,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsAdminScreen())),
                    );
                  },
                ),
                StreamBuilder(
                  stream: firestoreService.allVendorRequestsStream(),
                  builder: (context, snap) {
                    final count = (snap.data?.docs.length) ?? 0;
                    return _StatCard(
                      label: 'Requests',
                      value: count.toString(),
                      icon: Icons.forum,
                      color: Colors.teal,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsAdminScreen())),
                    );
                  },
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // ── Quick Actions ───────────────────────
        Text(
          'QUICK ACTIONS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('System Configuration'),
                subtitle: const Text('Manage categories & vehicles'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigAdminScreen())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        margin: EdgeInsets.zero,
        color: color.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.15)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color.withValues(alpha: 0.8),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
