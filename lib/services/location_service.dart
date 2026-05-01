import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final GeoPoint point;
  final String placeName;

  LocationResult({
    required this.point,
    required this.placeName,
  });
}

class LocationService {
  Future<LocationResult?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable them in your device settings.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permissions are denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied, we cannot request permissions.');
    }

    try {
      final position = await Geolocator.getCurrentPosition();

      final point = GeoPoint(position.latitude, position.longitude);
      final placeName = await getPlaceName(point);

      return LocationResult(
        point: point,
        placeName: placeName,
      );
    } catch (e) {
      throw Exception('Failed to get location: $e');
    }
  }

  Future<String> getPlaceName(GeoPoint point) async {
    try {
      final places = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );

      if (places.isEmpty) {
        return '${point.latitude}, ${point.longitude}';
      }

      final place = places.first;

      final parts = [
        place.street,
        place.subLocality,
        place.locality,
      ].where((part) => part != null && part.trim().isNotEmpty).toList();

      if (parts.isEmpty) {
        return '${point.latitude}, ${point.longitude}';
      }

      return parts.join(', ');
    } catch (_) {
      return '${point.latitude}, ${point.longitude}';
    }
  }
}
