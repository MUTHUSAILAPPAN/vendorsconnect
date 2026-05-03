import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../login_screen.dart';
import '../common/app_settings_screen.dart';
import 'admin_dashboard_tab.dart';
import 'admin_users_tab.dart';
import 'admin_analytics_tab.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  String? _pendingRoleFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          AdminDashboardTab(onFilterUsers: _onDashboardFilter),
          AdminUsersTab(initialRoleFilter: _pendingRoleFilter),
          const AdminAnalyticsTab(),
          const AppSettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            if (index != 1) _pendingRoleFilter = null;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0: return 'Admin Dashboard';
      case 1: return 'User Management';
      case 2: return 'System Analytics';
      case 3: return 'App Settings';
      default: return 'Admin';
    }
  }

  void _onDashboardFilter(String? role) {
    setState(() {
      _pendingRoleFilter = role;
      _currentIndex = 1;
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showConfirmDialog(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to log out?',
      confirmText: 'Logout',
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
  }
}
