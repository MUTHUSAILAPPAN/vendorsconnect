import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/firestore_service.dart';

class AdminVendorApprovalScreen extends StatefulWidget {
  const AdminVendorApprovalScreen({super.key});

  @override
  State<AdminVendorApprovalScreen> createState() => _AdminVendorApprovalScreenState();
}

class _AdminVendorApprovalScreenState extends State<AdminVendorApprovalScreen> {
  final firestoreService = FirestoreService();

  Future<void> _approveVendor(AppUser vendor) async {
    try {
      await firestoreService.approveVendor(vendor.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${vendor.name} approved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve: $e')),
      );
    }
  }

  Future<void> _rejectVendor(AppUser vendor) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Vendor'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final reason = reasonController.text.trim();
      if (reason.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rejection reason is required')),
        );
        return;
      }

      try {
        await firestoreService.rejectVendor(vendor.id, reason);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${vendor.name} rejected')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Vendors'),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: firestoreService.pendingVendorsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: ${snapshot.error}', style: TextStyle(color: colorScheme.error)),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final vendors = snapshot.data!;

          if (vendors.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
                    SizedBox(height: 16),
                    Text('No pending vendors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('All registrations have been processed.', textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vendors.length,
            itemBuilder: (context, index) {
              final vendor = vendors[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.orange.shade100,
                            child: Icon(Icons.store, color: Colors.orange.shade700),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(vendor.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(vendor.phone, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      if (vendor.interests.isNotEmpty) ...[
                        const Text('Categories', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: vendor.interests.map((c) => Chip(label: Text(c, style: const TextStyle(fontSize: 11)), padding: EdgeInsets.zero)).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Vehicle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                Text(vendor.vehicle.isNotEmpty ? vendor.vehicle : 'Not provided', style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                Text(vendor.locationName.isNotEmpty ? vendor.locationName : 'Not set', style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _rejectVendor(vendor),
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text('Reject', style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => _approveVendor(vendor),
                            style: FilledButton.styleFrom(backgroundColor: Colors.green),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                          ),
                        ],
                      )
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
}
