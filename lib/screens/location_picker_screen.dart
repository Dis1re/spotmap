import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/spot.dart';
import '../services/map_tile_cache.dart';

/// Экран ручного исправления координат места.
///
/// Возвращает новую точку через `Navigator.pop`.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, required this.spot, this.tileCache});

  final Spot spot;
  final MapTileCache? tileCache;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _draft = widget.spot.point;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Исправить положение')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.spot.point,
              initialZoom: 17,
              minZoom: 10,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, point) => setState(() => _draft = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.spotmap',
                maxZoom: 19,
                tileProvider: widget.tileCache?.tileProvider,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _draft,
                    width: 54,
                    height: 54,
                    child: const Icon(
                      Icons.location_on,
                      size: 48,
                      color: Color(0xFFC62828),
                    ),
                  ),
                ],
              ),
              SimpleAttributionWidget(
                source: const Text('OpenStreetMap contributors'),
                alignment: Alignment.bottomLeft,
              ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.spot.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Нажмите на карту, чтобы указать правильное место',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_draft.latitude.toStringAsFixed(6)}, '
                        '${_draft.longitude.toStringAsFixed(6)}',
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Отмена'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () =>
                                  Navigator.of(context).pop(_draft),
                              icon: const Icon(Icons.check),
                              label: const Text('Сохранить'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
