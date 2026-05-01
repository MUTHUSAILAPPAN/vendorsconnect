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
}