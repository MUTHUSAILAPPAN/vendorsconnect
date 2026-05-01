import 'package:flutter/material.dart';

import '../models/app_user.dart';

class AppProvider extends ChangeNotifier {
  AppUser? currentUser;
  String adminViewRole = 'resident';

  bool get isLoggedIn => currentUser != null;

  void login(AppUser user) {
    currentUser = user;
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    adminViewRole = 'resident';
    notifyListeners();
  }

  void updateUser(AppUser user) {
    currentUser = user;
    notifyListeners();
  }

  void switchAdminView(String role) {
    adminViewRole = role;
    notifyListeners();
  }
}
