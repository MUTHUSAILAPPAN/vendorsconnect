import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/login_required_view.dart';
import '../common/app_settings_screen.dart';
import '../login_screen.dart';
import 'following_screen.dart';
import 'resident_map_screen.dart';
import 'resident_profile_screen.dart';
import 'resident_requests_screen.dart';
import 'vendor_list_screen.dart';
import '../../l10n/app_strings.dart';

class ResidentHomeScreen extends StatefulWidget {
  const ResidentHomeScreen({super.key});

  @override
  State<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends State<ResidentHomeScreen> {
  int index = 0;

  List<Widget> _buildScreens(bool isGuest) {
    return [
      const VendorListScreen(),
      const ResidentMapScreen(),
      isGuest ? const LoginRequiredView(title: 'Requests', message: 'Login to send and track service requests.', icon: Icons.forum_outlined) : const ResidentRequestsScreen(),
      isGuest ? LoginRequiredView(title: context.t('Following'), message: 'Follow vendors to get real-time arrival updates.', icon: Icons.favorite_outline) : const FollowingScreen(),
      isGuest ? LoginRequiredView(title: context.t('Profile'), message: 'Manage your profile and preferences.', icon: Icons.person_outline) : const ResidentProfileScreen(),
      const AppSettingsScreen(),
    ];
  }

  String _getTitle(BuildContext context, int index) {
    final titles = ['Vendors', 'Map', 'Requests', 'Following', 'Profile', 'Settings'];
    return context.t(titles[index]);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(context, index)),
        actions: [
          if (user == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                icon: const Icon(Icons.login, size: 18),
                label: Text(context.t('Login')),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
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
            ),
        ],
      ),
      body: _buildScreens(user == null)[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront),
            label: context.t('Vendors'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: context.t('Map'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.forum_outlined),
            selectedIcon: const Icon(Icons.forum),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_outline),
            selectedIcon: const Icon(Icons.favorite),
            label: context.t('Following'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: context.t('Profile'),
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
