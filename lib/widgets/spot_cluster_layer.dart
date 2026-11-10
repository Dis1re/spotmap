import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/spot.dart';
import '../models/spot_category.dart';
import 'spot_marker.dart';

/// Показывает отдельные маркеры вблизи и кластеры при отдалении.
class SpotClusterLayer extends StatelessWidget {
  const SpotClusterLayer({
    super.key,
    required this.spots,
    required this.visitedIds,
    required this.selectedSpotId,
    required this.onSpotTap,
    required this.onClusterTap,
  });

  final List<Spot> spots;
  final Set<String> visitedIds;
  final String? selectedSpotId;
  final ValueChanged<Spot> onSpotTap;
  final void Function(LatLng center, double zoom) onClusterTap;

  static const double _clusterZoom = 15;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final bounds = camera.visibleBounds;

    // Небольшой запас, чтобы маркеры не «моргали» на краю экрана.
    final visible = spots.where((spot) {
      return spot.lat >= bounds.south - 0.01 &&
          spot.lat <= bounds.north + 0.01 &&
          spot.lon >= bounds.west - 0.02 &&
          spot.lon <= bounds.east + 0.02;
    }).toList();

    if (camera.zoom >= _clusterZoom) {
      return MarkerLayer(
        markers: [for (final spot in visible) _spotMarker(spot)],
      );
    }

    final clusters = _buildClusters(visible, camera.zoom);

    return MarkerLayer(
      markers: [
        for (final cluster in clusters)
          if (cluster.spots.length == 1)
            _spotMarker(cluster.spots.first)
          else
            Marker(
              point: cluster.center,
              width: 46,
              height: 46,
              child: _ClusterMarker(
                count: cluster.spots.length,
                allVisited: cluster.spots.every(
                  (spot) => visitedIds.contains(spot.id),
                ),
                color: cluster.dominantCategory.color,
                onTap: () =>
                    onClusterTap(cluster.center, min(camera.zoom + 2, 18)),
              ),
            ),
      ],
    );
  }

  Marker _spotMarker(Spot spot) {
    return Marker(
      point: spot.point,
      width: 38,
      height: 38,
      child: SpotMarker(
        spot: spot,
        visited: visitedIds.contains(spot.id),
        selected: selectedSpotId == spot.id,
        onTap: () => onSpotTap(spot),
      ),
    );
  }

  List<_Cluster> _buildClusters(List<Spot> spots, double zoom) {
    final cellMeters = switch (zoom) {
      < 11 => 2500.0,
      < 12 => 1800.0,
      < 13 => 1200.0,
      < 14 => 800.0,
      _ => 400.0,
    };

    final cellLat = cellMeters / 111320;
    final cellLon = cellMeters / (111320 * cos(56.85 * pi / 180));

    final groups = <String, List<Spot>>{};
    for (final spot in spots) {
      final key =
          '${(spot.lat / cellLat).floor()}_${(spot.lon / cellLon).floor()}';
      groups.putIfAbsent(key, () => []).add(spot);
    }

    return [for (final group in groups.values) _clusterFrom(group)];
  }

  _Cluster _clusterFrom(List<Spot> group) {
    final counts = <SpotCategory, int>{};
    for (final spot in group) {
      counts.update(spot.category, (value) => value + 1, ifAbsent: () => 1);
    }

    final dominant = counts.entries.reduce(
      (first, second) => first.value >= second.value ? first : second,
    );

    return _Cluster(
      spots: group,
      center: LatLng(
        group.map((spot) => spot.lat).reduce((a, b) => a + b) / group.length,
        group.map((spot) => spot.lon).reduce((a, b) => a + b) / group.length,
      ),
      dominantCategory: dominant.key,
    );
  }
}

class _Cluster {
  const _Cluster({
    required this.spots,
    required this.center,
    required this.dominantCategory,
  });

  final List<Spot> spots;
  final LatLng center;
  final SpotCategory dominantCategory;
}

class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({
    required this.count,
    required this.allVisited,
    required this.color,
    required this.onTap,
  });

  final int count;
  final bool allVisited;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: allVisited ? const Color(0xFF2E7D32) : color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6)],
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: TextStyle(
            color: Colors.white,
            fontSize: count > 99 ? 11 : 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
