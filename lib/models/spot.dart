import 'dart:math';

import 'package:latlong2/latlong.dart';

import 'spot_category.dart';

/// Культурное место на карте.
class Spot {
  const Spot({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.category,
    this.description,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final SpotCategory category;
  final String? description;

  LatLng get point => LatLng(lat, lon);

  /// Разбирает место из сохранённого JSON-снимка.
  factory Spot.fromJson(Map<String, dynamic> json) {
    final rawDescription = json['description']?.toString().trim();

    return Spot(
      id: json['id']?.toString() ?? '',
      name: _cleanName(json['name']?.toString() ?? ''),
      lat: _toDouble(json['lat']) ?? 0,
      lon: _toDouble(json['lon']) ?? 0,
      category: SpotCategory.fromName(json['category']?.toString() ?? 'other'),
      description: (rawDescription == null || rawDescription.isEmpty)
          ? null
          : rawDescription,
    );
  }

  /// Разбирает элемент ответа Overpass API.
  static Spot? fromOverpassElement(Map<String, dynamic> element) {
    final rawTags = element['tags'];
    final tags = <String, dynamic>{};
    if (rawTags is Map) {
      rawTags.forEach((key, value) => tags[key.toString()] = value);
    }

    final category = SpotCategory.fromOsmTags(tags);
    if (category == null) return null;

    final name = _cleanName(
      (tags['name:ru'] ?? tags['name'] ?? tags['official_name'] ?? '')
          .toString(),
    );
    if (name.length < 3 || !RegExp('[A-Za-zА-Яа-яЁё]').hasMatch(name)) {
      return null;
    }

    final center = element['center'];
    final lat = _toDouble(
      element['lat'] ?? (center is Map ? center['lat'] : null),
    );
    final lon = _toDouble(
      element['lon'] ?? (center is Map ? center['lon'] : null),
    );
    if (lat == null || lon == null) return null;

    final rawDescription =
        (tags['description:ru'] ??
                tags['description'] ??
                tags['inscription'] ??
                tags['note'] ??
                '')
            .toString()
            .trim();

    return Spot(
      id: '${element['type'] ?? 'osm'}/${element['id']}',
      name: name,
      lat: lat,
      lon: lon,
      category: category,
      description: rawDescription.isEmpty
          ? null
          : rawDescription.substring(0, min(rawDescription.length, 200)),
    );
  }

  static String _cleanName(String value) {
    var name = value.trim();
    if (name.length >= 2 && name.startsWith('"') && name.endsWith('"')) {
      name = name.substring(1, name.length - 1).trim();
    }
    return name;
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
