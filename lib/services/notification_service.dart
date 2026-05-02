import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/app_notification.dart';
import '../models/app_user.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Exception _handleError(dynamic error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') return Exception('Permission denied. You do not have access.');
      if (error.code == 'unavailable' || error.code == 'network-request-failed') {
        return Exception('Network unavailable. Please check your connection.');
      }
      return Exception('Database error: ${error.message}');
    }
    return Exception('An unexpected error occurred: $error');
  }

  Future<void> setupMessaging() async {
    try {
      await _messaging.requestPermission();
      await _messaging.getToken();
    } catch (e) {
      throw Exception('Failed to set up notifications: $e');
    }
  }

  Future<void> notifyFollowers({
    required String vendorId,
    required String vendorName,
    required List<String> followerIds,
    required String street,
    String type = 'manual_arrival',
    String source = 'manual',
    String? customMessage,
  }) async {
    try {
      final message = customMessage ?? 'Vendor $vendorName has reached $street';

      for (final followerId in followerIds) {
        final residentDoc = await _db.collection('users').doc(followerId).get();
        if (residentDoc.exists && residentDoc.data() != null) {
          final resident = AppUser.fromMap(residentDoc.id, residentDoc.data()!);
          if (!resident.notificationsEnabled) continue;
          if (resident.mutedVendorIds.contains(vendorId)) continue;
        }

        await _db.collection('notifications').add({
          'vendorId': vendorId,
          'vendorName': vendorName,
          'residentId': followerId,
          'message': message,
          'street': street,
          'type': type,
          'source': source,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Placeholder for future geofence notifications.
  /// To be called when a vendor enters a street's geofence.
  Future<void> notifyFollowersFromGeofence({
    required String vendorId,
    required String vendorName,
    required List<String> followerIds,
    required String street,
  }) async {
    return notifyFollowers(
      vendorId: vendorId,
      vendorName: vendorName,
      followerIds: followerIds,
      street: street,
      type: 'geofence_arrival',
      source: 'geofence',
      customMessage: 'Location update: $vendorName is nearby on $street',
    );
  }

  Stream<List<AppNotification>> notificationsForUser(String userId) {
    return _db
        .collection('notifications')
        .where('residentId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => AppNotification.fromMap(doc.id, doc.data())).toList())
        .handleError((e) => throw _handleError(e));
  }

  Stream<List<AppNotification>> notificationsForVendor(String vendorId) {
    return _db
        .collection('notifications')
        .where('vendorId', isEqualTo: vendorId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => AppNotification.fromMap(doc.id, doc.data())).toList())
        .handleError((e) => throw _handleError(e));
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({'read': true});
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> markAllAsRead(String residentId) async {
    try {
      final snapshot = await _db
          .collection('notifications')
          .where('residentId', isEqualTo: residentId)
          .where('read', isEqualTo: false)
          .get();

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> clearNotifications(String residentId) async {
    try {
      final snapshot = await _db
          .collection('notifications')
          .where('residentId', isEqualTo: residentId)
          .get();

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw _handleError(e);
    }
  }
}
