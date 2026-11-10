import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:spotmap/services/map_tile_cache.dart';

void main() {
  final bounds = LatLngBounds(
    const LatLng(56.84, 53.19),
    const LatLng(56.86, 53.22),
  );

  test('тайлы покрывают прямоугольник без дублей', () {
    final tiles = MapTileCache.tilesForBounds(bounds, 13, 15);

    expect(tiles, isNotEmpty);
    expect(tiles.toSet().length, tiles.length);
    expect(tiles.every((tile) => tile.zoom >= 13 && tile.zoom <= 15), isTrue);
  });

  test('лимит ограничивает предзагрузку', () {
    final tiles = MapTileCache.tilesForBounds(bounds, 10, 16, limit: 5);

    expect(tiles.length, 5);
  });

  test('диапазон зумов ограничивается допустимыми значениями', () {
    final tiles = MapTileCache.tilesForBounds(bounds, -3, 30);

    expect(tiles, isNotEmpty);
    expect(tiles.first.zoom, 0);
    expect(tiles.last.zoom, 19);
  });

  test('координаты тайлов не выходят за границы мира', () {
    final world = LatLngBounds(const LatLng(-89, -179), const LatLng(89, 179));
    final tiles = MapTileCache.tilesForBounds(world, 2, 2);

    expect(tiles, isNotEmpty);
    for (final tile in tiles) {
      expect(tile.x, inInclusiveRange(0, 3));
      expect(tile.y, inInclusiveRange(0, 3));
    }
  });
}
