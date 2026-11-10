import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../models/spot.dart';

/// Экран достижений. Прогресс считается по уже сохранённым данным.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({
    super.key,
    required this.spots,
    required this.visitedIds,
    required this.exploredZones,
  });

  final List<Spot> spots;
  final Set<String> visitedIds;
  final int exploredZones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final achievements = buildAchievements(
      spots: spots,
      visitedIds: visitedIds,
      exploredZones: exploredZones,
    );
    final unlocked = achievements.where((item) => item.isUnlocked).length;
    final visited = spots.where((spot) => visitedIds.contains(spot.id)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Достижения')),
      body: SafeArea(
        top: false,
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.emoji_events,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Открыто $unlocked из ${achievements.length}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: achievements.isEmpty
                            ? 0
                            : unlocked / achievements.length,
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.onPrimaryContainer
                            .withAlpha(30),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Посещено мест: $visited из ${spots.length} · '
                      'пройдено зон: $exploredZones',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final achievement in achievements)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AchievementCard(achievement: achievement),
              ),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = achievement.isUnlocked;
    final color = unlocked
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: unlocked ? color : color.withAlpha(24),
                shape: BoxShape.circle,
              ),
              child: Icon(
                achievement.icon,
                color: unlocked ? theme.colorScheme.onPrimary : color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (unlocked)
                        Icon(Icons.check_circle, size: 20, color: color),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    achievement.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: achievement.fraction,
                      minHeight: 6,
                      color: color,
                      backgroundColor: color.withAlpha(24),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    unlocked
                        ? 'Получено'
                        : '${achievement.displayProgress} из '
                              '${achievement.target}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: unlocked
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: unlocked ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
