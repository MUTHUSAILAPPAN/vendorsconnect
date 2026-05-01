import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/report_reasons.dart';
import '../../models/app_user.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import 'vendor_request_screen.dart';

class VendorProfileScreen extends StatefulWidget {
  final AppUser vendor;

  const VendorProfileScreen({super.key, required this.vendor});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final firestoreService = FirestoreService();
  late AppUser vendor;
  bool loadingFollow = false;

  @override
  void initState() {
    super.initState();
    vendor = widget.vendor;
  }

  Future<void> toggleFollow() async {
    final provider = context.read<AppProvider>();
    final resident = provider.currentUser;
    if (resident == null || loadingFollow) return;

    setState(() => loadingFollow = true);
    try {
      final isFollowing = resident.following.contains(vendor.id);
      if (isFollowing) {
        await firestoreService.unfollowVendor(residentId: resident.id, vendorId: vendor.id);
        provider.updateUser(resident.copyWith(following: resident.following.where((id) => id != vendor.id).toList()));
      } else {
        await firestoreService.followVendor(residentId: resident.id, vendorId: vendor.id);
        provider.updateUser(resident.copyWith(following: [...resident.following, vendor.id]));
      }
      final freshVendor = await firestoreService.getUser(vendor.id);
      if (freshVendor != null && mounted) setState(() => vendor = freshVendor);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isFollowing ? 'Vendor unfollowed' : 'Now following ${vendor.name}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => loadingFollow = false);
    }
  }

  Future<void> toggleMute() async {
    final provider = context.read<AppProvider>();
    final resident = provider.currentUser;
    if (resident == null) return;

    final isMuted = resident.mutedVendorIds.contains(vendor.id);
    
    try {
      if (isMuted) {
        await firestoreService.unmuteVendor(resident, vendor.id);
        provider.updateUser(resident.copyWith(
          mutedVendorIds: resident.mutedVendorIds.where((id) => id != vendor.id).toList(),
        ));
      } else {
        await firestoreService.muteVendor(resident, vendor.id);
        provider.updateUser(resident.copyWith(
          mutedVendorIds: [...resident.mutedVendorIds, vendor.id],
        ));
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isMuted ? 'Vendor unmuted' : 'Vendor muted')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _reportVendor() async {
    final resident = context.read<AppProvider>().currentUser;
    if (resident == null) return;

    String? selectedReason;
    final detailsController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report Vendor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: reportReasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setState(() => selectedReason = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(labelText: 'Details (Optional)', border: OutlineInputBorder()),
                  maxLines: 3,
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (selectedReason != null) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedReason != null) {
      try {
        await firestoreService.createReport(
          reporterId: resident.id,
          reporterName: resident.name,
          reportedUserId: vendor.id,
          reportedUserName: vendor.name,
          reason: selectedReason!,
          details: detailsController.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted successfully')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit report: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AppProvider>().currentUser;
    final isFollowing = currentUser?.following.contains(vendor.id) ?? false;
    final colorScheme = Theme.of(context).colorScheme;
    final initial = vendor.name.isEmpty ? '?' : vendor.name[0].toUpperCase();

    if (vendor.approvalStatus != 'approved') {
      return Scaffold(
        appBar: AppBar(title: Text(vendor.name)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'This vendor profile is currently unavailable.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(vendor.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.report_problem_outlined),
            tooltip: 'Report Vendor',
            onPressed: _reportVendor,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(0),
        children: [
          // ── Header card ──────────────────────────
          Container(
            color: colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: vendor.isAvailable
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  child: Text(initial,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: vendor.isAvailable ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      )),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vendor.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            vendor.isAvailable ? Icons.circle : Icons.circle_outlined,
                            size: 10,
                            color: vendor.isAvailable ? Colors.green : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            vendor.isAvailable ? 'Available now' : 'Not available',
                            style: TextStyle(
                              color: vendor.isAvailable ? Colors.green.shade700 : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (vendor.followers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('${vendor.followers.length} follower(s)',
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Follow button ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: FilledButton.icon(
              onPressed: loadingFollow ? null : toggleFollow,
              style: isFollowing
                  ? FilledButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      foregroundColor: colorScheme.onSurfaceVariant,
                    )
                  : null,
              icon: loadingFollow
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(isFollowing ? Icons.favorite : Icons.favorite_border),
              label: Text(loadingFollow ? 'Updating...' : isFollowing ? 'Unfollow' : 'Follow'),
            ),
          ),

          // ── Ask Vendor ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: FilledButton.tonalIcon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => VendorRequestScreen(vendor: vendor)),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Ask Vendor a Question'),
            ),
          ),

          // ── Notification Preferences ────────────
          if (isFollowing) ...[
            const _SectionHeader('Notification Preferences'),
            ListTile(
              leading: Icon(
                (currentUser?.mutedVendorIds.contains(vendor.id) ?? false)
                    ? Icons.notifications_off
                    : Icons.notifications_active,
              ),
              title: Text((currentUser?.mutedVendorIds.contains(vendor.id) ?? false)
                  ? 'Unmute notifications'
                  : 'Mute notifications'),
              subtitle: Text((currentUser?.mutedVendorIds.contains(vendor.id) ?? false)
                  ? 'You are not receiving notifications from this vendor'
                  : 'Receive notifications when this vendor reaches a street'),
              onTap: toggleMute,
            ),
          ],

          // ── Details section ─────────────────────
          if (vendor.bio.isNotEmpty || vendor.vehicle.isNotEmpty || vendor.locationName.isNotEmpty) ...[
            const _SectionHeader('Details'),
            if (vendor.bio.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Bio'),
                subtitle: Text(vendor.bio),
              ),
            if (vendor.vehicle.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: const Text('Vehicle'),
                subtitle: Text(vendor.vehicle),
              ),
            if (vendor.locationName.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Current location'),
                subtitle: Text(vendor.locationName),
              ),
          ],

          // ── Categories ──────────────────────────
          if (vendor.interests.isNotEmpty) ...[
            const _SectionHeader('Categories'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: vendor.interests.map((c) => Chip(label: Text(c))).toList(),
              ),
            ),
          ],

          // ── Menu ────────────────────────────────
          const _SectionHeader('Menu'),
          if (vendor.menu.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('No menu items added.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            )
          else
            for (final item in vendor.menu)
              ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: Text(item),
              ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
