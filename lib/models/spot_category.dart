import 'package:flutter/material.dart';

/// Категории мест, которые показываем на карте.
enum SpotCategory {
  park('Парки', Icons.park_outlined, Color(0xFF2E7D32)),
  monument('Памятники', Icons.account_balance_outlined, Color(0xFF6D4C41)),
  museum('Музеи', Icons.museum_outlined, Color(0xFF8E24AA)),
  spring('Родники', Icons.water_drop_outlined, Color(0xFF0277BD)),
  theatre('Театры', Icons.theater_comedy_outlined, Color(0xFFC2185B)),
  attraction('Достопримечательности', Icons.star_outline, Color(0xFFF9A825)),
  fountain('Фонтаны', Icons.waves_outlined, Color(0xFF00838F)),
  other('Другое', Icons.place_outlined, Color(0xFF546E7A));

  const SpotCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static SpotCategory fromName(String value) {
    return SpotCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => SpotCategory.other,
    );
  }

  /// Аттракционы и животные, которые не являются культурными местами.
  static const _amusementAttractions = {
    'animal',
    'amusement_ride',
    'bumper_car',
    'carousel',
    'water_slide',
    'roller_coaster',
    'swing',
    'big_wheel',
    'drop_tower',
    'observation_tower',
    'dark_ride',
    'summer_toboggan',
    'kiddie_ride',
    'train',
    'monorail',
  };

  /// Определяет категорию по тегам OpenStreetMap.
  ///
  /// Возвращает `null`, если объект не относится к культурным местам
  /// (например, животное зоопарка, аттракцион или маршрут транспорта).
  static SpotCategory? fromOsmTags(Map<String, dynamic> tags) {
    String? value(String key) => tags[key]?.toString();

    // Маршруты общественного транспорта иногда ошибочно имеют тег historic.
    if (value('type') == 'route' || value('route') != null) return null;

    if (_amusementAttractions.contains(value('attraction'))) return null;

    if (value('tourism') == 'zoo' && value('zoo') == 'petting_zoo') {
      return null;
    }

    if (value('natural') == 'spring') return SpotCategory.spring;

    if (const {'park', 'garden', 'nature_reserve'}.contains(value('leisure'))) {
      return SpotCategory.park;
    }

    if (value('historic') != null || value('memorial') != null) {
      return SpotCategory.monument;
    }

    final isBusiness =
        value('shop') != null ||
        value('craft') != null ||
        value('office') != null;

    if (const {'museum', 'gallery'}.contains(value('tourism'))) {
      return isBusiness ? null : SpotCategory.museum;
    }

    if (const {'theatre', 'arts_centre'}.contains(value('amenity'))) {
      return SpotCategory.theatre;
    }

    if (value('amenity') == 'fountain') return SpotCategory.fountain;

    if (const {
      'attraction',
      'artwork',
      'viewpoint',
      'zoo',
    }.contains(value('tourism'))) {
      return isBusiness ? null : SpotCategory.attraction;
    }

    if (value('amenity') == 'planetarium') return SpotCategory.museum;

    return null;
  }
}
