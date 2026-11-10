import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../data/spot_filters.dart';
import '../models/spot.dart';
import '../models/spot_category.dart';
import '../utils/formatters.dart';

/// Список всех мест с фильтрами. Возвращает выбранное место через `Navigator.pop`.
class SpotsListScreen extends StatefulWidget {
  const SpotsListScreen({
    super.key,
    required this.spots,
    required this.visitedIds,
    required this.position,
  });

  final List<Spot> spots;
  final Set<String> visitedIds;
  final Position? position;

  @override
  State<SpotsListScreen> createState() => _SpotsListScreenState();
}

class _SpotsListScreenState extends State<SpotsListScreen> {
  final _searchController = TextEditingController();

  String _query = '';
  SpotCategory? _category;
  VisitFilter _visit = VisitFilter.all;
  bool _sortByDistance = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = _filteredSpots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Все места'),
        actions: [
          IconButton(
            tooltip: _sortByDistance
                ? 'Сортировка по расстоянию'
                : 'Сортировка по названию',
            onPressed: widget.position == null
                ? null
                : () {
                    setState(() => _sortByDistance = !_sortByDistance);
                  },
            icon: Icon(_sortByDistance ? Icons.near_me : Icons.sort_by_alpha),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Поиск по названию',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Очистить',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final filter in VisitFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter.label),
                        selected: _visit == filter,
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        onSelected: (_) => setState(() => _visit = filter),
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
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Все категории'),
                      selected: _category == null,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      onSelected: (_) => setState(() => _category = null),
                    ),
                  ),
                  for (final category in _availableCategories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          category.icon,
                          size: 17,
                          color: _category == category
                              ? Colors.white
                              : category.color,
                        ),
                        label: Text(category.label),
                        selected: _category == category,
                        showCheckmark: false,
                        selectedColor: category.color,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        labelStyle: TextStyle(
                          color: _category == category ? Colors.white : null,
                        ),
                        onSelected: (_) {
                          setState(() => _category = category);
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Найдено ${spots.length} из ${widget.spots.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(
              child: spots.isEmpty
                  ? const _EmptyList()
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: spots.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final spot = spots[index];
                        return _SpotTile(
                          spot: spot,
                          visited: widget.visitedIds.contains(spot.id),
                          distanceMeters: _distanceTo(spot),
                          onTap: () => Navigator.of(context).pop(spot),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<SpotCategory> get _availableCategories {
    return SpotCategory.values
        .where(
          (category) => widget.spots.any((spot) => spot.category == category),
        )
        .toList();
  }

  List<Spot> _filteredSpots() {
    final result = applySpotFilters(
      spots: widget.spots,
      visitedIds: widget.visitedIds,
      query: _query,
      category: _category,
      visit: _visit,
    );

    if (_sortByDistance && widget.position != null) {
      result.sort((a, b) {
        final first = _distanceTo(a) ?? double.infinity;
        final second = _distanceTo(b) ?? double.infinity;
        return first.compareTo(second);
      });
    } else {
      result.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    return result;
  }

  double? _distanceTo(Spot spot) {
    final position = widget.position;
    if (position == null) return null;

    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      spot.lat,
      spot.lon,
    );
  }
}

class _SpotTile extends StatelessWidget {
  const _SpotTile({
    required this.spot,
    required this.visited,
    required this.distanceMeters,
    required this.onTap,
  });

  final Spot spot;
  final bool visited;
  final double? distanceMeters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = spot.category;
    final subtitleParts = <String>[category.label];
    if (distanceMeters != null) {
      subtitleParts.add(formatDistance(distanceMeters));
    }
    if (visited) subtitleParts.add('посещено');

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
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text(
              'Ничего не найдено',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Измените фильтры или поисковый запрос.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
