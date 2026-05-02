import 'package:latlong2/latlong.dart';

class SelectedStreet {
  final String name;
  final LatLng center;
  final List<LatLng> geometry;

  SelectedStreet({
    required this.name,
    required this.center,
    required this.geometry,
  });

  SelectedStreet copyWith({
    String? name,
    LatLng? center,
    List<LatLng>? geometry,
  }) {
    return SelectedStreet(
      name: name ?? this.name,
      center: center ?? this.center,
      geometry: geometry ?? this.geometry,
    );
  }
}