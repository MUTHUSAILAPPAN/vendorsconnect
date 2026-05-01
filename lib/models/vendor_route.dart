import 'package:cloud_firestore/cloud_firestore.dart';

class VendorRoute {
  final String id;
  final String vendorId;
  final String name;
  final List<String> streets;
  final List<GeoPoint> coordinates;

  VendorRoute({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.streets,
    required this.coordinates,
  });

  factory VendorRoute.fromMap(String id, Map<String, dynamic> data) {
    return VendorRoute(
      id: id,
      vendorId: data['vendorId'] ?? '',
      name: data['name'] ?? 'Unnamed Route', // backward compatible
      streets: List<String>.from(data['streets'] ?? []),
      coordinates: List<GeoPoint>.from(data['coordinates'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'name': name,
      'streets': streets,
      'coordinates': coordinates,
    };
  }
}