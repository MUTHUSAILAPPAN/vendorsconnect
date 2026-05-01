import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/vendor_categories.dart';
import '../../models/app_user.dart';
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
    return vendors.where((vendor) {
      final hasLocation = vendor.location != null;
      final matchesAvailability = !onlyAvailable || vendor.isAvailable;
      final matchesCategories = selectedCategories.isEmpty ||
          vendor.interests.any(selectedCategories.contains);

      return hasLocation && matchesAvailability && matchesCategories;
    }).toList();
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

        final vendors = filterVendors(snapshot.data!);

        return Stack(
          children: [
            FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(19.0760, 72.8777),
                initialZoom: 12,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.vendors_connect',
                ),
                MarkerLayer(
                  markers: vendors.map((vendor) {
                    final location = vendor.location!;

                    return Marker(
                      point: LatLng(location.latitude, location.longitude),
                      width: 54,
                      height: 54,
                      child: IconButton(
                        icon: Icon(
                          Icons.location_on,
                          color:
                              vendor.isAvailable ? Colors.green : Colors.red,
                          size: 40,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VendorProfileScreen(vendor: vendor),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
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
                        child: ListView(
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
                            ...vendorCategories.map((category) {
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
