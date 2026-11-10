import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/spot.dart';
import 'izhevsk_bounds.dart';

class SpotsLoadException implements Exception {
  const SpotsLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Загружает места Ижевска из OpenStreetMap.
///
/// При старте используется сохранённый снимок (работает без интернета),
/// а свежие данные подтягиваются через Overpass API.
class SpotsRepository {
  SpotsRepository({http.Client? client}) : _client = client ?? http.Client();

  static const _snapshotAsset = 'assets/data/izhevsk_spots.json';

  static const _endpoints = <String>[
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  static const _query =
      '''
[out:json][timeout:30];
(
  node["tourism"~"attraction|museum|artwork|viewpoint|gallery|zoo"](${IzhevskBounds.overpass});
  node["historic"~"monument|memorial|archaeological_site|castle|city_gate"](${IzhevskBounds.overpass});
  node["leisure"~"park|garden"](${IzhevskBounds.overpass});
  node["natural"="spring"](${IzhevskBounds.overpass});
  node["amenity"~"theatre|arts_centre|planetarium|fountain"](${IzhevskBounds.overpass});
  way["tourism"~"attraction|museum|artwork|viewpoint|gallery|zoo"](${IzhevskBounds.overpass});
  way["historic"~"monument|memorial|archaeological_site"](${IzhevskBounds.overpass});
  way["leisure"~"park|garden"](${IzhevskBounds.overpass});
  way["natural"="spring"](${IzhevskBounds.overpass});
  way["amenity"~"theatre|arts_centre|planetarium|fountain"](${IzhevskBounds.overpass});
  relation["tourism"~"museum|attraction"](${IzhevskBounds.overpass});
  relation["historic"~"monument|memorial"](${IzhevskBounds.overpass});
  relation["leisure"~"park|garden"](${IzhevskBounds.overpass});
);
out center;
''';

  final http.Client _client;
  List<Spot>? _cache;

  /// Мгновенно отдаёт сохранённый набор мест.
  Future<List<Spot>> loadSnapshot() async {
    final raw = await rootBundle.loadString(_snapshotAsset);
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const SpotsLoadException('Некорректный файл сохранённых мест');
    }

    final spots = <Spot>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        final spot = Spot.fromJson(item);
        if (spot.id.isNotEmpty && spot.name.isNotEmpty) spots.add(spot);
      }
    }

    if (spots.isEmpty) {
      throw const SpotsLoadException('Сохранённый список мест пуст');
    }
    return spots;
  }

  /// Пробует получить актуальные места из Overpass API.
  Future<List<Spot>> fetchFresh() async {
    if (_cache != null) return _cache!;

    Object? lastError;

    for (final endpoint in _endpoints) {
      try {
        final response = await _client
            .post(
              Uri.parse(endpoint),
              headers: {
                'Accept': 'application/json',
                if (!kIsWeb)
                  'User-Agent':
                      'SpotMap/1.0 (Flutter; Izhevsk educational app)',
              },
              body: {'data': _query},
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode != 200) {
          lastError = 'сервер ответил ${response.statusCode}';
          continue;
        }

        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map || decoded['elements'] is! List) {
          lastError = 'неожиданный формат ответа';
          continue;
        }

        final spots = <Spot>[];
        for (final element in decoded['elements'] as List) {
          if (element is Map<String, dynamic>) {
            final spot = Spot.fromOverpassElement(element);
            if (spot != null) spots.add(spot);
          }
        }

        final unique = _dedupe(spots);
        if (unique.length < 10) {
          lastError = 'получено слишком мало мест (${unique.length})';
          continue;
        }

        _cache = unique;
        return unique;
      } catch (error) {
        lastError = error;
      }
    }

    throw SpotsLoadException(
      'Не удалось загрузить данные OpenStreetMap: $lastError',
    );
  }

  List<Spot> _dedupe(List<Spot> spots) {
    final byKey = <String, Spot>{};
    for (final spot in spots) {
      final key =
          '${spot.name.toLowerCase()}|${spot.lat.toStringAsFixed(4)}|${spot.lon.toStringAsFixed(4)}';
      byKey.putIfAbsent(key, () => spot);
    }

    final result = byKey.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  void dispose() => _client.close();
}
