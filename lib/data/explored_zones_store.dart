import 'package:shared_preferences/shared_preferences.dart';

/// Хранит ключи уже пройденных зон.
class ExploredZonesStore {
  static const _key = 'explored_zones_v1';
  static const _legacyFogKey = 'cleared_fog_cells_v1';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key);
    if (current != null) return current.toSet();

    // Переносим прогресс из старой версии приложения.
    final legacy = prefs.getStringList(_legacyFogKey);
    if (legacy == null) return <String>{};

    final zones = legacy.toSet();
    await prefs.setStringList(_key, zones.toList()..sort());
    await prefs.remove(_legacyFogKey);
    return zones;
  }

  Future<void> save(Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, keys.toList()..sort());
  }
}
