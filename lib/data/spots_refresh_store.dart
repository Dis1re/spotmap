import 'package:shared_preferences/shared_preferences.dart';

/// Запоминает, когда места последний раз успешно обновлялись из OSM.
///
/// Автоматическое обновление при запуске выполняется не чаще раза в сутки,
/// чтобы не тратить время и трафик. Кнопка обновления в шапке работает всегда.
class SpotsRefreshStore {
  static const _key = 'spots_last_refresh_v1';
  static const _ttl = Duration(hours: 24);

  Future<bool> isStale() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_key);
    if (timestamp == null) return true;

    final last = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(last) >= _ttl;
  }

  Future<void> markRefreshed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, DateTime.now().millisecondsSinceEpoch);
  }
}
