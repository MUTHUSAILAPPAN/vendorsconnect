import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/vendor_route.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';

enum RouteOperationMode { manual, autoGeofence, verifiedManual }

class ActiveRouteScreen extends StatefulWidget {
  final VendorRoute route;

  const ActiveRouteScreen({super.key, required this.route});

  @override
  State<ActiveRouteScreen> createState() => _ActiveRouteScreenState();
}

class _ActiveRouteScreenState extends State<ActiveRouteScreen> {
  final notificationService = NotificationService();
  final firestoreService = FirestoreService();
  final locationService = LocationService();
  final mapController = MapController();

  int currentIndex = 0;
  bool routeStarted = false;
  bool routeFinished = false;
  bool loading = false;
  final Set<int> reachedStops = {};
  LatLng? currentVendorLocation;

  RouteOperationMode selectedMode = RouteOperationMode.manual;
  StreamSubscription<Position>? _positionStreamSubscription;
  double? distanceToCurrentStop;
  static const double geofenceRadiusMeters = 40;

  @override
  void dispose() {
    _stopLocationTracking();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final res = await locationService.getCurrentLocation();
      if (res != null) {
        setState(() {
          currentVendorLocation = LatLng(res.point.latitude, res.point.longitude);
        });
      }
    } catch (_) {}
  }

  void _startLocationTracking() async {
    await _stopLocationTracking();

    try {
      // Check permissions first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permission is required for automatic detection. Switching to manual mode.'),
          ));
          setState(() => selectedMode = RouteOperationMode.manual);
        }
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location service is off. Switching to manual mode.'),
          ));
          setState(() => selectedMode = RouteOperationMode.manual);
        }
        return;
      }

      _positionStreamSubscription = locationService.getPositionStream().listen(
        (position) {
          if (!mounted) return;
          _onLocationUpdate(LatLng(position.latitude, position.longitude));
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location tracking error: $error. Switching to manual.')));
            setState(() => selectedMode = RouteOperationMode.manual);
          }
          _stopLocationTracking();
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start tracking: $e')));
        setState(() => selectedMode = RouteOperationMode.manual);
      }
    }
  }

  Future<void> _stopLocationTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    if (mounted) {
      setState(() {
        distanceToCurrentStop = null;
      });
    }
  }

  void _onLocationUpdate(LatLng location) {
    setState(() {
      currentVendorLocation = location;
    });

    if (!routeStarted || routeFinished || widget.route.coordinates.isEmpty) return;

    final target = widget.route.coordinates[currentIndex];
    final distance = Geolocator.distanceBetween(
      location.latitude,
      location.longitude,
      target.latitude,
      target.longitude,
    );

    setState(() {
      distanceToCurrentStop = distance;
    });

    if (selectedMode == RouteOperationMode.autoGeofence && distance <= geofenceRadiusMeters) {
      if (!reachedStops.contains(currentIndex)) {
        reachedStreet(autoTriggered: true);
      }
    }
  }

  Future<void> reachedStreet({bool autoTriggered = false}) async {
    final vendor = context.read<AppProvider>().currentUser;
    if (vendor == null || widget.route.streets.isEmpty || routeFinished || !routeStarted || reachedStops.contains(currentIndex)) return;

    // Mode-specific logic
    if (!autoTriggered) {
      if (selectedMode == RouteOperationMode.verifiedManual) {
        if (currentVendorLocation == null) {
          final confirm = await _showManualConfirmDialog(
            'Location Unavailable',
            'Could not verify your location. Send manual update instead?',
          );
          if (confirm != true) return;
        } else if (distanceToCurrentStop != null && distanceToCurrentStop! > geofenceRadiusMeters) {
          final confirm = await _showManualConfirmDialog(
            'Distance Warning',
            'You are about ${distanceToCurrentStop!.toInt()} meters away from this street. Send manual update anyway?',
          );
          if (confirm != true) return;
        }
      }
    }

    setState(() => loading = true);
    try {
      final street = widget.route.streets[currentIndex];
      
      String source = 'manual';
      String verificationStatus = 'unverified';
      String type = 'manual_arrival';

      if (autoTriggered) {
        source = 'geofence';
        verificationStatus = 'location_verified';
        type = 'geofence_arrival';
      } else if (selectedMode == RouteOperationMode.verifiedManual) {
        source = 'verified_manual';
        if (distanceToCurrentStop != null && distanceToCurrentStop! <= geofenceRadiusMeters) {
          verificationStatus = 'location_verified';
        } else {
          source = 'manual';
          verificationStatus = 'location_mismatch';
        }
      }

      await notificationService.notifyFollowers(
        vendorId: vendor.id,
        vendorName: vendor.name,
        followerIds: vendor.followers,
        street: street,
        type: type,
        source: source,
        verificationStatus: verificationStatus,
        distanceMeters: distanceToCurrentStop,
      );
      
      if (!mounted) return;
      setState(() {
        reachedStops.add(currentIndex);
        if (currentIndex < widget.route.streets.length - 1) {
          currentIndex++;
          // distance will update in next stream pulse
        } else {
          routeFinished = true;
          _stopLocationTracking();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Followers notified: $street')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<bool?> _showManualConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send Anyway')),
        ],
      ),
    );
  }

  void startRoute() {
    setState(() {
      routeStarted = true;
      routeFinished = false;
      currentIndex = 0;
      reachedStops.clear();
    });

    if (selectedMode != RouteOperationMode.manual) {
      if (widget.route.coordinates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This route does not have coordinates. Manual mode only.'),
        ));
        setState(() => selectedMode = RouteOperationMode.manual);
      } else {
        _startLocationTracking();
      }
    }
  }

  Future<void> finishRoute() async {
    final provider = context.read<AppProvider>();
    final vendor = provider.currentUser;
    if (vendor == null) return;

    setState(() => loading = true);
    try {
      await firestoreService.clearCurrentRoute(vendor.id);
      provider.updateUser(vendor.copyWith(currentRouteId: ''));
      if (!mounted) return;
      setState(() { routeFinished = true; routeStarted = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Route finished')));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  Widget build(BuildContext context) {
    final streets = widget.route.streets;
    final totalStops = streets.length;
    final reachedCount = reachedStops.length;
    final colorScheme = Theme.of(context).colorScheme;
    final progressValue = totalStops == 0 ? 0.0 : reachedCount / totalStops;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.route.name),
        actions: [
          if (widget.route.coordinates.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: () {
                if (currentVendorLocation != null) {
                  mapController.move(currentVendorLocation!, 15);
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(0),
        children: [
          // ── Map Section (Optional) ──────────────
          if (widget.route.coordinates.isNotEmpty)
            SizedBox(
              height: 240,
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: LatLng(
                    widget.route.coordinates.first.latitude,
                    widget.route.coordinates.first.longitude,
                  ),
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.vendors_connect',
                  ),
                  PolylineLayer(
                    polylines: [
                      if (widget.route.streetGeometries.isNotEmpty)
                        for (final geo in widget.route.streetGeometries)
                          Polyline(
                            points: geo.map((p) => LatLng(p.latitude, p.longitude)).toList(),
                            color: colorScheme.primary.withValues(alpha: 0.6),
                            strokeWidth: 6,
                          )
                      else
                        Polyline(
                          points: widget.route.coordinates
                              .map((p) => LatLng(p.latitude, p.longitude))
                              .toList(),
                          color: colorScheme.primary.withValues(alpha: 0.4),
                          strokeWidth: 4,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      // Stop markers
                      for (int i = 0; i < widget.route.coordinates.length; i++)
                        Marker(
                          point: LatLng(
                            widget.route.coordinates[i].latitude,
                            widget.route.coordinates[i].longitude,
                          ),
                          width: 32,
                          height: 32,
                          child: Icon(
                            reachedStops.contains(i)
                                ? Icons.check_circle
                                : i == currentIndex && routeStarted && !routeFinished
                                    ? Icons.location_on
                                    : Icons.circle,
                            color: reachedStops.contains(i)
                                ? Colors.green
                                : i == currentIndex && routeStarted && !routeFinished
                                    ? Colors.blue
                                    : Colors.grey,
                            size: i == currentIndex && routeStarted && !routeFinished ? 32 : 24,
                          ),
                        ),
                      // Current vendor location
                      if (currentVendorLocation != null)
                        Marker(
                          point: currentVendorLocation!,
                          width: 16,
                          height: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          // ── Progress header ─────────────────────
          Container(
            color: colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routeFinished
                                ? 'Route Complete! 🎉'
                                : routeStarted
                                    ? 'Route in Progress'
                                    : 'Ready to Start',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$reachedCount of $totalStops stop${totalStops != 1 ? "s" : ""} reached',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    // Circular progress badge
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progressValue,
                            strokeWidth: 5,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            color: routeFinished ? Colors.green : colorScheme.primary,
                          ),
                          Text(
                            '${(progressValue * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: routeFinished ? Colors.green : colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 8,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: routeFinished ? Colors.green : colorScheme.primary,
                  ),
                ),
                if (routeStarted && !routeFinished && selectedMode != RouteOperationMode.manual) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.gps_fixed, size: 14, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        distanceToCurrentStop != null 
                          ? 'Distance to current stop: ${distanceToCurrentStop!.toInt()} m'
                          : 'Tracking location...',
                        style: TextStyle(fontSize: 13, color: colorScheme.primary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Operation Mode ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OPERATION MODE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<RouteOperationMode>(
                  segments: const [
                    ButtonSegment(value: RouteOperationMode.manual, label: Text('Manual'), icon: Icon(Icons.touch_app, size: 16)),
                    ButtonSegment(value: RouteOperationMode.autoGeofence, label: Text('Auto'), icon: Icon(Icons.auto_awesome, size: 16)),
                    ButtonSegment(value: RouteOperationMode.verifiedManual, label: Text('Verify'), icon: Icon(Icons.verified_user, size: 16)),
                  ],
                  selected: {selectedMode},
                  onSelectionChanged: (newSelection) {
                    if (routeStarted && !routeFinished) {
                      // Handle mode change during active route
                      final newMode = newSelection.first;
                      if (newMode == RouteOperationMode.manual) {
                        _stopLocationTracking();
                      } else if (selectedMode == RouteOperationMode.manual) {
                        _startLocationTracking();
                      }
                    }
                    setState(() => selectedMode = newSelection.first);
                  },
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                if (selectedMode == RouteOperationMode.autoGeofence)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      'App will automatically notify when you are within ${geofenceRadiusMeters.toInt()}m of a stop.',
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                if (selectedMode == RouteOperationMode.verifiedManual)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      'Manual button will verify your location before sending.',
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),

          // ── Action buttons ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!routeStarted && !routeFinished)
                  FilledButton.icon(
                    onPressed: streets.isEmpty || loading ? null : startRoute,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(streets.isEmpty ? 'No stops in this route' : 'Start Route',
                        style: const TextStyle(fontSize: 16)),
                  )
                else if (routeFinished)
                  FilledButton.icon(
                    onPressed: loading ? null : finishRoute,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark as Complete', style: TextStyle(fontSize: 16)),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: loading ? null : reachedStreet,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.notifications_active),
                    label: Text(
                      loading ? 'Notifying followers...' : 'Reached: ${streets[currentIndex]}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: loading ? null : finishRoute,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('End Route Early'),
                  ),
                ],
              ],
            ),
          ),

          // ── Stops list ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'STOPS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (streets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('No streets in this route.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            )
          else
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (int i = 0; i < streets.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: reachedStops.contains(i)
                            ? Colors.green.withValues(alpha: 0.15)
                            : i == currentIndex && routeStarted && !routeFinished
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                        child: Icon(
                          reachedStops.contains(i)
                              ? Icons.check
                              : i == currentIndex && routeStarted && !routeFinished
                                  ? Icons.location_on
                                  : Icons.radio_button_unchecked,
                          size: 16,
                          color: reachedStops.contains(i)
                              ? Colors.green
                              : i == currentIndex && routeStarted && !routeFinished
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(
                        streets[i],
                        style: TextStyle(
                          fontWeight: i == currentIndex && routeStarted && !routeFinished
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: reachedStops.contains(i) ? colorScheme.onSurfaceVariant : null,
                          decoration: reachedStops.contains(i) ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: reachedStops.contains(i)
                          ? Text('✓ Reached', style: TextStyle(color: Colors.green.shade700, fontSize: 12))
                          : i == currentIndex && routeStarted && !routeFinished
                              ? Text('Current stop', style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w500))
                              : Text('Stop ${i + 1}', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
