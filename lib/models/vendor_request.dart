import 'package:cloud_firestore/cloud_firestore.dart';

class VendorRequest {
  final String id;
  final String residentId;
  final String residentName;
  final String vendorId;
  final String vendorName;
  final String question;
  final String itemName;
  final String extraDetails;
  final String response;
  final String status;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  VendorRequest({
    required this.id,
    required this.residentId,
    required this.residentName,
    required this.vendorId,
    required this.vendorName,
    required this.question,
    this.itemName = '',
    this.extraDetails = '',
    this.response = '',
    this.status = 'pending',
    this.createdAt,
    this.respondedAt,
  });

  factory VendorRequest.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic rawDate) {
      if (rawDate is Timestamp) return rawDate.toDate();
      if (rawDate is String) return DateTime.tryParse(rawDate);
      return null;
    }

    return VendorRequest(
      id: id,
      residentId: data['residentId'] ?? '',
      residentName: data['residentName'] ?? 'Unknown Resident',
      vendorId: data['vendorId'] ?? '',
      vendorName: data['vendorName'] ?? 'Unknown Vendor',
      question: data['question'] ?? '',
      itemName: data['itemName'] ?? '',
      extraDetails: data['extraDetails'] ?? '',
      response: data['response'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: parseDate(data['createdAt']),
      respondedAt: parseDate(data['respondedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'residentId': residentId,
      'residentName': residentName,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'question': question,
      'itemName': itemName,
      'extraDetails': extraDetails,
      'response': response,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }
}
