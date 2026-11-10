import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Хранит координаты, которые пользователь исправил вручную.
class SpotLocationStore {
  static const _key = 'spot_location_overrides_v1';

  Future<Map<String, LatLng>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <String, LatLng>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, LatLng>{};

      final result = <String, LatLng>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map) continue;

        final lat = _toDouble(value['lat']);
        final lon = _toDouble(value['lon']);
        if (lat == null || lon == null) continue;
        result[entry.key.toString()] = LatLng(lat, lon);
      }
      return result;
    } catch (_) {
      return <String, LatLng>{};
    }
  }

  Future<void> save(Map<String, LatLng> overrides) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, dynamic>{
      for (final entry in overrides.entries)
        entry.key: {'lat': entry.value.latitude, 'lon': entry.value.longitude},
    };
    await prefs.setString(_key, jsonEncode(encoded));
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
