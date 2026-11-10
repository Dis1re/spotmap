import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:path_provider/path_provider.dart';

const _tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Координаты одного тайла карты.
class TileCoordinate {
  const TileCoordinate(this.zoom, this.x, this.y);

  final int zoom;
  final int x;
  final int y;

  @override
  bool operator ==(Object other) {
    return other is TileCoordinate &&
        other.zoom == zoom &&
        other.x == x &&
        other.y == y;
  }

  @override
  int get hashCode => Object.hash(zoom, x, y);

  @override
  String toString() => '$zoom/$x/$y';
}

/// Постоянный кэш тайлов OpenStreetMap.
///
/// Все просмотренные тайлы сохраняются на устройстве, поэтому карта
/// открывается без интернета там, где пользователь уже был. Дополнительно
/// можно заранее скачать текущий вид.
class MapTileCache {
  MapTileCache._(this._store, this.tileProvider);

  static const int maxPrefetchTiles = 400;
  static const String _userAgent =
      'SpotMap/1.0 (Flutter; Izhevsk educational app)';

  final HiveCacheStore _store;
  final CachedTileProvider tileProvider;

  static Future<MapTileCache> create() async {
    String? directory;
    if (!kIsWeb) {
      final cacheDirectory = await getApplicationCacheDirectory();
      directory = '${cacheDirectory.path}/spotmap_map_tiles';
    }

    final store = HiveCacheStore(
      directory,
      hiveBoxName: 'spotmap_map_tiles_v1',
    );
    final provider = CachedTileProvider(
      store: store,
      maxStale: const Duration(days: 30),
      headers: {if (!kIsWeb) 'User-Agent': _userAgent},
    );

    return MapTileCache._(store, provider);
  }

  /// Скачивает тайлы для прямоугольника и диапазона зумов.
  ///
  /// Возвращает количество успешно сохранённых тайлов. [onProgress] получает
  /// число обработанных и общее число тайлов.
  Future<int> prefetch({
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    int limit = maxPrefetchTiles,
    void Function(int done, int total)? onProgress,
  }) async {
    final tiles = tilesForBounds(bounds, minZoom, maxZoom, limit: limit);
    if (tiles.isEmpty) {
      onProgress?.call(0, 0);
      return 0;
    }

    var saved = 0;
    var processed = 0;
    onProgress?.call(0, tiles.length);

    const batchSize = 4;
    for (var index = 0; index < tiles.length; index += batchSize) {
      final end = min(index + batchSize, tiles.length);
      final batch = tiles.sublist(index, end);
      final results = await Future.wait(batch.map(_downloadTile));

      saved += results.where((success) => success).length;
      processed += batch.length;
      onProgress?.call(processed, tiles.length);
    }

    return saved;
  }

  Future<void> clear() => _store.clean();

  Future<void> close() => _store.close();

  Future<bool> _downloadTile(TileCoordinate tile) async {
    try {
      await tileProvider.dio.get<List<int>>(
        _tileUrl(tile),
        options: Options(
          responseType: ResponseType.bytes,
          headers: tileProvider.headers,
        ),
      );
      return true;
    } catch (_) {
      // Один недоступный тайл не должен отменять всю предзагрузку.
      return false;
    }
  }

  static String _tileUrl(TileCoordinate tile) {
    return _tileUrlTemplate
        .replaceFirst('{z}', '${tile.zoom}')
        .replaceFirst('{x}', '${tile.x}')
        .replaceFirst('{y}', '${tile.y}');
  }

  /// Считает тайлы, покрывающие прямоугольник на указанных зумах.
  static List<TileCoordinate> tilesForBounds(
    LatLngBounds bounds,
    int minZoom,
    int maxZoom, {
    int? limit,
  }) {
    final firstZoom = minZoom.clamp(0, 19).toInt();
    final lastZoom = maxZoom.clamp(firstZoom, 19).toInt();
    final tiles = <TileCoordinate>[];

    for (var zoom = firstZoom; zoom <= lastZoom; zoom++) {
      final count = 1 << zoom;
      final west = _lonToTileX(
        bounds.west,
        count,
      ).floor().clamp(0, count - 1).toInt();
      final east = _lonToTileX(
        bounds.east,
        count,
      ).floor().clamp(0, count - 1).toInt();
      final north = _latToTileY(
        bounds.north,
        count,
      ).floor().clamp(0, count - 1).toInt();
      final south = _latToTileY(
        bounds.south,
        count,
      ).floor().clamp(0, count - 1).toInt();

      final minX = min(west, east);
      final maxX = max(west, east);
      final minY = min(north, south);
      final maxY = max(north, south);

      for (var x = minX; x <= maxX; x++) {
        for (var y = minY; y <= maxY; y++) {
          tiles.add(TileCoordinate(zoom, x, y));
          if (limit != null && tiles.length >= limit) return tiles;
        }
      }
    }

    return tiles;
  }

  static double _lonToTileX(double lon, int count) {
    return (lon + 180) / 360 * count;
  }

  static double _latToTileY(double lat, int count) {
    final clamped = lat.clamp(-85.05112878, 85.05112878).toDouble();
    final radians = clamped * pi / 180;
    return (1 - log(tan(radians) + 1 / cos(radians)) / pi) / 2 * count;
  }
}
