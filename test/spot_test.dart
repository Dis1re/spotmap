import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spotmap/models/spot.dart';
import 'package:spotmap/models/spot_category.dart';

void main() {
  group('Spot.fromJson', () {
    test('читает поля сохранённого места', () {
      final spot = Spot.fromJson({
        'id': 'node/1',
        'name': 'Памятник пельменю',
        'lat': 56.8467,
        'lon': 53.2063,
        'category': 'monument',
        'description': 'Бронзовый пельмень',
      });

      expect(spot.id, 'node/1');
      expect(spot.name, 'Памятник пельменю');
      expect(spot.lat, closeTo(56.8467, 0.00001));
      expect(spot.category, SpotCategory.monument);
      expect(spot.description, 'Бронзовый пельмень');
    });

    test('неизвестная категория превращается в «Другое»', () {
      final spot = Spot.fromJson({
        'id': 'node/2',
        'name': 'Нечто',
        'lat': 0,
        'lon': 0,
        'category': 'unknown-category',
      });

      expect(spot.category, SpotCategory.other);
    });

    test('снимает лишние кавычки вокруг названия', () {
      final spot = Spot.fromJson({
        'id': 'node/3',
        'name': '"Крокодил"',
        'lat': 56.848,
        'lon': 53.2005,
        'category': 'attraction',
      });

      expect(spot.name, 'Крокодил');
    });
  });

  group('SpotCategory.fromOsmTags', () {
    test('распознаёт основные категории', () {
      expect(
        SpotCategory.fromOsmTags({'natural': 'spring'}),
        SpotCategory.spring,
      );
      expect(SpotCategory.fromOsmTags({'leisure': 'park'}), SpotCategory.park);
      expect(
        SpotCategory.fromOsmTags({'historic': 'monument'}),
        SpotCategory.monument,
      );
      expect(
        SpotCategory.fromOsmTags({'tourism': 'museum'}),
        SpotCategory.museum,
      );
      expect(
        SpotCategory.fromOsmTags({'amenity': 'theatre'}),
        SpotCategory.theatre,
      );
      expect(
        SpotCategory.fromOsmTags({'tourism': 'attraction'}),
        SpotCategory.attraction,
      );
    });

    test('игнорирует животных зоопарка и аттракционы', () {
      expect(
        SpotCategory.fromOsmTags({
          'tourism': 'attraction',
          'attraction': 'animal',
        }),
        isNull,
      );
      expect(
        SpotCategory.fromOsmTags({
          'tourism': 'attraction',
          'attraction': 'amusement_ride',
        }),
        isNull,
      );
    });

    test('игнорирует обычные здания', () {
      expect(SpotCategory.fromOsmTags({'building': 'yes'}), isNull);
    });

    test('игнорирует маршруты, аттракционы и коммерческие галереи', () {
      expect(
        SpotCategory.fromOsmTags({
          'type': 'route',
          'route': 'tram',
          'historic': 'yes',
        }),
        isNull,
      );
      expect(
        SpotCategory.fromOsmTags({
          'tourism': 'attraction',
          'attraction': 'bumper_car',
        }),
        isNull,
      );
      expect(
        SpotCategory.fromOsmTags({'tourism': 'zoo', 'zoo': 'petting_zoo'}),
        isNull,
      );
      expect(
        SpotCategory.fromOsmTags({'tourism': 'gallery', 'shop': 'frame'}),
        isNull,
      );
    });
  });

  group('Spot.fromOverpassElement', () {
    test('разбирает точку с центром', () {
      final spot = Spot.fromOverpassElement({
        'type': 'way',
        'id': 42,
        'center': {'lat': 56.85, 'lon': 53.21},
        'tags': {
          'name:ru': 'Парк Кирова',
          'leisure': 'park',
          'description': 'Большой парк',
        },
      });

      expect(spot, isNotNull);
      expect(spot!.id, 'way/42');
      expect(spot.name, 'Парк Кирова');
      expect(spot.category, SpotCategory.park);
      expect(spot.description, 'Большой парк');
    });

    test('возвращает null без координат', () {
      final spot = Spot.fromOverpassElement({
        'type': 'node',
        'id': 43,
        'tags': {'name': 'Без координат', 'tourism': 'attraction'},
      });

      expect(spot, isNull);
    });
  });

  test('сохранённый снимок мест валиден и содержит Ижевск', () {
    final file = File('assets/data/izhevsk_spots.json');
    expect(file.existsSync(), isTrue);

    final decoded = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    expect(decoded.length, greaterThan(250));

    final ids = <String>{};
    final names = <String>[];
    for (final item in decoded) {
      final spot = Spot.fromJson(item as Map<String, dynamic>);

      expect(spot.id, isNotEmpty);
      expect(spot.name.length, greaterThanOrEqualTo(3));
      expect(spot.lat, inInclusiveRange(56.78, 56.93));
      expect(spot.lon, inInclusiveRange(53.08, 53.34));
      expect(ids.add(spot.id), isTrue, reason: 'дубликат id: ${spot.id}');
      names.add(spot.name.toLowerCase());
    }

    expect(
      names.any((name) => name.contains('пельмен')),
      isTrue,
      reason: 'в снимке должен быть памятник пельменю',
    );
    expect(
      names.any((name) => name.contains('звёздочк')),
      isTrue,
      reason: 'в снимке должен быть памятник собаке-космонавту',
    );
  });
}
