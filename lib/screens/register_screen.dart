import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/vendor_categories.dart';
import '../constants/vehicle_options.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import 'resident/resident_home_screen.dart';
import 'role_selection_screen.dart';
import 'vendor/vendor_home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final firestoreService = FirestoreService();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final bioController = TextEditingController();
  final itemController = TextEditingController();
  final priceController = TextEditingController();

  String role = 'resident';
  bool loading = false;
  bool _obscurePassword = true;

  final List<String> selectedInterests = [];
  final List<String> menuItems = [];

  String? selectedVehicle;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    bioController.dispose();
    itemController.dispose();
    priceController.dispose();
    super.dispose();
  }

  void toggleInterest(String category) {
    setState(() {
      if (selectedInterests.contains(category)) {
        selectedInterests.remove(category);
      } else {
        selectedInterests.add(category);
      }
    });
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

  Future<void> chooseRole() async {
    final selectedRole = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
    if (selectedRole != null) setState(() => role = selectedRole);
  }

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(role == 'vendor' ? 'Select at least one vendor category' : 'Select at least one interest'),
      ));
      return;
    }
    if (role == 'vendor' && selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a vehicle')));
      return;
    }
    setState(() => loading = true);
    try {
      final user = await firestoreService.registerUser(
        role: role,
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        password: passwordController.text.trim(),
        bio: bioController.text.trim(),
        interests: selectedInterests,
        vehicle: selectedVehicle ?? '',
        menu: menuItems,
      );
      if (!mounted) return;
      context.read<AppProvider>().login(user);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => role == 'vendor' ? const VendorHomeScreen() : const ResidentHomeScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
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

  @override
  Widget build(BuildContext context) {
    final isVendor = role == 'vendor';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(isVendor ? Icons.store : Icons.person, color: colorScheme.primary),
                title: Text('Account type: ${isVendor ? "Vendor" : "Resident"}'),
                subtitle: const Text('Tap to change'),
                trailing: const Icon(Icons.chevron_right),
                onTap: chooseRole,
              ),
            ),
            _sectionLabel(context, 'Basic Information'),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.badge_outlined)),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone is required';
                final cleanPhone = v.trim();
                if (cleanPhone.length < 10) return 'Enter a valid phone number (at least 10 digits)';
                if (!RegExp(r'^[0-9]+$').hasMatch(cleanPhone)) return 'Phone number can only contain digits';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Password is required';
                if (v.trim().length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: bioController,
              decoration: const InputDecoration(labelText: 'Bio (optional)', prefixIcon: Icon(Icons.edit_note_outlined)),
              maxLines: 2,
            ),
            _sectionLabel(context, isVendor ? 'Vendor Categories' : 'Interests'),
            StreamBuilder<List<String>>(
              stream: firestoreService.configValuesStream('vendor_categories'),
              initialData: vendorCategories,
              builder: (context, snapshot) {
                final categories = snapshot.data ?? vendorCategories;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((category) {
                    final selected = selectedInterests.contains(category);
                    return FilterChip(label: Text(category), selected: selected, onSelected: (_) => toggleInterest(category));
                  }).toList(),
                );
              },
            ),
            if (isVendor) ...[
              _sectionLabel(context, 'Vendor Details'),
              StreamBuilder<List<String>>(
                stream: firestoreService.configValuesStream('vehicle_options'),
                initialData: defaultVehicleOptions,
                builder: (context, snapshot) {
                  final options = snapshot.data ?? defaultVehicleOptions;
                  // If selected value is no longer in options, set it to null
                  if (selectedVehicle != null && !options.contains(selectedVehicle)) {
                    // Using post-frame callback to avoid build conflicts
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => selectedVehicle = null);
                    });
                  }
                  
                  return DropdownButtonFormField<String>(
                    initialValue: selectedVehicle,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Type',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                    items: options.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) => setState(() => selectedVehicle = v),
                    validator: (v) => v == null ? 'Vehicle is required' : null,
                  );
                },
              ),
              _sectionLabel(context, 'Menu Items'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: TextFormField(controller: itemController, decoration: const InputDecoration(labelText: 'Item', hintText: 'Apple'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(controller: priceController, decoration: const InputDecoration(labelText: 'Price (₹)', hintText: '30'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton.filled(icon: const Icon(Icons.add), onPressed: addMenuItem),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (menuItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No menu items added yet', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                )
              else
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(children: [
                    for (int i = 0; i < menuItems.length; i++)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.restaurant_menu, size: 18),
                        title: Text(menuItems[i]),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => removeMenuItem(i)),
                      ),
                  ]),
                ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: loading ? null : register,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Account', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
