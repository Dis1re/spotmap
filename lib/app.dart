import 'package:flutter/material.dart';

import 'screens/map_screen.dart';
import 'services/map_tile_cache.dart';

class SpotMapApp extends StatelessWidget {
  const SpotMapApp({super.key, this.tileCache});

  final MapTileCache? tileCache;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF00695C);

    return MaterialApp(
      title: 'Спотмап · Ижевск',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF6F4EF),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: MapScreen(tileCache: tileCache),
    );
  }
}
