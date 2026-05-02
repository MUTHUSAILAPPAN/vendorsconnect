import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/vehicle_options.dart';
import '../../constants/vendor_categories.dart';
import '../../models/app_user.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import 'vendor_profile_screen.dart';

class ResidentMapScreen extends StatefulWidget {
  const ResidentMapScreen({super.key});

  @override
  State<ResidentMapScreen> createState() => _ResidentMapScreenState();
}

class _ResidentMapScreenState extends State<ResidentMapScreen> {
  final firestoreService = FirestoreService();

  final List<String> selectedCategories = [];
  bool onlyAvailable = false;
  String selectedVehicle = 'All';

  void toggleCategory(String category) {
    setState(() {
      if (selectedCategories.contains(category)) {
        selectedCategories.remove(category);
      } else {
        selectedCategories.add(category);
      }
    });
  }

  List<AppUser> filterVendors(List<AppUser> vendors, AppUser? currentUser) {
    return vendors.where((vendor) {
      final isBlocked = currentUser?.blockedUserIds.contains(vendor.id) ?? false;
      final isApproved = vendor.approvalStatus == 'approved';
      final hasLocation = vendor.location != null;
      final matchesAvailability = !onlyAvailable || vendor.isAvailable;
      final matchesCategories = selectedCategories.isEmpty ||
          vendor.interests.any(selectedCategories.contains);
      final matchesVehicle = selectedVehicle == 'All' || vendor.vehicle == selectedVehicle;

      return !isBlocked && isApproved && hasLocation && matchesAvailability && matchesCategories && matchesVehicle;
    }).toList();
  }

  void _showVendorDetails(AppUser vendor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      vendor.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: vendor.isAvailable
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      vendor.isAvailable ? 'Available' : 'Unavailable',
                      style: TextStyle(
                        color: vendor.isAvailable
                            ? Colors.green.shade800
                            : Colors.grey.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      vendor.locationName,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (vendor.interests.isNotEmpty) ...[
                const Text('Categories',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: vendor.interests
                      .map((cat) => Chip(
                            label: Text(cat, style: const TextStyle(fontSize: 12)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              if (vendor.menu.isNotEmpty) ...[
                const Text('Menu Preview',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  vendor.menu.take(3).join(', ') +
                      (vendor.menu.length > 3 ? '...' : ''),
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VendorProfileScreen(vendor: vendor),
                      ),
                    );
                  },
                  child: const Text('View Profile'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: firestoreService.vendorsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final currentUser = context.watch<AppProvider>().currentUser;
        final vendors = filterVendors(snapshot.data!, currentUser);

        final userLocation = currentUser?.location;
        final mapCenter = userLocation != null
            ? LatLng(userLocation.latitude, userLocation.longitude)
            : const LatLng(19.0760, 72.8777);

        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: mapCenter,
                initialZoom: 12,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.vendors_connect',
                ),
                MarkerLayer(
                  markers: [
                    if (userLocation != null)
                      Marker(
                        point:
                            LatLng(userLocation.latitude, userLocation.longitude),
                        width: 50,
                        height: 50,
                        child: const Icon(Icons.person_pin_circle,
                            color: Colors.blue, size: 40),
                      ),
                    ...vendors.map((vendor) {
                      final location = vendor.location!;

                      return Marker(
                        point: LatLng(location.latitude, location.longitude),
                        width: 100,
                        height: 60,
                        alignment: Alignment.topCenter,
                        child: _VendorMarker(
                          vendor: vendor,
                          onTap: () => _showVendorDetails(vendor),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Only available vendors'),
                        value: onlyAvailable,
                        onChanged: (value) {
                          setState(() => onlyAvailable = value);
                        },
                      ),
                      SizedBox(
                        height: 44,
                        child: StreamBuilder<List<String>>(
                          stream: firestoreService.configValuesStream('vendor_categories'),
                          initialData: vendorCategories,
                          builder: (context, snapshot) {
                            final categories = snapshot.data ?? vendorCategories;
                            return ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: const Text('All'),
                                    selected: selectedCategories.isEmpty,
                                    onSelected: (_) {
                                      setState(() => selectedCategories.clear());
                                    },
                                  ),
                                ),
                                ...categories.map((category) {
                                  final selected =
                                      selectedCategories.contains(category);

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(category),
                                      selected: selected,
                                      onSelected: (_) => toggleCategory(category),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        height: 44,
                        child: StreamBuilder<List<String>>(
                          stream: firestoreService.configValuesStream('vehicle_options'),
                          initialData: defaultVehicleOptions,
                          builder: (context, snapshot) {
                            final options = snapshot.data ?? defaultVehicleOptions;
                            final allOptions = ['All', ...options];
                            return ListView(
                              scrollDirection: Axis.horizontal,
                              children: allOptions.map((opt) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(opt == 'All' ? 'All Vehicles' : opt),
                                    selected: selectedVehicle == opt,
                                    onSelected: (_) => setState(() => selectedVehicle = opt),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (vendors.isEmpty)
              const Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Card(
                  child: ListTile(
                    leading: Icon(Icons.info),
                    title: Text('No vendors match these filters'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VendorMarker extends StatelessWidget {
  final AppUser vendor;
  final VoidCallback onTap;

  const _VendorMarker({required this.vendor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = vendor.isAvailable ? Colors.green : Colors.red;
    final icon = _getVehicleIcon(vendor.vehicle);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 30,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              vendor.name,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
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
