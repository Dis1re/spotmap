import 'dart:async';

import 'package:flutter/material.dart';

import '../models/spot.dart';

class SpotDetailsSheet extends StatelessWidget {
  const SpotDetailsSheet({
    super.key,
    required this.spot,
    required this.distanceMeters,
    required this.visited,
    required this.hasCustomLocation,
    required this.onToggleVisited,
    required this.onCorrectLocation,
  });

  final Spot spot;
  final double? distanceMeters;
  final bool visited;
  final bool hasCustomLocation;
  final Future<void> Function() onToggleVisited;
  final VoidCallback onCorrectLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = spot.category;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: category.color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(category.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (visited)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.check_circle,
                      color: Color(0xFF2E7D32),
                      size: 28,
                    ),
                  ),
                IconButton(
                  tooltip: 'Исправить положение',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Navigator.of(context).pop();
                    onCorrectLocation();
                  },
                  icon: const Icon(Icons.edit_location_alt_outlined),
                ),
              ],
            ),
            if (spot.description != null) ...[
              const SizedBox(height: 16),
              Text(spot.description!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.near_me_outlined,
                  label: _distanceLabel(),
                ),
                if (hasCustomLocation)
                  const _InfoChip(
                    icon: Icons.edit_location_alt_outlined,
                    label: 'Положение исправлено',
                  ),
                if (spot.description == null)
                  const _InfoChip(
                    icon: Icons.info_outline,
                    label: 'Открытые данные OSM',
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => unawaited(onToggleVisited()),
                style: FilledButton.styleFrom(
                  backgroundColor: visited ? theme.colorScheme.error : null,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: Icon(visited ? Icons.undo : Icons.check_circle_outline),
                label: Text(visited ? 'Снять отметку' : 'Отметить посещение'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _distanceLabel() {
    if (distanceMeters == null) return 'Расстояние неизвестно';
    return 'До места ${_formatDistance(distanceMeters!)}';
  }

  String _formatDistance(double meters) {
    final value = meters < 0 ? 0 : meters;
    if (value < 1000) return '${value.round()} м';
    return '${(value / 1000).toStringAsFixed(1)} км';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
