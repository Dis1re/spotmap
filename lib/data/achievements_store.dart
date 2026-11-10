import 'package:shared_preferences/shared_preferences.dart';

/// Помнит, о каких достижениях уже сообщили пользователю.
class AchievementsStore {
  static const _key = 'announced_achievements_v1';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  Future<void> save(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ids.toList()..sort());
  }
}
