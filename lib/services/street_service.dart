import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/selected_street.dart';

class PlaceResult {
  final String displayName;
  final LatLng location;

  PlaceResult({
    required this.displayName,
    required this.location,
  });
}

class StreetService {
  final Distance _distance = const Distance();

  Future<List<PlaceResult>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(query)}'
      '&format=json'
      '&limit=5',
    );

    try {
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'VendorsConnectApp/1.0'},
      );

      if (response.statusCode != 200) {
        throw Exception('Search service unavailable (Error ${response.statusCode})');
      }

      final List<dynamic> data = jsonDecode(response.body);

      return data.map((item) {
        return PlaceResult(
          displayName: item['display_name'] ?? '',
          location: LatLng(
            double.parse(item['lat']),
            double.parse(item['lon']),
          ),
        );
      }).toList();
    } catch (error) {
      debugPrint('Nominatim search failed: $error');
      throw Exception('Failed to connect to search service.');
    }
  }

  Future<SelectedStreet?> fetchNearestStreet(LatLng point) async {
    const radius = 350;

    final query = '''
[out:json][timeout:20];
(
  way(around:$radius,${point.latitude},${point.longitude})["highway"];
);
out tags geom;
''';

    final uri = Uri.parse('https://overpass-api.de/api/interpreter');

    try {
      final response = await http.post(
        uri,
        headers: {'User-Agent': 'VendorsConnectApp/1.0'},
        body: {'data': query},
      );

      debugPrint('Overpass status: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('Overpass error: ${response.body}');
        throw Exception('Map data service unavailable (Error ${response.statusCode})');
      }

      final data = jsonDecode(response.body);
      final elements = data['elements'] as List<dynamic>? ?? [];

      debugPrint('Overpass roads found: ${elements.length}');

      if (elements.isEmpty) return null;

      SelectedStreet? nearestStreet;
      double nearestDistance = double.infinity;

      for (final element in elements) {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};
        final highway = tags['highway']?.toString() ?? '';

        if (_shouldSkipHighway(highway)) continue;

        final rawGeometry = element['geometry'] as List<dynamic>? ?? [];
        if (rawGeometry.length < 2) continue;

        final geometry = rawGeometry.map((node) {
          return LatLng(
            (node['lat'] as num).toDouble(),
            (node['lon'] as num).toDouble(),
          );
        }).toList();

        final distanceToTap = _distanceToPolyline(point, geometry);

        if (distanceToTap < nearestDistance) {
          nearestDistance = distanceToTap;

          final name = _streetName(tags);
          final center = _closestPointInGeometry(point, geometry);

          nearestStreet = SelectedStreet(
            name: name,
            center: center,
            geometry: geometry,
          );
        }
      }

      debugPrint('Nearest street distance: $nearestDistance m');

      return nearestStreet;
    } catch (error) {
      debugPrint('Overpass lookup failed: $error');
      throw Exception('Failed to connect to map data service.');
    }
  }

  bool _shouldSkipHighway(String highway) {
    const skipped = {
      'footway',
      'path',
      'steps',
      'cycleway',
      'bridleway',
      'construction',
      'proposed',
    };

    return skipped.contains(highway);
  }

  String _streetName(Map<String, dynamic> tags) {
    final name = tags['name']?.toString().trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final ref = tags['ref']?.toString().trim();

    if (ref != null && ref.isNotEmpty) {
      return ref;
    }

    final highway = tags['highway']?.toString().trim();

    if (highway != null && highway.isNotEmpty) {
      return 'Unnamed $highway road';
    }

    return 'Unnamed street';
  }

  double _distanceToPolyline(LatLng point, List<LatLng> geometry) {
    double closest = double.infinity;

    for (final node in geometry) {
      closest = min(closest, _distance(point, node));
    }

    return closest;
  }

  LatLng _closestPointInGeometry(LatLng point, List<LatLng> geometry) {
    LatLng closestPoint = geometry.first;
    double closestDistance = double.infinity;

    for (final node in geometry) {
      final distance = _distance(point, node);

      if (distance < closestDistance) {
        closestDistance = distance;
        closestPoint = node;
      }
    }

    return closestPoint;
  }
}
