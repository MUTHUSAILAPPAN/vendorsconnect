import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import '../../widgets/confirm_dialog.dart';

class AdminUsersTab extends StatefulWidget {
  final String? initialRoleFilter;

  const AdminUsersTab({super.key, this.initialRoleFilter});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final firestoreService = FirestoreService();
  String _searchQuery = '';
  String? _roleFilter;
  String? _categoryFilter;
  String? _vehicleFilter;

  @override
  void initState() {
    super.initState();
    _roleFilter = widget.initialRoleFilter;
  }

  @override
  void didUpdateWidget(AdminUsersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRoleFilter != oldWidget.initialRoleFilter) {
      setState(() {
        _roleFilter = widget.initialRoleFilter;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Search & Filters ─────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          color: colorScheme.surface,
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name, phone, or location...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All Roles',
                      selected: _roleFilter == null,
                      onSelected: (s) => setState(() => _roleFilter = null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Vendors',
                      selected: _roleFilter == 'vendor',
                      onSelected: (s) => setState(() => _roleFilter = 'vendor'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Residents',
                      selected: _roleFilter == 'resident',
                      onSelected: (s) => setState(() => _roleFilter = 'resident'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Admins',
                      selected: _roleFilter == 'admin',
                      onSelected: (s) => setState(() => _roleFilter = 'admin'),
                    ),
                  ],
                ),
              ),
              if (_roleFilter == 'vendor') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<List<String>>(
                        stream: firestoreService.configValuesStream('vendor_categories'),
                        builder: (context, snapshot) {
                          final categories = snapshot.data ?? [];
                          return DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Category',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            initialValue: _categoryFilter,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Categories')),
                              ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                            ],
                            onChanged: (v) => setState(() => _categoryFilter = v),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StreamBuilder<List<String>>(
                        stream: firestoreService.configValuesStream('vehicle_options'),
                        builder: (context, snapshot) {
                          final vehicles = snapshot.data ?? [];
                          return DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Vehicle',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            initialValue: _vehicleFilter,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Vehicles')),
                              ...vehicles.map((v) => DropdownMenuItem(value: v, child: Text(v))),
                            ],
                            onChanged: (v) => setState(() => _vehicleFilter = v),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ── User List ────────────────────────────
        Expanded(
          child: StreamBuilder<List<AppUser>>(
            stream: firestoreService.usersStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = snapshot.data!.where((u) {
                final matchesSearch = u.name.toLowerCase().contains(_searchQuery) ||
                    u.phone.contains(_searchQuery) ||
                    u.locationName.toLowerCase().contains(_searchQuery);
                final matchesRole = _roleFilter == null || u.role == _roleFilter;
                
                bool matchesVendor = true;
                if (u.role == 'vendor') {
                  if (_categoryFilter != null && !u.interests.contains(_categoryFilter)) matchesVendor = false;
                  if (_vehicleFilter != null && u.vehicle != _vehicleFilter) matchesVendor = false;
                } else if (_roleFilter == 'vendor') {
                  // If we are filtering by vendor but this user isn't one
                  matchesVendor = false;
                }

                return matchesSearch && matchesRole && matchesVendor;
              }).toList();

              if (users.isEmpty) {
                return const Center(child: Text('No users found matching filters.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: users.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: user.role == 'vendor'
                          ? Colors.orange.withValues(alpha: 0.1)
                          : user.role == 'admin' 
                            ? Colors.purple.withValues(alpha: 0.1)
                            : colorScheme.primaryContainer,
                      child: Icon(
                        user.role == 'vendor' ? Icons.store : user.role == 'admin' ? Icons.security : Icons.person,
                        size: 20,
                        color: user.role == 'vendor' ? Colors.orange.shade700 : user.role == 'admin' ? Colors.purple : colorScheme.primary,
                      ),
                    ),
                    title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${user.role.toUpperCase()} • ${user.phone}'),
                        if (user.locationName.isNotEmpty)
                          Text(user.locationName, style: const TextStyle(fontSize: 12)),
                        if (user.isBlocked)
                          Text('Blocked: ${user.blockedReason}', style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) => _handleMenuAction(context, value, user),
                      itemBuilder: (context) => [
                        if (!user.isBlocked) const PopupMenuItem(value: 'block', child: Text('Block User')),
                        if (user.isBlocked) const PopupMenuItem(value: 'unblock', child: Text('Unblock User')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete User', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleMenuAction(BuildContext context, String action, AppUser user) async {
    if (action == 'block') {
      final reasonController = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Block User'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(labelText: 'Reason for blocking'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Block')),
          ],
        ),
      );
      if (confirm == true) {
        await firestoreService.blockUser(user.id, reasonController.text);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked')));
      }
    } else if (action == 'unblock') {
      final confirm = await showConfirmDialog(
        context: context,
        title: 'Unblock User?',
        message: 'Are you sure you want to unblock ${user.name}?',
        confirmText: 'Unblock',
      );
      if (confirm) {
        await firestoreService.unblockUser(user.id);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unblocked')));
      }
    } else if (action == 'delete') {
      final confirm = await showConfirmDialog(
        context: context,
        title: 'Delete User?',
        message: 'This action cannot be undone and will remove all user data.',
        confirmText: 'Delete',
        confirmColor: Colors.red,
      );
      if (confirm) {
        await firestoreService.deleteUser(user.id);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted')));
      }
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Function(bool) onSelected;

  const _FilterChip({required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      labelStyle: TextStyle(
        color: selected ? Colors.white : null,
        fontWeight: selected ? FontWeight.bold : null,
      ),
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Colors.white,
    );
  }
}
