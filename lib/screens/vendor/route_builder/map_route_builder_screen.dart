import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../models/selected_street.dart';
import '../../../providers/app_provider.dart';
import '../../../services/firestore_service.dart';
import '../../../services/location_service.dart';
import '../../../services/street_service.dart';
import 'widgets/place_search_bar.dart';
import 'widgets/selected_streets_panel.dart';

class MapRouteBuilderScreen extends StatefulWidget {
  const MapRouteBuilderScreen({super.key});

  @override
  State<MapRouteBuilderScreen> createState() => _MapRouteBuilderScreenState();
}

class _MapRouteBuilderScreenState extends State<MapRouteBuilderScreen> {
  final firestoreService = FirestoreService();
  final streetService = StreetService();
  final locationService = LocationService();
  final mapController = MapController();

  // Route name lives in the panel, not a dialog
  final routeNameController = TextEditingController();

  final List<SelectedStreet> selectedStreets = [];

  bool fetchingStreet = false;
  bool fetchingLocation = false;
  bool saving = false;

  // Last tapped point – used to display "Locating street..." overlay
  LatLng? lastTappedPoint;
  LatLng? currentLocation;

  // Distance helper for smart duplicate check
  final _distance = const Distance();

  @override
  void dispose() {
    routeNameController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Back navigation guard
  // ─────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    if (selectedStreets.isEmpty) return true;

    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard route?'),
        content: Text(
          'You have ${selectedStreets.length} street${selectedStreets.length > 1 ? "s" : ""} selected. '
          'Leaving now will discard them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  // ─────────────────────────────────────────────
  // Map tap → fetch nearest street via Overpass
  // ─────────────────────────────────────────────

  Future<void> onMapTap(LatLng tappedPoint) async {
    if (fetchingStreet) return;

    setState(() {
      fetchingStreet = true;
      lastTappedPoint = tappedPoint;
    });

    try {
      final street = await streetService.fetchNearestStreet(tappedPoint);

      if (!mounted) return;

      if (street == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No road found near that point.'),
            action: SnackBarAction(
              label: 'Tips',
              onPressed: () => _showTipsDialog(),
            ),
          ),
        );
        return;
      }

      // Smart duplicate check: same name AND center within 100 m
      final alreadyAdded = selectedStreets.any((s) {
        if (s.name != street.name) return false;
        final dist = _distance(s.center, street.center);
        return dist < 100;
      });

      if (alreadyAdded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${street.name}" is already in your route.'),
          ),
        );
        return;
      }

      // ── Prompt if "Unnamed" ─────────────────────
      if (street.name.toLowerCase().contains('unnamed')) {
        final newName = await _showRenameDialog(street.name);
        if (newName != null && newName.trim().isNotEmpty) {
          final renamed = street.copyWith(name: newName.trim());
          setState(() => selectedStreets.add(renamed));
          return;
        }
      }

      setState(() => selectedStreets.add(street));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          fetchingStreet = false;
          lastTappedPoint = null;
        });
      }
    }
  }

  void _showTipsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tips for selecting streets'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TipRow(icon: Icons.zoom_in, text: 'Zoom in more before tapping — streets need to be visible on screen.'),
            SizedBox(height: 10),
            _TipRow(icon: Icons.touch_app, text: 'Tap directly on a road line, not on an intersection or building.'),
            SizedBox(height: 10),
            _TipRow(icon: Icons.wifi_off, text: 'Check your internet connection — street data comes from OpenStreetMap.'),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Fetch current GPS location
  // ─────────────────────────────────────────────

  Future<void> goToCurrentLocation() async {
    setState(() => fetchingLocation = true);
    try {
      final result = await locationService.getCurrentLocation();
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location')),
        );
        return;
      }
      final latLng = LatLng(result.point.latitude, result.point.longitude);
      setState(() => currentLocation = latLng);
      mapController.move(latLng, 16);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => fetchingLocation = false);
    }
  }

  // ─────────────────────────────────────────────
  // Move map to search result
  // ─────────────────────────────────────────────

  void onSearchLocationSelected(LatLng location, String name) {
    mapController.move(location, 15);
  }

  // ─────────────────────────────────────────────
  // Reorder / remove streets
  // ─────────────────────────────────────────────

  void onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = selectedStreets.removeAt(oldIndex);
      selectedStreets.insert(newIndex, item);
    });
  }

  void onRemove(int index) {
    setState(() => selectedStreets.removeAt(index));
  }

  void onRenameStreet(int index, String newName) {
    setState(() {
      selectedStreets[index] = selectedStreets[index].copyWith(name: newName);
    });
  }

  Future<String?> _showRenameDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Street'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Street Name',
            hintText: 'Enter custom street name',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Save route (name comes from bottom panel field)
  // ─────────────────────────────────────────────

  Future<void> saveRoute() async {
    if (selectedStreets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one street for your route')),
      );
      return;
    }

    final routeName = routeNameController.text.trim();
    if (routeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a route name before saving')),
      );
      return;
    }

    final user = context.read<AppProvider>().currentUser;
    if (user == null) return;

    setState(() => saving = true);

    final streets = selectedStreets.map((s) => s.name).toList();
    final coordinates = selectedStreets
        .map((s) => GeoPoint(s.center.latitude, s.center.longitude))
        .toList();
    final streetGeometries = selectedStreets.map((s) {
      return s.geometry.map((p) => GeoPoint(p.latitude, p.longitude)).toList();
    }).toList();

    try {
      await firestoreService.createRoute(
        vendorId: user.id,
        name: routeName,
        streets: streets,
        coordinates: coordinates,
        streetGeometries: streetGeometries,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Route "$routeName" saved!')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  // ─────────────────────────────────────────────
  // Build map polylines (glow effect)
  // ─────────────────────────────────────────────

  List<Polyline> buildPolylines() {
    final polylines = <Polyline>[];

    for (final street in selectedStreets) {
      if (street.geometry.length < 2) continue;

      // Glow layer
      polylines.add(Polyline(
        points: street.geometry,
        color: Colors.blue.withValues(alpha: 0.25),
        strokeWidth: 12,
      ));

      // Solid layer on top
      polylines.add(Polyline(
        points: street.geometry,
        color: Colors.blue,
        strokeWidth: 4,
      ));
    }

    return polylines;
  }

  // ─────────────────────────────────────────────
  // Build numbered markers
  // ─────────────────────────────────────────────

  List<Marker> buildMarkers() {
    final markers = <Marker>[];

    for (int i = 0; i < selectedStreets.length; i++) {
      final street = selectedStreets[i];
      markers.add(Marker(
        point: street.center,
        width: 36,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.location_on, color: Colors.blue, size: 40),
            Positioned(
              top: 7,
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ));
    }

    // "Locating street..." tap indicator
    if (fetchingStreet && lastTappedPoint != null) {
      markers.add(Marker(
        point: lastTappedPoint!,
        width: 30,
        height: 30,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Padding(
            padding: EdgeInsets.all(5),
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        ),
      ));
    }

    // Current GPS location dot
    if (currentLocation != null) {
      markers.add(Marker(
        point: currentLocation!,
        width: 20,
        height: 20,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
      ));
    }

    return markers;
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canSave = selectedStreets.isNotEmpty && !saving;
    final bottomPanelHeight = selectedStreets.isEmpty ? 80.0 : 280.0;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Build Route'),
              if (selectedStreets.isNotEmpty)
                Text(
                  '${selectedStreets.length} street${selectedStreets.length > 1 ? "s" : ""} selected',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
            ],
          ),
          actions: [
            if (fetchingStreet)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: 'Tips',
                onPressed: _showTipsDialog,
              ),
          ],
        ),
        body: Stack(
          children: [
            // ── Map ──────────────────────────────────
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPanelHeight),
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(19.0760, 72.8777),
                    initialZoom: 13,
                    onTap: (_, point) => onMapTap(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.vendors_connect',
                    ),
                    PolylineLayer(polylines: buildPolylines()),
                    MarkerLayer(markers: buildMarkers()),
                  ],
                ),
              ),
            ),

            // ── "Locating street..." status banner ───
            if (fetchingStreet)
              Positioned(
                bottom: bottomPanelHeight + 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 10),
                        Text('Locating street…', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Search bar overlay ───────────────────
            Positioned(
              top: 8,
              left: 12,
              right: 60,
              child: PlaceSearchBar(
                onLocationSelected: onSearchLocationSelected,
              ),
            ),

            // ── Current location button ──────────────
            Positioned(
              top: 8,
              right: 12,
              child: FloatingActionButton.small(
                heroTag: 'locationBtn',
                tooltip: 'Go to my location',
                onPressed: fetchingLocation ? null : goToCurrentLocation,
                child: fetchingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),
          ],
        ),

        // ── Bottom panel ────────────────────────────
        bottomSheet: SelectedStreetsPanel(
          streets: selectedStreets,
          saveEnabled: canSave,
          saving: saving,
          routeNameController: routeNameController,
          onSave: saveRoute,
          onReorder: onReorder,
          onRemove: onRemove,
          onRename: onRenameStreet,
        ),
      ),
    );
  }
}

/// Small helper widget used in the tips dialog.
class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}