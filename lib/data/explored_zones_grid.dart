import 'dart:math';

import 'package:latlong2/latlong.dart';

import 'izhevsk_bounds.dart';

/// Один базовый квадрат пройденной зоны размером примерно 500 × 500 метров.
class ExploredZone {
  const ExploredZone(this.row, this.col);

  final int row;
  final int col;

  String get key => '${row}_$col';

  static ExploredZone? fromKey(String key) {
    final separator = key.indexOf('_');
    if (separator <= 0) return null;

    final row = int.tryParse(key.substring(0, separator));
    final col = int.tryParse(key.substring(separator + 1));
    if (row == null || col == null) return null;

    return ExploredZone(row, col);
  }

  LatLng get southWest => LatLng(
    IzhevskBounds.south + row * ExploredZonesGrid.cellLat,
    IzhevskBounds.west + col * ExploredZonesGrid.cellLon,
  );

  LatLng get northEast => LatLng(
    IzhevskBounds.south + (row + 1) * ExploredZonesGrid.cellLat,
    IzhevskBounds.west + (col + 1) * ExploredZonesGrid.cellLon,
  );

  List<LatLng> get corners => [
    southWest,
    LatLng(southWest.latitude, northEast.longitude),
    northEast,
    LatLng(northEast.latitude, southWest.longitude),
  ];
}

/// Сетка пройденных зон поверх Ижевска.
///
/// Хранится и открывается базовыми квадратами 500 × 500 м. Для отрисовки
/// на отдалённом масштабе соседние квадраты объединяются в более крупные —
/// так же, как маркеры собираются в кластеры. Максимальный размер такого
/// квадрата — 5 км.
class ExploredZonesGrid {
  const ExploredZonesGrid._();

  static const double baseCellMeters = 500;
  static const double maxDisplayCellMeters = 5000;
  static const double _metersPerDegreeLat = 111320;

  static final double cellLat = baseCellMeters / _metersPerDegreeLat;

  /// Долгота зависит от широты: на широте Ижевска 1° заметно короче.
  static final double cellLon =
      baseCellMeters /
      (_metersPerDegreeLat *
          cos(((IzhevskBounds.south + IzhevskBounds.north) / 2) * pi / 180));

  static final int rows =
      ((IzhevskBounds.north - IzhevskBounds.south) / cellLat).ceil();
  static final int cols = ((IzhevskBounds.east - IzhevskBounds.west) / cellLon)
      .ceil();

  /// Размер объединённого квадрата на текущем зуме карты.
  static double displayCellMeters(double zoom) {
    if (zoom >= 15) return baseCellMeters;
    if (zoom >= 14) return 1000;
    if (zoom >= 13) return 1500;
    if (zoom >= 12) return 2000;
    if (zoom >= 11) return 3000;
    return maxDisplayCellMeters;
  }

  /// Во сколько базовых квадратов превращается один квадрат отрисовки.
  static int aggregationFactor(double zoom) =>
      (displayCellMeters(zoom) / baseCellMeters).round();

  static double displayCellLat(double zoom) =>
      displayCellMeters(zoom) / _metersPerDegreeLat;

  static double displayCellLon(double zoom) =>
      displayCellMeters(zoom) /
      (_metersPerDegreeLat *
          cos(((IzhevskBounds.south + IzhevskBounds.north) / 2) * pi / 180));

  /// Ключ объединённого квадрата для базового ключа на текущем зуме.
  static String displayKeyFor(String baseKey, double zoom) {
    final zone = ExploredZone.fromKey(baseKey);
    if (zone == null) return baseKey;

    final factor = aggregationFactor(zoom);
    return ExploredZone(zone.row ~/ factor, zone.col ~/ factor).key;
  }

  /// Объединяет набор базовых квадратов для отрисовки на текущем зуме.
  static Set<String> displayKeysFor(Iterable<String> baseKeys, double zoom) {
    final factor = aggregationFactor(zoom);
    final keys = <String>{};

    for (final key in baseKeys) {
      final zone = ExploredZone.fromKey(key);
      if (zone == null) continue;
      keys.add(ExploredZone(zone.row ~/ factor, zone.col ~/ factor).key);
    }

    return keys;
  }

  static List<ExploredZone> allZones() => [
    for (var row = 0; row < rows; row++)
      for (var col = 0; col < cols; col++) ExploredZone(row, col),
  ];

  static int rowFor(double lat) {
    return ((lat - IzhevskBounds.south) / cellLat).floor().clamp(0, rows - 1);
  }

  static int colFor(double lon) {
    return ((lon - IzhevskBounds.west) / cellLon).floor().clamp(0, cols - 1);
  }

  static ExploredZone? zoneFor(double lat, double lon) {
    if (lat < IzhevskBounds.south ||
        lat > IzhevskBounds.north ||
        lon < IzhevskBounds.west ||
        lon > IzhevskBounds.east) {
      return null;
    }

    return ExploredZone(rowFor(lat), colFor(lon));
  }
}
