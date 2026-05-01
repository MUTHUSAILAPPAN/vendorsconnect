import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/vendor_route.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import 'active_route_screen.dart';
import 'route_builder/map_route_builder_screen.dart';

class RouteManagementScreen extends StatelessWidget {
  const RouteManagementScreen({super.key});

  Future<void> confirmDeleteRoute({
    required BuildContext context,
    required FirestoreService firestoreService,
    required VendorRoute route,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete route?'),
        content: Text('Are you sure you want to delete "${route.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await firestoreService.deleteRoute(route.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted "${route.name}"')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))));
    }
  }

  Future<void> startRoute({
    required BuildContext context,
    required FirestoreService firestoreService,
    required String vendorId,
    required VendorRoute route,
  }) async {
    try {
      await firestoreService.setCurrentRoute(vendorId: vendorId, routeId: route.id);
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveRouteScreen(route: route)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser;
    final firestoreService = FirestoreService();
    final colorScheme = Theme.of(context).colorScheme;

    if (user == null) return const Center(child: Text('Please login'));

    return Scaffold(
      body: StreamBuilder<List<VendorRoute>>(
        stream: firestoreService.vendorRoutesStream(user.id),
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
                    Text('Could not load routes', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(snapshot.error.toString().replaceAll('Exception: ', ''), textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final routes = snapshot.data!;

          if (routes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.route, size: 64, color: colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text('No routes yet', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the button below to draw a new route on the map.',
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
            itemCount: routes.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 16),
            itemBuilder: (context, index) {
              final route = routes[index];
              final stopCount = route.streets.length;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text('${index + 1}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                ),
                title: Text(route.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  stopCount == 0 ? 'No stops' : '$stopCount stop${stopCount > 1 ? "s" : ""} • ${route.streets.take(3).join(" → ")}${stopCount > 3 ? "…" : ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                onTap: () => startRoute(context: context, firestoreService: firestoreService, vendorId: user.id, route: route),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'start') startRoute(context: context, firestoreService: firestoreService, vendorId: user.id, route: route);
                    if (value == 'delete') confirmDeleteRoute(context: context, firestoreService: firestoreService, route: route);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'start', child: ListTile(leading: Icon(Icons.play_arrow), title: Text('Start route'), contentPadding: EdgeInsets.zero)),
                    PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete route'), contentPadding: EdgeInsets.zero)),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_location_alt),
        label: const Text('New Route'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapRouteBuilderScreen())),
      ),
    );
  }
}
