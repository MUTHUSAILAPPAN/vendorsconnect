import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';

class AppProvider extends ChangeNotifier {
  AppUser? currentUser;
  String adminViewRole = 'resident';

  // App Settings
  String themeMode = 'System'; // System, Light, Dark
  String fontSize = 'Normal'; // Small, Normal, Large, Extra Large
  double fontScale = 1.0;
  String selectedLanguageCode = 'en'; // en, ta, hi
  
  final _firestoreService = FirestoreService();

  bool get isContactPublic => currentUser?.isContactPublic ?? true;

  bool get isLoggedIn => currentUser != null;
  bool get isGuest => currentUser == null;

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

  // Settings updates
  void updateThemeMode(String mode) {
    themeMode = mode;
    notifyListeners();
  }

  void updateFontSize(String size) {
    fontSize = size;
    switch (size) {
      case 'Small':
        fontScale = 0.9;
        break;
      case 'Large':
        fontScale = 1.15;
        break;
      case 'Extra Large':
        fontScale = 1.3;
        break;
      default:
        fontScale = 1.0;
    }
    notifyListeners();
  }

  void updateLanguageCode(String code) {
    selectedLanguageCode = code;
    notifyListeners();
  }

  Future<void> updateContactVisibility(bool visible) async {
    if (currentUser == null) return;
    try {
      final updatedUser = currentUser!.copyWith(isContactPublic: visible);
      currentUser = updatedUser;
      notifyListeners();
      await _firestoreService.updateContactVisibility(updatedUser.id, visible);
    } catch (e) {
      // Revert if failed
      if (currentUser != null) {
        currentUser = currentUser!.copyWith(isContactPublic: !visible);
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> blockUser(String targetUserId) async {
    if (currentUser == null) return;
    try {
      final updatedList = [...currentUser!.blockedUserIds, targetUserId];
      final updatedUser = currentUser!.copyWith(blockedUserIds: updatedList);
      currentUser = updatedUser;
      notifyListeners();
      await _firestoreService.addToBlockedList(updatedUser.id, targetUserId);
    } catch (e) {
      if (currentUser != null) {
        final revertedList = currentUser!.blockedUserIds.where((id) => id != targetUserId).toList();
        currentUser = currentUser!.copyWith(blockedUserIds: revertedList);
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> unblockUser(String targetUserId) async {
    if (currentUser == null) return;
    try {
      final updatedList = currentUser!.blockedUserIds.where((id) => id != targetUserId).toList();
      final updatedUser = currentUser!.copyWith(blockedUserIds: updatedList);
      currentUser = updatedUser;
      notifyListeners();
      await _firestoreService.removeFromBlockedList(updatedUser.id, targetUserId);
    } catch (e) {
      if (currentUser != null) {
        final revertedList = [...currentUser!.blockedUserIds, targetUserId];
        currentUser = currentUser!.copyWith(blockedUserIds: revertedList);
        notifyListeners();
      }
      rethrow;
    }
  }

  ThemeMode get currentThemeMode {
    switch (themeMode) {
      case 'Light':
        return ThemeMode.light;
      case 'Dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
