import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:spotmap/models/spot.dart';
import 'package:spotmap/models/spot_category.dart';
import 'package:spotmap/screens/achievements_screen.dart';
import 'package:spotmap/screens/nearby_screen.dart';

void main() {
  const spots = [
    Spot(
      id: 'near',
      name: 'Ближайшее место',
      lat: 56.8501,
      lon: 53.2001,
      category: SpotCategory.park,
    ),
    Spot(
      id: 'far',
      name: 'Далёкое место',
      lat: 56.86,
      lon: 53.21,
      category: SpotCategory.museum,
    ),
  ];

  testWidgets('экран достижений показывает прогресс', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AchievementsScreen(
          spots: spots,
          visitedIds: const {'near'},
          exploredZones: 12,
        ),
      ),
    );

    expect(find.text('Достижения'), findsOneWidget);
    expect(find.textContaining('Открыто'), findsOneWidget);
    expect(find.text('Первый шаг'), findsOneWidget);
  });

  testWidgets('что рядом показывает ближайшие места', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NearbyScreen(
          spots: spots,
          visitedIds: const {},
          position: const LatLng(56.85, 53.20),
        ),
      ),
    );

    expect(find.text('Что рядом'), findsOneWidget);
    expect(find.text('Ближайшее место'), findsOneWidget);
    expect(find.text('Далёкое место'), findsOneWidget);
    expect(find.textContaining('Найдено 2 мест'), findsOneWidget);
  });

  testWidgets('что рядом показывает пустое состояние', (tester) async {
    const farSpots = [
      Spot(
        id: 'far',
        name: 'Далёкое место',
        lat: 56.99,
        lon: 53.50,
        category: SpotCategory.other,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: NearbyScreen(
          spots: farSpots,
          visitedIds: const {},
          position: const LatLng(56.85, 53.20),
        ),
      ),
    );

    expect(find.text('Поблизости пока ничего нет'), findsOneWidget);
  });
}
