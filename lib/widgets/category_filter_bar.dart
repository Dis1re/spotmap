import 'package:flutter/material.dart';

import '../models/spot_category.dart';

class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({
    super.key,
    required this.selected,
    required this.categories,
    required this.onSelected,
  });

  final SpotCategory? selected;
  final List<SpotCategory> categories;
  final ValueChanged<SpotCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
        children: [
          _FilterChip(
            label: 'Все',
            icon: Icons.apps,
            color: Theme.of(context).colorScheme.primary,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final category in categories)
            _FilterChip(
              label: category.label,
              icon: category.icon,
              color: category.color,
              selected: selected == category,
              onTap: () => onSelected(category),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: color,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        avatar: Icon(icon, size: 17, color: selected ? Colors.white : color),
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? Colors.white : null,
        ),
      ),
    );
  }
}
