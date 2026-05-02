import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/vendor_route.dart';
import '../../models/app_user.dart';

class VendorActiveRouteMapScreen extends StatelessWidget {
  final AppUser vendor;
  final VendorRoute route;

  const VendorActiveRouteMapScreen({
    super.key,
    required this.vendor,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stops = route.streets;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vendor.name),
            Text(route.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Map Section ──────────────────────────
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: route.coordinates.isNotEmpty
                        ? LatLng(route.coordinates.first.latitude, route.coordinates.first.longitude)
                        : const LatLng(0, 0),
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.vendors_connect',
                    ),
                    if (route.coordinates.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          if (route.streetGeometries.isNotEmpty)
                            for (final geo in route.streetGeometries)
                              Polyline(
                                points: geo.map((p) => LatLng(p.latitude, p.longitude)).toList(),
                                color: colorScheme.primary.withValues(alpha: 0.6),
                                strokeWidth: 6,
                              )
                          else
                            Polyline(
                              points: route.coordinates
                                  .map((p) => LatLng(p.latitude, p.longitude))
                                  .toList(),
                              color: colorScheme.primary.withValues(alpha: 0.4),
                              strokeWidth: 4,
                            ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Numbered stop markers
                        for (int i = 0; i < route.coordinates.length; i++)
                          Marker(
                            point: LatLng(route.coordinates[i].latitude, route.coordinates[i].longitude),
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        // Vendor current location
                        if (vendor.location != null)
                          Marker(
                            point: LatLng(vendor.location!.latitude, vendor.location!.longitude),
                            width: 45,
                            height: 45,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                                  ),
                                  child: const Text('VENDOR', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                                const Icon(Icons.navigation, color: Colors.blue, size: 24),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Legend/Status overlay
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LegendItem(color: Colors.blue, label: 'Current Location'),
                        const SizedBox(height: 4),
                        _LegendItem(color: colorScheme.primary, label: 'Planned Stops'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Stops Section ────────────────────────
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PLANNED STOPS (${stops.length})',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Text(
                        'Updated just now',
                        style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (stops.isEmpty)
                  const Expanded(child: Center(child: Text('No stops defined for this route.')))
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: stops.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 40),
                      itemBuilder: (context, index) {
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            child: Text('${index + 1}', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                          ),
                          title: Text(stops[index], style: const TextStyle(fontSize: 14)),
                        );
                      },
                    ),
                  ),
                Container(
                  width: double.infinity,
                  color: colorScheme.surfaceContainerLow,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Note: Vendor location is based on their last updated location.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
