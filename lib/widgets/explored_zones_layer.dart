import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../data/explored_zones_grid.dart';
import '../data/izhevsk_bounds.dart';

/// Рисует пройденные зоны одним слоем.
///
/// В отличие от отдельных Polygon-виджетов, здесь всё рисуется на одном
/// canvas. Сначала заливается видимая часть города, затем вырезаются уже
/// пройденные квадраты, а сетка рисуется несколькими линиями, а не тысячами
/// прямоугольников. На отдалении соседние квадраты объединяются, поэтому
/// линий и вырезов становится только меньше.
class ExploredZonesLayer extends StatelessWidget {
  const ExploredZonesLayer({
    super.key,
    required this.exploredZones,
    required this.version,
  });

  final Set<String> exploredZones;

  /// Меняется при открытии новой зоны, чтобы слой перерисовался.
  final int version;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final displayKeys = ExploredZonesGrid.displayKeysFor(
      exploredZones,
      camera.zoom,
    );

    return IgnorePointer(
      child: CustomPaint(
        size: Size(camera.size.x, camera.size.y),
        painter: _ExploredZonesPainter(
          camera: camera,
          displayKeys: displayKeys,
          version: version,
        ),
      ),
    );
  }
}

class _ExploredZonesPainter extends CustomPainter {
  _ExploredZonesPainter({
    required this.camera,
    required this.displayKeys,
    required this.version,
  });

  final MapCamera camera;
  final Set<String> displayKeys;
  final int version;

  static const _fill = Color(0x22FF3D8B);
  static const _border = Color(0x55FF3D8B);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = camera.visibleBounds;
    if (bounds.north < IzhevskBounds.south ||
        bounds.south > IzhevskBounds.north ||
        bounds.east < IzhevskBounds.west ||
        bounds.west > IzhevskBounds.east) {
      return;
    }

    final viewport = Offset.zero & size;
    final cityRect = Rect.fromPoints(
      camera.getOffsetFromOrigin(
        LatLng(IzhevskBounds.north, IzhevskBounds.west),
      ),
      camera.getOffsetFromOrigin(
        LatLng(IzhevskBounds.south, IzhevskBounds.east),
      ),
    );
    final visibleCity = cityRect.intersect(viewport);
    if (visibleCity.isEmpty) return;

    final cellLat = ExploredZonesGrid.displayCellLat(camera.zoom);
    final cellLon = ExploredZonesGrid.displayCellLon(camera.zoom);

    final minRow = ((bounds.south - IzhevskBounds.south) / cellLat).floor();
    final maxRow = ((bounds.north - IzhevskBounds.south) / cellLat).floor();
    final minCol = ((bounds.west - IzhevskBounds.west) / cellLon).floor();
    final maxCol = ((bounds.east - IzhevskBounds.west) / cellLon).floor();

    final holes = <Rect>[];
    for (final key in displayKeys) {
      final zone = ExploredZone.fromKey(key);
      if (zone == null) continue;
      if (zone.row < minRow ||
          zone.row > maxRow ||
          zone.col < minCol ||
          zone.col > maxCol) {
        continue;
      }

      final rect = _zoneRect(zone.row, zone.col, cellLat, cellLon);
      if (rect.overlaps(visibleCity)) holes.add(rect);
    }

    final zonesPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(visibleCity);
    for (final hole in holes) {
      zonesPath.addRect(hole);
    }

    final fillPaint = Paint()..color = _fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _border;

    canvas.save();
    canvas.clipRect(visibleCity);
    canvas.drawPath(zonesPath, fillPaint);

    if (holes.isNotEmpty) {
      canvas.save();
      canvas.clipPath(zonesPath, doAntiAlias: false);
    }
    _drawGrid(canvas, minRow, maxRow, minCol, maxCol, visibleCity, borderPaint);
    if (holes.isNotEmpty) {
      canvas.restore();
    }
    canvas.restore();
  }

  Rect _zoneRect(int row, int col, double cellLat, double cellLon) {
    final south = IzhevskBounds.south + row * cellLat;
    final west = IzhevskBounds.west + col * cellLon;

    final topLeft = camera.getOffsetFromOrigin(LatLng(south + cellLat, west));
    final bottomRight = camera.getOffsetFromOrigin(
      LatLng(south, west + cellLon),
    );
    return Rect.fromPoints(topLeft, bottomRight);
  }

  /// Рисует границы квадратов парой десятков линий вместо тысяч рамок.
  void _drawGrid(
    Canvas canvas,
    int minRow,
    int maxRow,
    int minCol,
    int maxCol,
    Rect visible,
    Paint paint,
  ) {
    final cellLat = ExploredZonesGrid.displayCellLat(camera.zoom);
    final cellLon = ExploredZonesGrid.displayCellLon(camera.zoom);
    final path = Path();

    for (var row = minRow; row <= maxRow + 1; row++) {
      final lat = IzhevskBounds.south + row * cellLat;
      final y = camera.getOffsetFromOrigin(LatLng(lat, IzhevskBounds.west)).dy;
      path.moveTo(visible.left, y);
      path.lineTo(visible.right, y);
    }

    for (var col = minCol; col <= maxCol + 1; col++) {
      final lon = IzhevskBounds.west + col * cellLon;
      final x = camera.getOffsetFromOrigin(LatLng(IzhevskBounds.south, lon)).dx;
      path.moveTo(x, visible.top);
      path.lineTo(x, visible.bottom);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ExploredZonesPainter oldDelegate) {
    return oldDelegate.version != version || oldDelegate.camera != camera;
  }
}
