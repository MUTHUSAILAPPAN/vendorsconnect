import 'package:cloud_firestore/cloud_firestore.dart';

class VendorRoute {
  final String id;
  final String vendorId;
  final String name;
  final List<String> streets;
  final List<GeoPoint> coordinates;
  final List<List<GeoPoint>> streetGeometries;

  VendorRoute({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.streets,
    required this.coordinates,
    required this.streetGeometries,
  });

  factory VendorRoute.fromMap(String id, Map<String, dynamic> data) {
    final geometriesRaw = data['streetGeometries'] as List?;
    final List<List<GeoPoint>> streetGeometries = geometriesRaw != null
        ? geometriesRaw.map((g) {
            if (g is Map) {
              return List<GeoPoint>.from(g['points'] ?? []);
            } else if (g is List) {
              return List<GeoPoint>.from(g);
            }
            return <GeoPoint>[];
          }).toList()
        : [];

    return VendorRoute(
      id: id,
      vendorId: data['vendorId'] ?? '',
      name: data['name'] ?? 'Unnamed Route',
      streets: List<String>.from(data['streets'] ?? []),
      coordinates: List<GeoPoint>.from(data['coordinates'] ?? []),
      streetGeometries: streetGeometries,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'name': name,
      'streets': streets,
      'coordinates': coordinates,
      'streetGeometries': streetGeometries.map((g) => {'points': g}).toList(),
    };
  }
}