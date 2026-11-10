import 'package:flutter_test/flutter_test.dart';
import 'package:spotmap/data/spot_filters.dart';
import 'package:spotmap/models/spot.dart';
import 'package:spotmap/models/spot_category.dart';

void main() {
  const spots = [
    Spot(
      id: 'node/1',
      name: 'Парк Кирова',
      lat: 56.86,
      lon: 53.16,
      category: SpotCategory.park,
    ),
    Spot(
      id: 'node/2',
      name: 'Памятник пельменю',
      lat: 56.84,
      lon: 53.20,
      category: SpotCategory.monument,
    ),
    Spot(
      id: 'node/3',
      name: 'Родник',
      lat: 56.85,
      lon: 53.18,
      category: SpotCategory.spring,
    ),
  ];

  test('фильтрует по статусу посещения', () {
    final visited = applySpotFilters(
      spots: spots,
      visitedIds: {'node/1'},
      visit: VisitFilter.visited,
    );
    expect(visited.map((spot) => spot.id), ['node/1']);

    final unvisited = applySpotFilters(
      spots: spots,
      visitedIds: {'node/1'},
      visit: VisitFilter.unvisited,
    );
    expect(unvisited.map((spot) => spot.id), ['node/2', 'node/3']);
  });

  test('фильтрует по категории', () {
    final result = applySpotFilters(
      spots: spots,
      visitedIds: const {},
      category: SpotCategory.monument,
    );
    expect(result.map((spot) => spot.name), ['Памятник пельменю']);
  });

  test('ищет по названию без учёта регистра', () {
    final result = applySpotFilters(
      spots: spots,
      visitedIds: const {},
      query: 'ПАРК',
    );
    expect(result.map((spot) => spot.id), ['node/1']);
  });

  test('комбинирует фильтры', () {
    final result = applySpotFilters(
      spots: spots,
      visitedIds: {'node/3'},
      category: SpotCategory.spring,
      visit: VisitFilter.unvisited,
    );
    expect(result, isEmpty);
  });
}
