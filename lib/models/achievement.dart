import 'dart:math';

import 'package:flutter/material.dart';

import 'spot.dart';
import 'spot_category.dart';

/// Достижение и прогресс по нему.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.target,
    required this.progress,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int target;
  final int progress;

  bool get isUnlocked => target > 0 && progress >= target;

  int get displayProgress {
    if (progress < 0) return 0;
    if (progress > target) return target;
    return progress;
  }

  double get fraction {
    if (target <= 0) return 0;
    return displayProgress / target;
  }
}

/// Собирает достижения из уже сохранённого прогресса.
///
/// Достижения не хранятся отдельно: они всегда пересчитываются по
/// посещённым местам и пройденным зонам, поэтому не могут «потеряться»
/// или разойтись с реальными данными.
List<Achievement> buildAchievements({
  required List<Spot> spots,
  required Set<String> visitedIds,
  required int exploredZones,
}) {
  final visited = spots
      .where((spot) => visitedIds.contains(spot.id))
      .toList(growable: false);
  final total = spots.length;

  int totalIn(SpotCategory category) =>
      spots.where((spot) => spot.category == category).length;
  int visitedIn(SpotCategory category) =>
      visited.where((spot) => spot.category == category).length;

  final visitedCategories = visited.map((spot) => spot.category).toSet().length;
  final quarterTarget = max(1, (total * 0.25).ceil());
  final halfTarget = max(1, (total * 0.5).ceil());

  final achievements = <Achievement>[
    Achievement(
      id: 'first_spot',
      title: 'Первый шаг',
      description: 'Отметьте первое посещённое место',
      icon: Icons.flag_outlined,
      target: 1,
      progress: visited.length,
    ),
    Achievement(
      id: 'five_spots',
      title: 'Пять мест',
      description: 'Отметьте пять разных мест',
      icon: Icons.looks_5_outlined,
      target: 5,
      progress: visited.length,
    ),
    Achievement(
      id: 'fifteen_spots',
      title: 'Городской исследователь',
      description: 'Отметьте пятнадцать мест',
      icon: Icons.explore_outlined,
      target: 15,
      progress: visited.length,
    ),
    Achievement(
      id: 'quarter_city',
      title: 'Четверть пути',
      description: 'Откройте четверть всех мест Ижевска',
      icon: Icons.map_outlined,
      target: quarterTarget,
      progress: visited.length,
    ),
    Achievement(
      id: 'half_city',
      title: 'Половина Ижевска',
      description: 'Откройте половину всех мест',
      icon: Icons.public,
      target: halfTarget,
      progress: visited.length,
    ),
    Achievement(
      id: 'all_city',
      title: 'Весь Ижевск',
      description: 'Отметьте все места на карте',
      icon: Icons.workspace_premium_outlined,
      target: total,
      progress: visited.length,
    ),
    if (totalIn(SpotCategory.park) > 0)
      Achievement(
        id: 'parks',
        title: 'Парковый человек',
        description: 'Побывайте в десяти парках',
        icon: Icons.park_outlined,
        target: min(10, totalIn(SpotCategory.park)),
        progress: visitedIn(SpotCategory.park),
      ),
    if (totalIn(SpotCategory.monument) > 0)
      Achievement(
        id: 'monuments',
        title: 'Знаток истории',
        description: 'Посмотрите десять памятников',
        icon: Icons.account_balance_outlined,
        target: min(10, totalIn(SpotCategory.monument)),
        progress: visitedIn(SpotCategory.monument),
      ),
    if (totalIn(SpotCategory.museum) > 0)
      Achievement(
        id: 'museums',
        title: 'Музейный завсегдатай',
        description: 'Посетите пять музеев',
        icon: Icons.museum_outlined,
        target: min(5, totalIn(SpotCategory.museum)),
        progress: visitedIn(SpotCategory.museum),
      ),
    if (totalIn(SpotCategory.spring) > 0)
      Achievement(
        id: 'springs',
        title: 'Родниковая тропа',
        description: 'Найдите все родники Ижевска',
        icon: Icons.water_drop_outlined,
        target: totalIn(SpotCategory.spring),
        progress: visitedIn(SpotCategory.spring),
      ),
    if (totalIn(SpotCategory.theatre) > 0)
      Achievement(
        id: 'theatres',
        title: 'Театрал',
        description: 'Посетите пять театров',
        icon: Icons.theater_comedy_outlined,
        target: min(5, totalIn(SpotCategory.theatre)),
        progress: visitedIn(SpotCategory.theatre),
      ),
    Achievement(
      id: 'categories',
      title: 'Разносторонний',
      description: 'Посетите места из трёх разных категорий',
      icon: Icons.category_outlined,
      target: 3,
      progress: visitedCategories,
    ),
    Achievement(
      id: 'zones_10',
      title: 'Первые километры',
      description: 'Пройдите десять зон города',
      icon: Icons.directions_walk,
      target: 10,
      progress: exploredZones,
    ),
    Achievement(
      id: 'zones_50',
      title: 'Ходок',
      description: 'Пройдите пятьдесят зон',
      icon: Icons.route_outlined,
      target: 50,
      progress: exploredZones,
    ),
    Achievement(
      id: 'zones_150',
      title: 'Пешеходный марафон',
      description: 'Пройдите сто пятьдесят зон',
      icon: Icons.hiking,
      target: 150,
      progress: exploredZones,
    ),
  ];

  return achievements;
}
