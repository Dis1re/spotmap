import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spotmap/data/explored_zones_grid.dart';
import 'package:spotmap/data/izhevsk_bounds.dart';

void main() {
  test('квадрат примерно 500 на 500 метров', () {
    final zone = ExploredZonesGrid.zoneFor(56.85, 53.20);
    expect(zone, isNotNull);

    final southWest = zone!.southWest;
    final northEast = zone.northEast;

    final height = (northEast.latitude - southWest.latitude) * 111320;
    final width =
        (northEast.longitude - southWest.longitude) *
        111320 *
        cos((southWest.latitude + northEast.latitude) / 2 * pi / 180);

    expect(height, closeTo(500, 2));
    expect(width, closeTo(500, 15));
  });

  test('сетка покрывает весь прямоугольник Ижевска', () {
    expect(ExploredZonesGrid.rows, greaterThan(20));
    expect(ExploredZonesGrid.cols, greaterThan(20));
    expect(
      ExploredZonesGrid.allZones().length,
      ExploredZonesGrid.rows * ExploredZonesGrid.cols,
    );
  });

  test('точки рядом попадают в один квадрат', () {
    final first = ExploredZonesGrid.zoneFor(56.85, 53.20);
    final second = ExploredZonesGrid.zoneFor(56.85001, 53.20001);

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first!.key, second!.key);
  });

  test('за пределами Ижевска квадрата нет', () {
    expect(ExploredZonesGrid.zoneFor(55.75, 37.61), isNull);
    expect(
      ExploredZonesGrid.zoneFor(IzhevskBounds.south - 0.01, 53.20),
      isNull,
    );
  });

  group('масштаб отрисовки', () {
    test('на приближении квадраты остаются базовыми', () {
      expect(ExploredZonesGrid.displayCellMeters(16), 500);
      expect(ExploredZonesGrid.displayCellMeters(15), 500);
      expect(ExploredZonesGrid.aggregationFactor(15), 1);
    });

    test('на отдалении квадраты растут до 5 км', () {
      expect(ExploredZonesGrid.displayCellMeters(14), 1000);
      expect(ExploredZonesGrid.displayCellMeters(13), 1500);
      expect(ExploredZonesGrid.displayCellMeters(12), 2000);
      expect(ExploredZonesGrid.displayCellMeters(11), 3000);
      expect(ExploredZonesGrid.displayCellMeters(10), 5000);
      expect(ExploredZonesGrid.displayCellMeters(5), 5000);
      expect(ExploredZonesGrid.aggregationFactor(10), 10);
    });

    test('соседние базовые квадраты объединяются на отдалении', () {
      final baseKeys = ['0_0', '0_1', '1_0', '10_20'];

      expect(
        ExploredZonesGrid.displayKeysFor(baseKeys, 15),
        containsAll(baseKeys),
      );

      expect(ExploredZonesGrid.displayKeysFor(baseKeys, 14), {'0_0', '5_10'});

      expect(ExploredZonesGrid.displayKeysFor(baseKeys, 10), {'0_0', '1_2'});
    });

    test('displayKeyFor совпадает с пакетным объединением', () {
      const key = '12_18';
      expect(
        ExploredZonesGrid.displayKeyFor(key, 12),
        ExploredZonesGrid.displayKeysFor([key], 12).single,
      );
    });
  });
}
