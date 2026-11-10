import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/spot.dart';
import '../utils/formatters.dart';

/// Ближайшие места к текущему местоположению.
///
/// Возвращает выбранное место через `Navigator.pop`, чтобы карта могла
/// центрироваться на нём и открыть карточку.
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({
    super.key,
    required this.spots,
    required this.visitedIds,
    required this.position,
  });

  final List<Spot> spots;
  final Set<String> visitedIds;
  final LatLng position;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

enum _NearbyRadius {
  meters500('500 м', 500),
  kilometers1('1 км', 1000),
  kilometers3('3 км', 3000),
  kilometers5('5 км', 5000),
  all('Все', null);

  const _NearbyRadius(this.label, this.meters);

  final String label;
  final double? meters;
}

class _NearbyScreenState extends State<NearbyScreen> {
  _NearbyRadius _radius = _NearbyRadius.kilometers3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _nearby();
    final radiusLabel = _radius == _NearbyRadius.all
        ? 'во всём городе'
        : 'в радиусе ${_radius.label}';

    return Scaffold(
      appBar: AppBar(title: const Text('Что рядом')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Icon(Icons.near_me_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Найдено ${items.length} мест $radiusLabel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final radius in _NearbyRadius.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(radius.label),
                      selected: _radius == radius,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _radius = radius),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: items.isEmpty
                ? _EmptyNearby(
                    radius: _radius,
                    onShowAll: () =>
                        setState(() => _radius = _NearbyRadius.all),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _NearbyTile(
                        spot: item.spot,
                        distanceMeters: item.distanceMeters,
                        visited: widget.visitedIds.contains(item.spot.id),
                        onTap: () => Navigator.of(context).pop(item.spot),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<_NearbySpot> _nearby() {
    final items = <_NearbySpot>[];

    for (final spot in widget.spots) {
      final distance = Geolocator.distanceBetween(
        widget.position.latitude,
        widget.position.longitude,
        spot.lat,
        spot.lon,
      );
      final radius = _radius.meters;
      if (radius != null && distance > radius) continue;

      items.add(_NearbySpot(spot: spot, distanceMeters: distance));
    }

    items.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return items;
  }
}

class _NearbySpot {
  const _NearbySpot({required this.spot, required this.distanceMeters});

  final Spot spot;
  final double distanceMeters;
}

class _NearbyTile extends StatelessWidget {
  const _NearbyTile({
    required this.spot,
    required this.distanceMeters,
    required this.visited,
    required this.onTap,
  });

  final Spot spot;
  final double distanceMeters;
  final bool visited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = spot.category;
    final parts = [category.label, formatDistance(distanceMeters)];
    if (visited) parts.add('посещено');

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: visited ? const Color(0xFF2E7D32) : category.color,
        child: Icon(
          visited ? Icons.check_rounded : category.icon,
          color: Colors.white,
          size: 21,
        ),
      ),
      title: Text(spot.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(parts.join(' · ')),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _EmptyNearby extends StatelessWidget {
  const _EmptyNearby({required this.radius, required this.onShowAll});

  final _NearbyRadius radius;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text(
              'Поблизости пока ничего нет',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              radius == _NearbyRadius.all
                  ? 'В сохранённом списке не осталось мест.'
                  : 'Попробуйте увеличить радиус поиска.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (radius != _NearbyRadius.all) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onShowAll,
                child: const Text('Показать все места'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
