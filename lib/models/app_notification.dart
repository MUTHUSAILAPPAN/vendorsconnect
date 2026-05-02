import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String vendorId;
  final String vendorName;
  final String residentId;
  final String message;
  final String street;
  final bool read;
  final DateTime? createdAt;
  final String type; // manual_arrival / geofence_arrival / vendor_update / request_response
  final String source; // manual / geofence

  AppNotification({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.residentId,
    required this.message,
    required this.street,
    required this.read,
    required this.createdAt,
    required this.type,
    required this.source,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    DateTime? createdAt;
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      createdAt = raw.toDate();
    }

    return AppNotification(
      id: id,
      vendorId: data['vendorId'] as String? ?? '',
      vendorName: data['vendorName'] as String? ?? 'Unknown vendor',
      residentId: data['residentId'] as String? ?? '',
      message: data['message'] as String? ?? '',
      street: data['street'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: createdAt,
      type: data['type'] as String? ?? 'manual_arrival',
      source: data['source'] as String? ?? 'manual',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'vendorName': vendorName,
      'residentId': residentId,
      'message': message,
      'street': street,
      'read': read,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'type': type,
      'source': source,
    };
  }
}
