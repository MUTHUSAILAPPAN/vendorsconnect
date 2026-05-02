import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';

class ConfigAdminScreen extends StatefulWidget {
  const ConfigAdminScreen({super.key});

  @override
  State<ConfigAdminScreen> createState() => _ConfigAdminScreenState();
}

class _ConfigAdminScreenState extends State<ConfigAdminScreen> {
  final firestoreService = FirestoreService();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();

  @override
  void dispose() {
    _categoryController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _addValue(String configId, TextEditingController controller) async {
    final value = controller.text.trim();
    if (value.isEmpty) return;

    try {
      await firestoreService.addConfigValue(configId, value);
      controller.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "$value"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _removeValue(String configId, String value) async {
    try {
      await firestoreService.removeConfigValue(configId, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed "$value"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildConfigSection({
    required String title,
    required String configId,
    required TextEditingController controller,
    required String hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hint,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _addValue(configId, controller),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<String>>(
          stream: firestoreService.configValuesStream(configId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: const Text('Error loading data'),
              );
            }

            final values = snapshot.data ?? [];
            if (values.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No values configured.'),
              );
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: values.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(values[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeValue(configId, values[index]),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Configuration'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildConfigSection(
            title: 'Vendor Categories / Interests',
            configId: 'vendor_categories',
            controller: _categoryController,
            hint: 'e.g. Household Help',
          ),
          const SizedBox(height: 24),
          _buildConfigSection(
            title: 'Vehicle Options',
            configId: 'vehicle_options',
            controller: _vehicleController,
            hint: 'e.g. Electric Cart',
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () async {
                await firestoreService.ensureDefaultConfig();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Default config seeded if missing')),
                );
              },
              icon: const Icon(Icons.settings_backup_restore),
              label: const Text('Seed Default Config'),
            ),
          ),
        ],
      ),
    );
  }
}
