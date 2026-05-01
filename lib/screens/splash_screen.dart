import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'login_screen.dart';
import 'resident/resident_home_screen.dart';
import 'vendor/vendor_home_screen.dart';
import 'admin/admin_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      final appProvider = context.read<AppProvider>();
      final user = appProvider.currentUser;

      Widget nextScreen;

      if (user == null) {
        nextScreen = const LoginScreen();
      } else if (user.role == 'vendor') {
        nextScreen = const VendorHomeScreen();
      } else if (user.role == 'admin') {
        nextScreen = const AdminHomeScreen();
      } else {
        nextScreen = const ResidentHomeScreen();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'VendorsConnect',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
