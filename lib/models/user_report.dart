import 'package:cloud_firestore/cloud_firestore.dart';

class UserReport {
  final String id;
  final String reporterId;
  final String reporterName;
  final String reportedUserId;
  final String reportedUserName;
  final String requestId;
  final String reason;
  final String details;
  final String status;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  UserReport({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.reportedUserId,
    required this.reportedUserName,
    this.requestId = '',
    required this.reason,
    this.details = '',
    this.status = 'pending',
    this.createdAt,
    this.reviewedAt,
  });

  factory UserReport.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic rawDate) {
      if (rawDate is Timestamp) return rawDate.toDate();
      if (rawDate is String) return DateTime.tryParse(rawDate);
      return null;
    }

    return UserReport(
      id: id,
      reporterId: data['reporterId'] ?? '',
      reporterName: data['reporterName'] ?? 'Unknown Reporter',
      reportedUserId: data['reportedUserId'] ?? '',
      reportedUserName: data['reportedUserName'] ?? 'Unknown User',
      requestId: data['requestId'] ?? '',
      reason: data['reason'] ?? '',
      details: data['details'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: parseDate(data['createdAt']),
      reviewedAt: parseDate(data['reviewedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reportedUserId': reportedUserId,
      'reportedUserName': reportedUserName,
      'requestId': requestId,
      'reason': reason,
      'details': details,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
    };
  }
}
