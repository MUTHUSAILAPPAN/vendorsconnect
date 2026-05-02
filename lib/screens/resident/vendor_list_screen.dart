import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../constants/vehicle_options.dart';
import '../../constants/vendor_categories.dart';
import '../../models/app_user.dart';
import '../../providers/app_provider.dart';
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
  String searchQuery = '';
  String selectedVehicle = 'All';
  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void toggleCategory(String category) {
    setState(() {
      if (selectedCategories.contains(category)) {
        selectedCategories.remove(category);
      } else {
        selectedCategories.add(category);
      }
    });
  }

  List<AppUser> filterAndSortVendors(List<AppUser> vendors, AppUser? currentUser) {
    List<AppUser> filtered = vendors;
    
    // Approval filter
    filtered = filtered.where((v) => v.approvalStatus == 'approved').toList();

    // Blocked users filter
    if (currentUser != null && currentUser.blockedUserIds.isNotEmpty) {
      filtered = filtered.where((v) => !currentUser.blockedUserIds.contains(v.id)).toList();
    }

    // Category filter
    if (selectedCategories.isNotEmpty) {
      filtered = filtered.where((v) => v.interests.any(selectedCategories.contains)).toList();
    }

    // Vehicle filter
    if (selectedVehicle != 'All') {
      filtered = filtered.where((v) => v.vehicle == selectedVehicle).toList();
    }

    // Search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((v) {
        final matchesName = v.name.toLowerCase().contains(query);
        final matchesLocation = v.locationName.toLowerCase().contains(query);
        final matchesMenu = v.menu.any((item) => item.toLowerCase().contains(query));
        final matchesCategories = v.interests.any((cat) => cat.toLowerCase().contains(query));
        return matchesName || matchesLocation || matchesMenu || matchesCategories;
      }).toList();
    }

    final userLocation = currentUser?.location;
    if (userLocation != null) {
      final userLat = userLocation.latitude;
      final userLng = userLocation.longitude;
      const distanceCalculator = Distance();

      filtered.sort((a, b) {
        if (a.location == null && b.location == null) return 0;
        if (a.location == null) return 1;
        if (b.location == null) return -1;

        final distA = distanceCalculator.as(
            LengthUnit.Meter, LatLng(userLat, userLng), LatLng(a.location!.latitude, a.location!.longitude));
        final distB = distanceCalculator.as(
            LengthUnit.Meter, LatLng(userLat, userLng), LatLng(b.location!.latitude, b.location!.longitude));
        return distA.compareTo(distB);
      });
    }
    return filtered;
  }

  String _formatDistance(AppUser vendor, AppUser? currentUser) {
    final userLocation = currentUser?.location;
    if (userLocation == null || vendor.location == null) return '';
    final distance = const Distance().as(
        LengthUnit.Meter,
        LatLng(userLocation.latitude, userLocation.longitude),
        LatLng(vendor.location!.latitude, vendor.location!.longitude));

    if (distance < 1000) {
      return '${distance.round()}m away';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km away';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Search Bar ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SearchBar(
            controller: searchController,
            hintText: 'Search vendors, items, or locations...',
            leading: const Icon(Icons.search),
            trailing: [
              if (searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    searchController.clear();
                    setState(() => searchQuery = '');
                  },
                ),
            ],
            onChanged: (v) => setState(() => searchQuery = v),
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),

        // ── Category filter chips ─────────────────
        SizedBox(
          height: 52,
          child: StreamBuilder<List<String>>(
            stream: firestoreService.configValuesStream('vendor_categories'),
            initialData: vendorCategories,
            builder: (context, snapshot) {
              final categories = snapshot.data ?? vendorCategories;
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All Categories'),
                      selected: selectedCategories.isEmpty,
                      onSelected: (_) => setState(() => selectedCategories.clear()),
                    ),
                  ),
                  ...categories.map((category) {
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
              );
            },
          ),
        ),

        // ── Vehicle filter chips ──────────────────
        SizedBox(
          height: 52,
          child: StreamBuilder<List<String>>(
            stream: firestoreService.configValuesStream('vehicle_options'),
            initialData: defaultVehicleOptions,
            builder: (context, snapshot) {
              final options = snapshot.data ?? defaultVehicleOptions;
              final allOptions = ['All', ...options];
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: allOptions.map((opt) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(opt == 'All' ? 'All Vehicles' : opt),
                      selected: selectedVehicle == opt,
                      onSelected: (_) => setState(() => selectedVehicle = opt),
                      avatar: opt == 'All' ? null : Icon(_getVehicleIcon(opt), size: 16),
                    ),
                  );
                }).toList(),
              );
            },
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

              final currentUser = context.watch<AppProvider>().currentUser;
              final vendors = filterAndSortVendors(snapshot.data!, currentUser);

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
                          searchQuery.isNotEmpty || selectedCategories.isNotEmpty || selectedVehicle != 'All'
                              ? 'No vendors match your search/filters.'
                              : (currentUser?.location == null
                                  ? 'No vendors have registered yet. Set your location to see nearest vendors.'
                                  : 'No vendors have registered yet.'),
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
                            if (vendor.currentRouteId.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.directions_run, size: 10, color: colorScheme.primary),
                                    const SizedBox(width: 2),
                                    Text(
                                      'On route now',
                                      style: TextStyle(color: colorScheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (vendor.availableFrom.isNotEmpty && vendor.availableTo.isNotEmpty)
                              Expanded(
                                child: Text(
                                  ' • ${vendor.availableFrom} - ${vendor.availableTo}',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                        if (currentUser?.location != null && vendor.location != null)
                          Text(
                            _formatDistance(vendor, currentUser),
                            style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                        if (currentUser?.location == null)
                          Text(
                            'Set your location to see distance',
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
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

  IconData _getVehicleIcon(String vehicle) {
    switch (vehicle) {
      case 'Bicycle':
        return Icons.directions_bike;
      case 'Two Wheeler':
        return Icons.two_wheeler;
      case 'Auto':
        return Icons.electric_rickshaw;
      case 'Van':
        return Icons.airport_shuttle;
      case 'Mini Truck':
        return Icons.local_shipping;
      case 'Push Cart':
        return Icons.shopping_cart;
      case 'By Walk':
        return Icons.directions_walk;
      default:
        return Icons.location_on;
    }
  }
}
