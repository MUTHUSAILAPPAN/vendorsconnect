import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/vendor_route.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';

class ActiveRouteScreen extends StatefulWidget {
  final VendorRoute route;

  const ActiveRouteScreen({super.key, required this.route});

  @override
  State<ActiveRouteScreen> createState() => _ActiveRouteScreenState();
}

class _ActiveRouteScreenState extends State<ActiveRouteScreen> {
  final notificationService = NotificationService();
  final firestoreService = FirestoreService();

  int currentIndex = 0;
  bool routeStarted = false;
  bool routeFinished = false;
  bool loading = false;
  final Set<int> reachedStops = {};

  Future<void> reachedStreet() async {
    final vendor = context.read<AppProvider>().currentUser;
    if (vendor == null || widget.route.streets.isEmpty || routeFinished || !routeStarted || reachedStops.contains(currentIndex)) return;

    setState(() => loading = true);
    try {
      final street = widget.route.streets[currentIndex];
      await notificationService.notifyFollowers(vendorId: vendor.id, vendorName: vendor.name, followerIds: vendor.followers, street: street);
      if (!mounted) return;
      setState(() {
        reachedStops.add(currentIndex);
        if (currentIndex < widget.route.streets.length - 1) {
          currentIndex++;
        } else {
          routeFinished = true;
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

  void startRoute() {
    setState(() {
      routeStarted = true;
      routeFinished = false;
      currentIndex = 0;
      reachedStops.clear();
    });
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
  Widget build(BuildContext context) {
    final streets = widget.route.streets;
    final totalStops = streets.length;
    final reachedCount = reachedStops.length;
    final colorScheme = Theme.of(context).colorScheme;
    final progressValue = totalStops == 0 ? 0.0 : reachedCount / totalStops;

    return Scaffold(
      appBar: AppBar(title: Text(widget.route.name)),
      body: ListView(
        padding: const EdgeInsets.all(0),
        children: [
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
