import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final firestoreService = FirestoreService();
  final locationService = LocationService();

  final vehicleController = TextEditingController();
  final itemController = TextEditingController();
  final priceController = TextEditingController();

  final List<String> menuItems = [];
  bool initialized = false;
  bool saving = false;
  bool updatingLocation = false;
  bool updatingAvailability = false;

  @override
  void dispose() {
    vehicleController.dispose();
    itemController.dispose();
    priceController.dispose();
    super.dispose();
  }

  void initializeFields(AppUser user) {
    if (initialized) return;
    vehicleController.text = user.vehicle;
    menuItems..clear()..addAll(user.menu);
    initialized = true;
  }

  void addMenuItem() {
    final item = itemController.text.trim();
    final priceText = priceController.text.trim();
    if (item.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item name is required')));
      return;
    }
    if (priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price is required')));
      return;
    }
    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price must be a number greater than 0')));
      return;
    }
    setState(() {
      menuItems.add('$item - ₹$priceText');
      itemController.clear();
      priceController.clear();
    });
  }

  void removeMenuItem(int index) => setState(() => menuItems.removeAt(index));

  Future<void> saveVendor(AppUser user, AppProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final updated = user.copyWith(menu: menuItems, vehicle: vehicleController.text.trim());
      await firestoreService.updateUser(updated);
      provider.updateUser(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> toggleAvailability(AppUser user, AppProvider provider) async {
    setState(() => updatingAvailability = true);
    try {
      final updated = user.copyWith(isAvailable: !user.isAvailable);
      await firestoreService.updateUser(updated);
      provider.updateUser(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => updatingAvailability = false);
    }
  }

  Future<void> updateLocation(AppUser user, AppProvider provider) async {
    setState(() => updatingLocation = true);
    try {
      final result = await locationService.getCurrentLocation();
      if (result == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not get location')));
        return;
      }
      final updated = user.copyWith(location: result.point, locationName: result.placeName);
      await firestoreService.updateUser(updated);
      provider.updateUser(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location updated: ${result.placeName}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => updatingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.currentUser;
    if (user == null) return const Center(child: Text('Please login'));

    initializeFields(user);
    final busy = saving || updatingLocation || updatingAvailability;
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Approval Banner ────────────────────────
          if (user.approvalStatus == 'pending')
            Material(
              color: Colors.orange.shade100,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.pending_actions, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(child: Text('Your vendor account is pending admin approval. Residents cannot see your profile yet.', style: TextStyle(color: Colors.deepOrange))),
                  ],
                ),
              ),
            ),
          if (user.approvalStatus == 'rejected')
            Material(
              color: Colors.red.shade100,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Your account was rejected. Reason: ${user.rejectionReason}', style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            ),
          // ── Header ─────────────────────────────
          Container(
            color: colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          if (user.bio.isNotEmpty)
                            Text(user.bio, style: TextStyle(color: colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (user.locationName.isNotEmpty)
                            Row(children: [
                              Icon(Icons.location_on_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 2),
                              Expanded(child: Text(user.locationName, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ]),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => updateLocation(user, provider),
                  icon: updatingLocation
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(updatingLocation ? 'Updating...' : 'Update Location'),
                ),
              ],
            ),
          ),

          // ── Availability toggle ─────────────────
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SwitchListTile(
              secondary: Icon(user.isAvailable ? Icons.storefront : Icons.store_outlined,
                  color: user.isAvailable ? colorScheme.primary : colorScheme.onSurfaceVariant),
              title: const Text('Available to customers'),
              subtitle: updatingAvailability
                  ? const Text('Updating...')
                  : Text(user.isAvailable ? 'Customers can see you online' : 'You are hidden from customers'),
              value: user.isAvailable,
              onChanged: busy ? null : (_) => toggleAvailability(user, provider),
            ),
          ),

          // ── Vehicle ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Text('VEHICLE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.primary, letterSpacing: 1, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextFormField(
              controller: vehicleController,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Vehicle info', prefixIcon: Icon(Icons.local_shipping_outlined)),
            ),
          ),

          // ── Menu ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(
              children: [
                Text('MENU', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.primary, letterSpacing: 1, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${menuItems.length} item(s)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: TextField(controller: itemController, enabled: !busy, decoration: const InputDecoration(labelText: 'Item', hintText: 'Apple'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: priceController, enabled: !busy, decoration: const InputDecoration(labelText: 'Price (₹)', hintText: '30'), keyboardType: TextInputType.number)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filled(icon: const Icon(Icons.add), onPressed: busy ? null : addMenuItem),
                ),
              ],
            ),
          ),
          if (menuItems.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text('No menu items added.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            )
          else
            Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(children: [
                for (int i = 0; i < menuItems.length; i++)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.restaurant_menu, size: 18),
                    title: Text(menuItems[i]),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: busy ? null : () => removeMenuItem(i)),
                  ),
              ]),
            ),

          // ── Save button ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: FilledButton(
              onPressed: busy ? null : () => saveVendor(user, provider),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Profile', style: TextStyle(fontSize: 16)),
            ),
          ),

          const Divider(height: 32),

          // ── Followers ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('FOLLOWERS (${user.followers.length})',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.primary, letterSpacing: 1, fontWeight: FontWeight.w600)),
          ),
          if (user.followers.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('No followers yet.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            )
          else
            StreamBuilder<List<AppUser>>(
              stream: firestoreService.followersStream(user.followers),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ListTile(leading: const Icon(Icons.error_outline), title: const Text('Could not load followers'));
                }
                if (!snapshot.hasData) {
                  return const ListTile(title: Text('Loading followers...'));
                }
                final followers = snapshot.data!;
                if (followers.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text('No followers yet.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  );
                }
                return Column(children: followers.map((f) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
                  title: Text(f.name),
                  subtitle: Text(f.phone),
                )).toList());
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
