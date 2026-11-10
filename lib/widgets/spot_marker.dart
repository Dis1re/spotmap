import 'package:flutter/material.dart';

import '../models/spot.dart';

class SpotMarker extends StatelessWidget {
  const SpotMarker({
    super.key,
    required this.spot,
    required this.visited,
    required this.selected,
    required this.onTap,
  });

  final Spot spot;
  final bool visited;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = visited ? const Color(0xFF2E7D32) : spot.category.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: selected ? 3 : 2),
        ),
        child: Icon(
          visited ? Icons.check_rounded : spot.category.icon,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}
