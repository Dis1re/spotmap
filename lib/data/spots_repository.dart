import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/spot.dart';
import '../models/spot_category.dart';
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
  node["historic"](${IzhevskBounds.overpass});
  node["memorial"](${IzhevskBounds.overpass});
  node["leisure"~"park|garden|nature_reserve"](${IzhevskBounds.overpass});
  node["natural"="spring"](${IzhevskBounds.overpass});
  node["amenity"~"theatre|arts_centre|planetarium|fountain"](${IzhevskBounds.overpass});
  way["tourism"~"attraction|museum|artwork|viewpoint|gallery|zoo"](${IzhevskBounds.overpass});
  way["historic"](${IzhevskBounds.overpass});
  way["memorial"](${IzhevskBounds.overpass});
  way["leisure"~"park|garden|nature_reserve"](${IzhevskBounds.overpass});
  way["natural"="spring"](${IzhevskBounds.overpass});
  way["amenity"~"theatre|arts_centre|planetarium|fountain"](${IzhevskBounds.overpass});
  relation["tourism"~"museum|attraction"](${IzhevskBounds.overpass});
  relation["historic"](${IzhevskBounds.overpass});
  relation["memorial"](${IzhevskBounds.overpass});
  relation["leisure"~"park|garden|nature_reserve"](${IzhevskBounds.overpass});
  relation["natural"="spring"](${IzhevskBounds.overpass});
);
out center;
''';

  /// Точки, которые не являются культурными местами или дублируют другие.
  static const _hiddenSpotIds = <String>{
    'node/11384884537', // багетная мастерская с тегом tourism=gallery
    'node/13717734955', // Yoga без культурного объекта
    'node/2613424919', // студия звукозаписи с тегом arts_centre
    'node/13387737806', // перечисление животных контактного зоопарка
    'node/13052029822', // узел «Замок» без тегов
    'node/5723697927', // дубль «Я люблю Ижевск» без тегов
    'node/13893515459', // дубль граффити с fixme
    'node/13465257752', // руины с названием «родник»
    'node/13617799202', // «Свиньи» из контактного зоопарка
    'relation/1970577', // трамвайный маршрут с тегом historic
    'way/821216127', // части того же сквера имени В.И. Зверева
    'way/821216128',
  };

  static const _nameOverrides = <String, String>{
    'node/10931834809': 'Памятник Крокодилу Гене',
    'node/2398192092': 'Памятник А. Ф. Дерябину',
    'node/999706511': 'Памятник А. С. Пушкину',
    'node/2348003715': 'Памятник ижевским оружейникам',
    'node/10737261203': 'Памятник В. Ф. Маргелову',
    'node/13276544367': 'Памятник Д. Ф. Устинову',
  };

  /// Места, которых нет в OSM, но они важны для города.
  static const _curatedSpots = <Spot>[
    Spot(
      id: 'curated/pelmen',
      name: 'Памятник пельменю',
      lat: 56.842276,
      lon: 53.239447,
      category: SpotCategory.monument,
      description:
          'Городская скульптура «Пельмень» на вилке у ресторана «Позимь», '
          'улица Владимира Краева, 35А.',
    ),
    Spot(
      id: 'curated/zvezdochka',
      name: 'Памятник собаке-космонавту Звёздочке',
      lat: 56.85,
      lon: 53.289722,
      category: SpotCategory.monument,
      description:
          'Памятник собаке-космонавту Звёздочке у бывшей взлётной полосы '
          'старого аэродрома, улица Молодёжная, 34.',
    ),
  ];

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
    return _applyCurated(spots);
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

        final unique = _applyCurated(_dedupe(spots));
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

    return byKey.values.toList();
  }

  /// Убирает скрытые точки, исправляет названия и добавляет курируемые места.
  List<Spot> _applyCurated(Iterable<Spot> spots) {
    final byId = <String, Spot>{};

    for (final spot in spots) {
      if (_hiddenSpotIds.contains(spot.id)) continue;

      final renamed = _nameOverrides[spot.id];
      byId[spot.id] = renamed == null
          ? spot
          : Spot(
              id: spot.id,
              name: renamed,
              lat: spot.lat,
              lon: spot.lon,
              category: spot.category,
              description: spot.description,
            );
    }

    for (final extra in _curatedSpots) {
      if (byId.containsKey(extra.id)) continue;

      final exists = byId.values.any((spot) => _isSameSpot(spot, extra));
      if (!exists) byId[extra.id] = extra;
    }

    return byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  bool _isSameSpot(Spot a, Spot b) {
    if (a.name.toLowerCase() != b.name.toLowerCase()) return false;
    return (a.lat - b.lat).abs() <= 0.001 && (a.lon - b.lon).abs() <= 0.002;
  }

  void dispose() => _client.close();
}
