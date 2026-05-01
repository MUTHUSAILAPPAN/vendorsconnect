import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/vendor_route.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get routes =>
      _db.collection('routes');

  Exception _handleError(dynamic error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') return Exception('Permission denied. You do not have access.');
      if (error.code == 'unavailable' || error.code == 'network-request-failed') {
        return Exception('Network unavailable. Please check your connection.');
      }
      if (error.code == 'not-found') return Exception('Requested data not found.');
      return Exception('Database error: ${error.message}');
    }
    return Exception('An unexpected error occurred: $error');
  }

  Future<AppUser?> login(String phone, String password) async {
    try {
      if (phone == 'admin' && password == 'admin123') {
        return AppUser.emptyAdmin();
      }

      final result = await users
          .where('phone', isEqualTo: phone)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (result.docs.isEmpty) return null;

      final doc = result.docs.first;
      return AppUser.fromMap(doc.id, doc.data());
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<AppUser> registerUser({
    required String role,
    required String name,
    required String phone,
    required String password,
    required String bio,
    required List<String> interests,
    required String vehicle,
    required List<String> menu,
  }) async {
    try {
      final existingUser = await users.where('phone', isEqualTo: phone).limit(1).get();
      if (existingUser.docs.isNotEmpty) {
        throw Exception('This phone number is already registered.');
      }

      final doc = users.doc();

      final user = AppUser(
        id: doc.id,
        role: role,
        name: name,
        phone: phone,
        password: password,
        bio: bio,
        location: null,
        locationName: '',
        interests: interests,
        profileImage: '',
        following: [],
        followers: [],
        vehicle: vehicle,
        menu: menu,
        isAvailable: false,
        currentRouteId: '',
        approvalStatus: role == 'vendor' ? 'pending' : 'approved',
      );

      await doc.set(user.toMap());
      return user;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Stream<List<AppUser>> vendorsStream() {
    return users.where('role', isEqualTo: 'vendor').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .where((user) => user.approvalStatus == 'approved')
          .toList();
    }).handleError((e) => throw _handleError(e));
  }

  Stream<List<AppUser>> pendingVendorsStream() {
    return users.where('role', isEqualTo: 'vendor').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .where((user) => user.approvalStatus == 'pending')
          .toList();
    }).handleError((e) => throw _handleError(e));
  }

  Stream<List<AppUser>> allVendorsStream() {
    return users.where('role', isEqualTo: 'vendor').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .toList();
    }).handleError((e) => throw _handleError(e));
  }

  Future<AppUser?> getUser(String id) async {
    try {
      final doc = await users.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateUser(AppUser user) async {
    try {
      await users.doc(user.id).update(user.toMap());
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> followVendor({
    required String residentId,
    required String vendorId,
  }) async {
    try {
      await users.doc(residentId).update({
        'following': FieldValue.arrayUnion([vendorId]),
      });

      await users.doc(vendorId).update({
        'followers': FieldValue.arrayUnion([residentId]),
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> unfollowVendor({
    required String residentId,
    required String vendorId,
  }) async {
    try {
      await users.doc(residentId).update({
        'following': FieldValue.arrayRemove([vendorId]),
      });

      await users.doc(vendorId).update({
        'followers': FieldValue.arrayRemove([residentId]),
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Stream<List<AppUser>> followersStream(List<String> followerIds) {
    if (followerIds.isEmpty) {
      return Stream.value([]);
    }

    return users.snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => followerIds.contains(doc.id))
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .toList();
    }).handleError((e) => throw _handleError(e));
  }

  /// Creates a new route. [name] is now required.
  Future<VendorRoute> createRoute({
    required String vendorId,
    required String name,
    required List<String> streets,
    required List<GeoPoint> coordinates,
  }) async {
    try {
      final doc = routes.doc();

      final route = VendorRoute(
        id: doc.id,
        vendorId: vendorId,
        name: name,
        streets: streets,
        coordinates: coordinates,
      );

      await doc.set(route.toMap());
      return route;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Stream<List<VendorRoute>> vendorRoutesStream(String vendorId) {
    return routes
        .where('vendorId', isEqualTo: vendorId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => VendorRoute.fromMap(doc.id, doc.data()))
          .toList();
    }).handleError((e) => throw _handleError(e));
  }

  Stream<List<AppUser>> usersStream() {
    return users.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .toList();
    }).handleError((e) => throw _handleError(e));
  }

  Stream<List<VendorRoute>> routesStream() {
    return routes.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => VendorRoute.fromMap(doc.id, doc.data()))
          .toList();
    }).handleError((e) => throw _handleError(e));
  }

  Future<VendorRoute?> getRoute(String routeId) async {
    try {
      final doc = await routes.doc(routeId).get();
      if (!doc.exists || doc.data() == null) return null;
      return VendorRoute.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteRoute(String routeId) async {
    try {
      await routes.doc(routeId).delete();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> setCurrentRoute({
    required String vendorId,
    required String routeId,
  }) async {
    try {
      await users.doc(vendorId).update({
        'currentRouteId': routeId,
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> clearCurrentRoute(String vendorId) async {
    try {
      await users.doc(vendorId).update({
        'currentRouteId': '',
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateNotificationEnabled(AppUser user, bool enabled) async {
    try {
      await users.doc(user.id).update({
        'notificationsEnabled': enabled,
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> muteVendor(AppUser user, String vendorId) async {
    try {
      await users.doc(user.id).update({
        'mutedVendorIds': FieldValue.arrayUnion([vendorId]),
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> unmuteVendor(AppUser user, String vendorId) async {
    try {
      await users.doc(user.id).update({
        'mutedVendorIds': FieldValue.arrayRemove([vendorId]),
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ── Vendor Requests ─────────────────────────────
  
  CollectionReference<Map<String, dynamic>> get vendorRequests =>
      _db.collection('vendor_requests');

  Future<void> createVendorRequest({
    required String residentId,
    required String residentName,
    required String vendorId,
    required String vendorName,
    required String question,
    String itemName = '',
    String extraDetails = '',
  }) async {
    try {
      await vendorRequests.add({
        'residentId': residentId,
        'residentName': residentName,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'question': question,
        'itemName': itemName,
        'extraDetails': extraDetails,
        'response': '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> residentRequestsStream(String residentId) {
    return vendorRequests
        .where('residentId', isEqualTo: residentId)
        .snapshots()
        .handleError((e) => throw _handleError(e));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> vendorRequestsStream(String vendorId) {
    return vendorRequests
        .where('vendorId', isEqualTo: vendorId)
        .snapshots()
        .handleError((e) => throw _handleError(e));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> allVendorRequestsStream() {
    return vendorRequests.snapshots().handleError((e) => throw _handleError(e));
  }

  Future<void> replyToVendorRequest(String requestId, String response) async {
    try {
      await vendorRequests.doc(requestId).update({
        'response': response,
        'status': 'answered',
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> closeVendorRequest(String requestId) async {
    try {
      await vendorRequests.doc(requestId).update({
        'status': 'closed',
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ── Reports ─────────────────────────────────────
  
  CollectionReference<Map<String, dynamic>> get reports =>
      _db.collection('reports');

  Future<void> createReport({
    required String reporterId,
    required String reporterName,
    required String reportedUserId,
    required String reportedUserName,
    String requestId = '',
    required String reason,
    String details = '',
  }) async {
    try {
      await reports.add({
        'reporterId': reporterId,
        'reporterName': reporterName,
        'reportedUserId': reportedUserId,
        'reportedUserName': reportedUserName,
        'requestId': requestId,
        'reason': reason,
        'details': details,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> reportsStream() {
    return reports.snapshots().handleError((e) => throw _handleError(e));
  }

  Future<void> updateReportStatus(String reportId, String status) async {
    try {
      await reports.doc(reportId).update({
        'status': status,
        'reviewedAt': status != 'pending' ? FieldValue.serverTimestamp() : null,
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ── User Moderation ─────────────────────────────

  Future<void> blockUser(String userId, String reason) async {
    try {
      await users.doc(userId).update({
        'isBlocked': true,
        'blockedReason': reason,
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> unblockUser(String userId) async {
    try {
      await users.doc(userId).update({
        'isBlocked': false,
        'blockedReason': '',
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await users.doc(userId).delete();
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ── Vendor Approval ───────────────────────────

  Future<void> approveVendor(String vendorId) async {
    try {
      await users.doc(vendorId).update({
        'approvalStatus': 'approved',
        'rejectionReason': '',
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> rejectVendor(String vendorId, String reason) async {
    try {
      await users.doc(vendorId).update({
        'approvalStatus': 'rejected',
        'rejectionReason': reason,
      });
    } catch (e) {
      throw _handleError(e);
    }
  }
}