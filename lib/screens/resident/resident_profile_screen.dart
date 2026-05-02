import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/vendor_categories.dart';
import '../../models/app_user.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

class ResidentProfileScreen extends StatefulWidget {
  const ResidentProfileScreen({super.key});

  @override
  State<ResidentProfileScreen> createState() => _ResidentProfileScreenState();
}

class _ResidentProfileScreenState extends State<ResidentProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final firestoreService = FirestoreService();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final bioController = TextEditingController();
  final locationService = LocationService();

  final List<String> selectedInterests = [];
  bool initialized = false;
  bool loading = false;
  bool updatingLocation = false;
  bool _isEditing = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    bioController.dispose();
    super.dispose();
  }

  void initializeFields(AppUser user, {bool force = false}) {
    if (initialized && !force) return;
    nameController.text = user.name;
    phoneController.text = user.phone;
    passwordController.text = user.password;
    bioController.text = user.bio;
    selectedInterests..clear()..addAll(user.interests);
    initialized = true;
  }

  void toggleInterest(String category) {
    if (!_isEditing) return;
    setState(() {
      if (selectedInterests.contains(category)) {
        selectedInterests.remove(category);
      } else {
        selectedInterests.add(category);
      }
    });
  }

  Future<void> saveProfile(AppUser user, AppProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one interest')),
      );
      return;
    }
    setState(() => loading = true);
    try {
      final updated = user.copyWith(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        password: passwordController.text.trim(),
        bio: bioController.text.trim(),
        interests: selectedInterests,
      );
      await firestoreService.updateUser(updated);
      provider.updateUser(updated);
      if (!mounted) return;
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void cancelEdit(AppUser user) {
    setState(() {
      _isEditing = false;
      initializeFields(user, force: true);
    });
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

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
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
    final provider = context.watch<AppProvider>();
    final user = provider.currentUser;
    if (user == null) return const Center(child: Text('Please login'));

    initializeFields(user);

    final colorScheme = Theme.of(context).colorScheme;
    final initial = user.name.isEmpty ? '?' : user.name[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
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
            // ── Header ─────────────────────────────
            Container(
              color: colorScheme.surfaceContainerLow,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name.isEmpty ? 'Your Profile' : user.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (user.bio.isNotEmpty)
                          Text(
                            user.bio,
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          '${user.interests.length} interest${user.interests.length != 1 ? "s" : ""}',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Location ────────────────────────────
            Card(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 20, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('CURRENT LOCATION', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.primary, letterSpacing: 1, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.locationName.isEmpty ? 'Location not set' : user.locationName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: user.locationName.isEmpty ? FontWeight.normal : FontWeight.w500,
                        color: user.locationName.isEmpty ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: updatingLocation ? null : () => updateLocation(user, provider),
                      icon: updatingLocation
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location, size: 18),
                      label: Text(updatingLocation ? 'Updating...' : 'Detect Current Location'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Basic info ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel(context, 'Basic Information'),
                  if (!_isEditing) ...[
                    _buildDetailRow(Icons.badge_outlined, 'Name', user.name),
                    _buildDetailRow(Icons.phone_outlined, 'Phone', user.phone),
                    _buildDetailRow(Icons.edit_note_outlined, 'Bio', user.bio.isEmpty ? 'No bio added' : user.bio),
                  ] else ...[
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Phone is required';
                        if (v.trim().length < 10) return 'Enter a valid phone number';
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
                      decoration: const InputDecoration(
                        labelText: 'Bio (optional)',
                        prefixIcon: Icon(Icons.edit_note_outlined),
                      ),
                      maxLines: 2,
                    ),
                  ],

                  // ── Interests ───────────────────
                  _sectionLabel(context, 'Interests'),
                  if (!_isEditing)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: user.interests.map((category) => Chip(label: Text(category))).toList(),
                    )
                  else ...[
                    Text(
                      'Select vendor types you are interested in:',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
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
                            return FilterChip(
                              label: Text(category),
                              selected: selected,
                              onSelected: (_) => toggleInterest(category),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 32),
                  if (_isEditing)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: loading ? null : () => cancelEdit(user),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: loading ? null : () => saveProfile(user, provider),
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                            child: loading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Save Changes'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
