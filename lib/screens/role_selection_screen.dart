import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Role'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              title: const Text('Resident'),
              subtitle: const Text('Discover and follow nearby vendors'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.pop(context, 'resident');
              },
            ),
            ListTile(
              title: const Text('Vendor'),
              subtitle: const Text('Manage availability, routes, and followers'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.pop(context, 'vendor');
              },
            ),
          ],
        ),
      ),
    );
  }
}
