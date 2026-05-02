import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/vendor_route.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../login_screen.dart';
import '../resident/resident_home_screen.dart';
import '../vendor/vendor_home_screen.dart';
import 'admin_vendor_approval_screen.dart';
import 'reports_admin_screen.dart';
import 'requests_admin_screen.dart';
import 'config_admin_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final firestoreService = FirestoreService();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showConfirmDialog(
                context: context,
                title: 'Logout',
                message: 'Are you sure you want to log out?',
                confirmText: 'Logout',
              );
              if (confirm) {
                if (context.mounted) {
                  context.read<AppProvider>().logout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
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

          // ── Moderation section ────────────────────
          Text(
            'MODERATION',
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
                  leading: const CircleAvatar(child: Icon(Icons.verified_user, size: 18)),
                  title: const Text('Vendor Approvals'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminVendorApprovalScreen())),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.report, size: 18)),
                  title: const Text('User Reports'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsAdminScreen())),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.forum, size: 18)),
                  title: const Text('All Vendor Requests'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsAdminScreen())),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.settings, size: 18)),
                  title: const Text('System Configuration'),
                  subtitle: const Text('Manage categories & vehicles'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigAdminScreen())),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Users section ───────────────────────
          Text(
            'USERS',
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
              if (snapshot.hasError) {
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(Icons.error_outline, color: colorScheme.error),
                    title: const Text('Could not load users'),
                    subtitle: Text(snapshot.error.toString().replaceAll('Exception: ', '')),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              final users = snapshot.data!;
              final vendors = users.where((u) => u.role == 'vendor').toList();
              final residents = users.where((u) => u.role == 'resident').toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatChip(label: 'Total', value: users.length, icon: Icons.people_outline, color: colorScheme.primary),
                      _StatChip(label: 'Vendors', value: vendors.length, icon: Icons.store_outlined, color: Colors.orange),
                      _StatChip(label: 'Residents', value: residents.length, icon: Icons.person_outline, color: Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (users.isEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('No users registered yet.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      ),
                    )
                  else
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (int i = 0; i < users.length; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 56),
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: users[i].role == 'vendor'
                                    ? Colors.orange.withValues(alpha: 0.15)
                                    : colorScheme.primaryContainer,
                                child: Icon(
                                  users[i].role == 'vendor' ? Icons.store : Icons.person,
                                  size: 18,
                                  color: users[i].role == 'vendor' ? Colors.orange.shade700 : colorScheme.primary,
                                ),
                              ),
                              title: Text(users[i].name, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${users[i].role} • ${users[i].phone}'),
                                  if (users[i].isBlocked)
                                    Text('Blocked: ${users[i].blockedReason}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'block') {
                                    final reasonController = TextEditingController();
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Block User'),
                                        content: TextField(
                                          controller: reasonController,
                                          decoration: const InputDecoration(labelText: 'Reason'),
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Block')),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await firestoreService.blockUser(users[i].id, reasonController.text);
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked')));
                                    }
                                  } else if (value == 'unblock') {
                                    final confirm = await showConfirmDialog(
                                      context: context,
                                      title: 'Unblock User?',
                                      message: 'Are you sure you want to unblock ${users[i].name}?',
                                      confirmText: 'Unblock',
                                    );
                                    if (confirm) {
                                      await firestoreService.unblockUser(users[i].id);
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unblocked')));
                                    }
                                  } else if (value == 'delete') {
                                    final confirm = await showConfirmDialog(
                                      context: context,
                                      title: 'Delete User?',
                                      message: 'This action cannot be undone and will remove all user data.',
                                      confirmText: 'Delete',
                                      confirmColor: Colors.red,
                                    );
                                    if (confirm) {
                                      await firestoreService.deleteUser(users[i].id);
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted')));
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (!users[i].isBlocked) const PopupMenuItem(value: 'block', child: Text('Block User')),
                                  if (users[i].isBlocked) const PopupMenuItem(value: 'unblock', child: Text('Unblock User')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete User', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Routes section ──────────────────────
          Text(
            'ROUTES',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<VendorRoute>>(
            stream: firestoreService.routesStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(Icons.error_outline, color: colorScheme.error),
                    title: const Text('Could not load routes'),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              final routes = snapshot.data!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    children: [
                      _StatChip(label: 'Total Routes', value: routes.length, icon: Icons.route_outlined, color: Colors.teal),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (routes.isEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('No routes created yet.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      ),
                    )
                  else
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (int i = 0; i < routes.length; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 56),
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.withValues(alpha: 0.12),
                                child: Icon(Icons.route, size: 18, color: Colors.teal.shade700),
                              ),
                              title: Text(routes[i].name, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                '${routes[i].streets.length} stop${routes[i].streets.length != 1 ? "s" : ""}',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
