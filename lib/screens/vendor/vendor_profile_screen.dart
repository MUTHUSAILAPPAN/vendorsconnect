import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../constants/vehicle_options.dart';
import '../../constants/vendor_categories.dart';
import 'follower_profile_screen.dart';

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final firestoreService = FirestoreService();
  final locationService = LocationService();

  final nameController = TextEditingController();
  final bioController = TextEditingController();
  final itemController = TextEditingController();
  final priceController = TextEditingController();

  final List<String> menuItems = [];
  final List<String> selectedWorkingDays = [];
  String availableFrom = '';
  String availableTo = '';
  String? selectedVehicle;
  bool showRoutesPublicly = false;
  final List<String> selectedCategories = [];

  bool updatingVisibility = false;

  bool initialized = false;
  bool _isEditing = false;
  bool saving = false;
  bool updatingLocation = false;
  bool updatingAvailability = false;

  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    itemController.dispose();
    priceController.dispose();
    super.dispose();
  }

  void initializeFields(AppUser user, {bool force = false}) {
    if (initialized && !force) return;
    nameController.text = user.name;
    bioController.text = user.bio;
    selectedVehicle = user.vehicle;
    menuItems..clear()..addAll(user.menu);
    selectedWorkingDays..clear()..addAll(user.workingDays);
    availableFrom = user.availableFrom;
    availableTo = user.availableTo;
    showRoutesPublicly = user.showRoutesPublicly;
    selectedCategories..clear()..addAll(user.interests);
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
    if (availableFrom.isNotEmpty && availableTo.isEmpty || availableFrom.isEmpty && availableTo.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select both From and To times')));
      return;
    }
    setState(() => saving = true);
    try {
      final updated = user.copyWith(
        name: nameController.text.trim(),
        bio: bioController.text.trim(),
        menu: menuItems, 
        vehicle: selectedVehicle ?? '',
        workingDays: selectedWorkingDays,
        availableFrom: availableFrom,
        availableTo: availableTo,
        showRoutesPublicly: showRoutesPublicly,
        interests: selectedCategories,
      );
      await firestoreService.updateUser(updated);
      provider.updateUser(updated);
      if (!mounted) return;
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void cancelEdit(AppUser user) {
    setState(() {
      _isEditing = false;
      initializeFields(user, force: true);
    });
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

  Future<void> toggleRouteVisibility(AppUser user, AppProvider provider, bool value) async {
    setState(() {
      showRoutesPublicly = value;
      updatingVisibility = true;
    });
    try {
      final updated = user.copyWith(showRoutesPublicly: value);
      await firestoreService.updateUser(updated);
      provider.updateUser(updated);
    } catch (error) {
      if (!mounted) return;
      setState(() => showRoutesPublicly = !value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update visibility: $error')));
    } finally {
      if (mounted) setState(() => updatingVisibility = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.currentUser;
    if (user == null) return const Center(child: Text('Please login'));

    initializeFields(user);
    final busy = saving || updatingLocation || updatingAvailability || updatingVisibility;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Profile'),
        actions: [
          if (!_isEditing)
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
        ],
      ),
      body: Form(
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
                      Expanded(child: Text('Your account is pending admin approval.', style: TextStyle(color: Colors.deepOrange))),
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
                            if (!_isEditing) ...[
                              Text(user.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              if (user.bio.isNotEmpty)
                                Text(user.bio, style: TextStyle(color: colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ] else ...[
                              TextFormField(
                                controller: nameController,
                                decoration: const InputDecoration(labelText: 'Business Name', isDense: true),
                                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: bioController,
                                decoration: const InputDecoration(labelText: 'Short Bio', isDense: true),
                                maxLines: 1,
                              ),
                            ],
                            if (user.locationName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(children: [
                                  Icon(Icons.location_on_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 2),
                                  Expanded(child: Text(user.locationName, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ]),
                              ),
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

            // ── Categories ──────────────────────────
            _sectionLabel(context, 'Business Categories'),
            if (!_isEditing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: selectedCategories.isEmpty
                    ? Text('No categories selected.', style: TextStyle(color: colorScheme.onSurfaceVariant))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedCategories.map((c) => Chip(label: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                      ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StreamBuilder<List<String>>(
                  stream: firestoreService.configValuesStream('vendor_categories'),
                  initialData: vendorCategories,
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? vendorCategories;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((category) {
                        final isSelected = selectedCategories.contains(category);
                        return FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: busy ? null : (selected) {
                            setState(() {
                              if (selected) {
                                selectedCategories.add(category);
                              } else {
                                selectedCategories.remove(category);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ),

            // ── Privacy Section ─────────────────────
            _sectionLabel(context, 'Privacy & Visibility'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: SwitchListTile(
                secondary: Icon(showRoutesPublicly ? Icons.visibility : Icons.visibility_off_outlined,
                    color: showRoutesPublicly ? colorScheme.primary : colorScheme.onSurfaceVariant),
                title: const Text('Show routes on public profile'),
                subtitle: updatingVisibility 
                    ? const Text('Updating...') 
                    : const Text('Allow residents to see your planned service routes'),
                value: showRoutesPublicly,
                onChanged: busy ? null : (v) => toggleRouteVisibility(user, provider, v),
              ),
            ),

            // ── Schedule ────────────────────────────────
            _sectionLabel(context, 'Schedule'),
            if (!_isEditing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.workingDays.isEmpty ? 'No days selected' : user.workingDays.join(', ')),
                    if (user.availableFrom.isNotEmpty)
                      Text('${user.availableFrom} - ${user.availableTo}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
                    final isSelected = selectedWorkingDays.contains(day);
                    return FilterChip(
                      label: Text(day),
                      selected: isSelected,
                      onSelected: busy ? null : (selected) {
                        setState(() {
                          if (selected) {
                            selectedWorkingDays.add(day);
                          } else {
                            selectedWorkingDays.remove(day);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : () async {
                          final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
                          if (time != null && mounted) setState(() => availableFrom = time.format(context));
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(availableFrom.isEmpty ? 'From Time' : availableFrom),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : () async {
                          final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 18, minute: 0));
                          if (time != null && mounted) setState(() => availableTo = time.format(context));
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(availableTo.isEmpty ? 'To Time' : availableTo),
                      ),
                    ),
                  ],
                ),
              ),
              if (availableFrom.isNotEmpty || availableTo.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: busy ? null : () => setState(() { availableFrom = ''; availableTo = ''; }),
                    child: const Text('Clear Times'),
                  ),
                ),
            ],

            // ── Vehicle ─────────────────────────────
            _sectionLabel(context, 'Vehicle'),
            if (!_isEditing)
              ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text(user.vehicle.isEmpty ? 'Not specified' : user.vehicle),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StreamBuilder<List<String>>(
                  stream: firestoreService.configValuesStream('vehicle_options'),
                  initialData: defaultVehicleOptions,
                  builder: (context, snapshot) {
                    final options = snapshot.data ?? defaultVehicleOptions;
                    List<String> currentOptions = List.from(options);
                    if (selectedVehicle != null && !currentOptions.contains(selectedVehicle)) {
                      currentOptions.insert(0, selectedVehicle!);
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: selectedVehicle,
                      decoration: const InputDecoration(labelText: 'Vehicle Type', prefixIcon: Icon(Icons.local_shipping_outlined)),
                      items: currentOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: busy ? null : (v) => setState(() => selectedVehicle = v),
                      validator: (v) => v == null ? 'Vehicle is required' : null,
                    );
                  },
                ),
              ),

            // ── Menu ────────────────────────────────
            _sectionLabel(context, 'Menu'),
            if (_isEditing) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
              const SizedBox(height: 12),
            ],
            if (menuItems.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('No menu items added.', style: TextStyle(color: colorScheme.onSurfaceVariant)))
            else
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  for (int i = 0; i < menuItems.length; i++)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.restaurant_menu, size: 18),
                      title: Text(menuItems[i]),
                      trailing: _isEditing ? IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: busy ? null : () => removeMenuItem(i)) : null,
                    ),
                ]),
              ),

            if (_isEditing) ...[
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : () => cancelEdit(user),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: busy ? null : () => saveVendor(user, provider),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                        child: saving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 48),

            // ── Followers ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('FOLLOWERS (${user.followers.length})',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.primary, letterSpacing: 1, fontWeight: FontWeight.w600)),
            ),
            StreamBuilder<List<AppUser>>(
              stream: firestoreService.followersStream(user.followers),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Padding(padding: const EdgeInsets.all(16), child: Text(snapshot.hasError ? 'Error loading followers' : 'No followers yet.'));
                }
                final currentUser = context.watch<AppProvider>().currentUser;
                final followers = snapshot.data!
                    .where((f) => !(currentUser?.blockedUserIds.contains(f.id) ?? false))
                    .toList();
                return Column(children: followers.map((f) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
                  title: Text(f.name),
                  subtitle: Text(f.isContactPublic ? f.phone : 'Contact is private'),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FollowerProfileScreen(follower: f))),
                )).toList());
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
