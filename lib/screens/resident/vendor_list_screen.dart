import 'package:flutter/material.dart';

import '../../constants/vendor_categories.dart';
import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import 'vendor_profile_screen.dart';

class VendorListScreen extends StatefulWidget {
  const VendorListScreen({super.key});

  @override
  State<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends State<VendorListScreen> {
  final firestoreService = FirestoreService();
  final List<String> selectedCategories = [];

  void toggleCategory(String category) {
    setState(() {
      if (selectedCategories.contains(category)) {
        selectedCategories.remove(category);
      } else {
        selectedCategories.add(category);
      }
    });
  }

  List<AppUser> filterVendors(List<AppUser> vendors) {
    if (selectedCategories.isEmpty) return vendors;
    return vendors.where((v) => v.interests.any(selectedCategories.contains)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Category filter chips ─────────────────
        SizedBox(
          height: 58,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('All'),
                  selected: selectedCategories.isEmpty,
                  onSelected: (_) => setState(() => selectedCategories.clear()),
                ),
              ),
              ...vendorCategories.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: selectedCategories.contains(category),
                    onSelected: (_) => toggleCategory(category),
                  ),
                );
              }),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<AppUser>>(
            stream: firestoreService.vendorsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off, size: 48, color: colorScheme.error),
                        const SizedBox(height: 12),
                        Text('Could not load vendors', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(snapshot.error.toString().replaceAll('Exception: ', ''),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final vendors = filterVendors(snapshot.data!);

              if (vendors.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_outlined, size: 56, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text('No vendors found',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        Text(
                          selectedCategories.isEmpty
                              ? 'No vendors have registered yet.'
                              : 'No vendors match the selected filter.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: vendors.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final vendor = vendors[index];
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (vendor.isAvailable && vendor.locationName.isNotEmpty)
                          Text(
                            vendor.locationName,
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => VendorProfileScreen(vendor: vendor)),
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
}
