import 'package:flutter/material.dart';

import 'app.dart';
import 'services/map_tile_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MapTileCache? tileCache;
  try {
    tileCache = await MapTileCache.create();
  } catch (error) {
    debugPrint('Не удалось открыть кэш карты: $error');
  }

  runApp(SpotMapApp(tileCache: tileCache));
}
