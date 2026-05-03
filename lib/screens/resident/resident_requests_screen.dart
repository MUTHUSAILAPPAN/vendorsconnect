import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/vendor_request.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/app_user.dart';
import 'request_detail_screen.dart';
import 'vendor_request_screen.dart';

class ResidentRequestsScreen extends StatelessWidget {
  const ResidentRequestsScreen({super.key});

  void _showVendorSelection(BuildContext context, AppUser resident) {
    final firestoreService = FirestoreService();
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt),
                  const SizedBox(width: 12),
                  Text(
                    'Select a Vendor',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<AppUser>>(
                stream: firestoreService.vendorsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final followed = snapshot.data!
                      .where((v) => resident.following.contains(v.id))
                      .where((v) => !resident.blockedUserIds.contains(v.id))
                      .toList();

                  if (followed.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite_border, size: 48, color: colorScheme.onSurfaceVariant),
                            const SizedBox(height: 16),
                            const Text(
                              'Follow a vendor first to create a request.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Go to the map or browse vendors to find someone to follow.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: followed.length,
                    itemBuilder: (context, index) {
                      final vendor = followed[index];
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
                        subtitle: Text(vendor.bio, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => VendorRequestScreen(vendor: vendor)),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resident = context.watch<AppProvider>().currentUser;
    if (resident == null) return const Scaffold(body: Center(child: Text('Please login')));

    return Scaffold(
      appBar: AppBar(title: const Text('My Requests')),
      body: StreamBuilder(
        stream: FirestoreService().residentRequestsStream(resident.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('You have not made any requests yet.'));
          }

          final requests = docs.map((d) => VendorRequest.fromMap(d.id, d.data())).toList();
          requests.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return ListTile(
                title: Text('To: ${req.vendorName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.question),
                    if (req.status == 'answered')
                      Text('Status: Answered', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold))
                    else
                      Text('Status: ${req.status}', style: const TextStyle(color: Colors.orange)),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailScreen(request: req)));
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVendorSelection(context, resident),
        label: const Text('New Request'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
