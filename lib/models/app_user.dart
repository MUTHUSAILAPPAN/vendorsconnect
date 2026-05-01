import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String role;
  final String name;
  final String phone;
  final String password;
  final String bio;
  final GeoPoint? location;
  final String locationName;
  final List<String> interests;
  final String profileImage;
  final List<String> following;
  final List<String> followers;
  final String vehicle;
  final List<String> menu;
  final bool isAvailable;
  final String currentRouteId;
  // ── Notification preferences ──────────────────
  final bool notificationsEnabled;
  final List<String> mutedVendorIds;
  // ── Moderation ────────────────────────────────
  final bool isBlocked;
  final String blockedReason;
  // ── Approval ──────────────────────────────────
  final String approvalStatus;
  final String rejectionReason;

  AppUser({
    required this.id,
    required this.role,
    required this.name,
    required this.phone,
    required this.password,
    required this.bio,
    required this.location,
    required this.locationName,
    required this.interests,
    required this.profileImage,
    required this.following,
    required this.followers,
    required this.vehicle,
    required this.menu,
    required this.isAvailable,
    required this.currentRouteId,
    this.notificationsEnabled = true,
    this.mutedVendorIds = const [],
    this.isBlocked = false,
    this.blockedReason = '',
    this.approvalStatus = 'approved',
    this.rejectionReason = '',
  });

  factory AppUser.emptyAdmin() {
    return AppUser(
      id: 'admin',
      role: 'admin',
      name: 'Admin',
      phone: 'admin',
      password: 'admin123',
      bio: '',
      location: null,
      locationName: '',
      interests: [],
      profileImage: '',
      following: [],
      followers: [],
      vehicle: '',
      menu: [],
      isAvailable: false,
      currentRouteId: '',
      notificationsEnabled: true,
      mutedVendorIds: [],
      isBlocked: false,
      blockedReason: '',
      approvalStatus: 'approved',
      rejectionReason: '',
    );
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    return AppUser(
      id: id,
      role: data['role'] ?? 'resident',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      password: data['password'] ?? '',
      bio: data['bio'] ?? '',
      location: data['location'],
      locationName: data['locationName'] ?? '',
      interests: List<String>.from(data['interests'] ?? []),
      profileImage: data['profileImage'] ?? '',
      following: List<String>.from(data['following'] ?? []),
      followers: List<String>.from(data['followers'] ?? []),
      vehicle: data['vehicle'] ?? '',
      menu: List<String>.from(data['menu'] ?? []),
      isAvailable: data['isAvailable'] ?? false,
      currentRouteId: data['currentRouteId'] ?? '',
      // Safe defaults for existing documents that predate these fields
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
      mutedVendorIds: List<String>.from(data['mutedVendorIds'] ?? []),
      isBlocked: data['isBlocked'] as bool? ?? false,
      blockedReason: data['blockedReason'] as String? ?? '',
      approvalStatus: data['approvalStatus'] as String? ?? 'approved',
      rejectionReason: data['rejectionReason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role,
      'name': name,
      'phone': phone,
      'password': password,
      'bio': bio,
      'location': location,
      'locationName': locationName,
      'interests': interests,
      'profileImage': profileImage,
      'following': following,
      'followers': followers,
      'vehicle': vehicle,
      'menu': menu,
      'isAvailable': isAvailable,
      'currentRouteId': currentRouteId,
      'notificationsEnabled': notificationsEnabled,
      'mutedVendorIds': mutedVendorIds,
      'isBlocked': isBlocked,
      'blockedReason': blockedReason,
      'approvalStatus': approvalStatus,
      'rejectionReason': rejectionReason,
    };
  }

  AppUser copyWith({
    String? role,
    String? name,
    String? phone,
    String? password,
    String? bio,
    GeoPoint? location,
    String? locationName,
    List<String>? interests,
    String? profileImage,
    List<String>? following,
    List<String>? followers,
    String? vehicle,
    List<String>? menu,
    bool? isAvailable,
    String? currentRouteId,
    bool? notificationsEnabled,
    List<String>? mutedVendorIds,
    bool? isBlocked,
    String? blockedReason,
    String? approvalStatus,
    String? rejectionReason,
  }) {
    return AppUser(
      id: id,
      role: role ?? this.role,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      locationName: locationName ?? this.locationName,
      interests: interests ?? this.interests,
      profileImage: profileImage ?? this.profileImage,
      following: following ?? this.following,
      followers: followers ?? this.followers,
      vehicle: vehicle ?? this.vehicle,
      menu: menu ?? this.menu,
      isAvailable: isAvailable ?? this.isAvailable,
      currentRouteId: currentRouteId ?? this.currentRouteId,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      mutedVendorIds: mutedVendorIds ?? this.mutedVendorIds,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedReason: blockedReason ?? this.blockedReason,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
