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

  AppNotification({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.residentId,
    required this.message,
    required this.street,
    required this.read,
    required this.createdAt,
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
    };
  }
}
