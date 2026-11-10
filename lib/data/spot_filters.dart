import '../models/spot.dart';
import '../models/spot_category.dart';

enum VisitFilter {
  all('Все'),
  visited('Посещённые'),
  unvisited('Не посещённые');

  const VisitFilter(this.label);

  final String label;
}

/// Фильтрует места по названию, категории и статусу посещения.
List<Spot> applySpotFilters({
  required List<Spot> spots,
  required Set<String> visitedIds,
  String query = '',
  SpotCategory? category,
  VisitFilter visit = VisitFilter.all,
}) {
  final search = query.trim().toLowerCase();

  return spots.where((spot) {
    if (category != null && spot.category != category) return false;

    final isVisited = visitedIds.contains(spot.id);
    if (visit == VisitFilter.visited && !isVisited) return false;
    if (visit == VisitFilter.unvisited && isVisited) return false;

    if (search.isNotEmpty && !spot.name.toLowerCase().contains(search)) {
      return false;
    }

    return true;
  }).toList();
}
