import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../common/app_settings_screen.dart';
import '../login_screen.dart';
import 'route_management_screen.dart';
import 'vendor_analytics_screen.dart';
import 'vendor_profile_screen.dart';
import 'vendor_requests_screen.dart';
import '../../l10n/app_strings.dart';

class VendorHomeScreen extends StatefulWidget {
  const VendorHomeScreen({super.key});

  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen> {
  int index = 0;

  final screens = const [
    VendorAnalyticsScreen(),
    VendorRequestsScreen(),
    VendorProfileScreen(),
    RouteManagementScreen(),
    AppSettingsScreen(),
  ];

  String _getTitle(BuildContext context, int index) {
    if (index == 2) {
      final user = context.read<AppProvider>().currentUser;
      return user?.name ?? 'Profile';
    }
    final titles = ['Analytics', 'Requests', 'Profile', 'Routes', 'Settings'];
    return context.t(titles[index]);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.currentUser;

    if (user != null && user.role != 'vendor' && user.role != 'admin') {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('Wrong UI Role detected.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('You do not have vendor permissions.'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => provider.getHomeWidget()),
                    (_) => false,
                  );
                },
                child: const Text('Switch to Resident Home'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(context, index)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: context.t('Logout'),
            onPressed: () async {
              final confirm = await showConfirmDialog(
                context: context,
                title: context.t('Logout'),
                message: 'Are you sure you want to log out?',
                confirmText: context.t('Logout'),
              );
              if (confirm) {
                if (context.mounted) {
                  context.read<AppProvider>().logout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
      body: screens[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.analytics_outlined),
            selectedIcon: const Icon(Icons.analytics),
            label: context.t('Analytics'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.forum_outlined),
            selectedIcon: const Icon(Icons.forum),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: context.t('Profile'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.route_outlined),
            selectedIcon: const Icon(Icons.route),
            label: context.t('Routes'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: context.t('Settings'),
          ),
        ],
      ),
    );
  }
}
