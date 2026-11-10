import 'package:flutter_test/flutter_test.dart';
import 'package:spotmap/models/achievement.dart';
import 'package:spotmap/models/spot.dart';
import 'package:spotmap/models/spot_category.dart';

Spot _spot(String id, SpotCategory category) {
  return Spot(
    id: id,
    name: 'Место $id',
    lat: 56.85,
    lon: 53.20,
    category: category,
  );
}

void main() {
  final spots = [
    for (var index = 0; index < 5; index++)
      _spot('park$index', SpotCategory.park),
    for (var index = 0; index < 3; index++)
      _spot('monument$index', SpotCategory.monument),
    _spot('museum0', SpotCategory.museum),
    _spot('museum1', SpotCategory.museum),
    _spot('spring0', SpotCategory.spring),
    _spot('theatre0', SpotCategory.theatre),
  ];

  Achievement byId(List<Achievement> items, String id) {
    return items.firstWhere((item) => item.id == id);
  }

  test('достижения открываются по прогрессу посещений', () {
    final achievements = buildAchievements(
      spots: spots,
      visitedIds: {'park0', 'park1', 'monument0', 'museum0', 'spring0'},
      exploredZones: 0,
    );

    expect(byId(achievements, 'first_spot').isUnlocked, isTrue);
    expect(byId(achievements, 'five_spots').isUnlocked, isTrue);
    expect(byId(achievements, 'fifteen_spots').isUnlocked, isFalse);
    expect(byId(achievements, 'quarter_city').isUnlocked, isTrue);
    expect(byId(achievements, 'half_city').isUnlocked, isFalse);
  });

  test('категорийные цели не превышают число мест', () {
    final achievements = buildAchievements(
      spots: spots,
      visitedIds: const {},
      exploredZones: 0,
    );

    expect(byId(achievements, 'parks').target, 5);
    expect(byId(achievements, 'monuments').target, 3);
    expect(byId(achievements, 'museums').target, 2);
    expect(byId(achievements, 'springs').target, 1);
    expect(byId(achievements, 'theatres').target, 1);
  });

  test('прогресс по категориям считается отдельно', () {
    final achievements = buildAchievements(
      spots: spots,
      visitedIds: {'park0', 'park1', 'park2', 'spring0'},
      exploredZones: 0,
    );

    expect(byId(achievements, 'parks').progress, 3);
    expect(byId(achievements, 'springs').isUnlocked, isTrue);
    expect(byId(achievements, 'categories').progress, 2);
  });

  test('пройденные зоны открывают достижения по зонам', () {
    final achievements = buildAchievements(
      spots: spots,
      visitedIds: const {},
      exploredZones: 60,
    );

    expect(byId(achievements, 'zones_10').isUnlocked, isTrue);
    expect(byId(achievements, 'zones_50').isUnlocked, isTrue);
    expect(byId(achievements, 'zones_150').isUnlocked, isFalse);
  });

  test('прогресс не превышает цель', () {
    final achievements = buildAchievements(
      spots: spots,
      visitedIds: {'park0', 'park1', 'park2', 'park3', 'park4'},
      exploredZones: 0,
    );

    final quarter = byId(achievements, 'quarter_city');
    expect(quarter.target, 3);
    expect(quarter.displayProgress, 3);
    expect(quarter.fraction, 1);
  });

  test('без мест в категории достижение не создаётся', () {
    final achievements = buildAchievements(
      spots: [_spot('park0', SpotCategory.park)],
      visitedIds: const {},
      exploredZones: 0,
    );

    expect(achievements.where((item) => item.id == 'springs'), isEmpty);
  });
}
