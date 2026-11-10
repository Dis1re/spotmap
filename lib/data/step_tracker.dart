import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Считает шаги за сегодня по перемещению GPS.
///
/// Это оценка: длина шага принимается равной 0,72 м, а шаги считаются,
/// пока приложение открыто и получает координаты.
class StepTracker {
  StepTracker({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const double strideMeters = 0.72;
  static const double _minMoveMeters = 1.8;
  static const double _maxMoveMeters = 60;

  static const _dateKey = 'steps_date';
  static const _stepsKey = 'steps_count';
  static const _metersKey = 'steps_meters';

  final DateTime Function() _clock;

  double _steps = 0;
  double _meters = 0;
  double? _lastLat;
  double? _lastLon;
  String _date = '';
  DateTime? _lastSaved;

  int get steps => _steps.round();
  double get meters => _meters;

  String get _today {
    final now = _clock();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today;
    _date = prefs.getString(_dateKey) ?? '';

    if (_date == today) {
      _steps = prefs.getDouble(_stepsKey) ?? 0;
      _meters = prefs.getDouble(_metersKey) ?? 0;
    } else {
      _steps = 0;
      _meters = 0;
      _date = today;
      await save();
    }

    _lastSaved = _clock();
  }

  /// Возвращает `true`, если шаги изменились.
  bool addPosition(double lat, double lon) {
    _rolloverIfNeeded();

    final lastLat = _lastLat;
    final lastLon = _lastLon;
    _lastLat = lat;
    _lastLon = lon;

    if (lastLat == null || lastLon == null) return false;

    final distance = _distanceMeters(lastLat, lastLon, lat, lon);
    if (distance < _minMoveMeters || distance > _maxMoveMeters) {
      return false;
    }

    _meters += distance;
    _steps += distance / strideMeters;

    final now = _clock();
    if (_lastSaved == null ||
        now.difference(_lastSaved!) > const Duration(seconds: 5)) {
      _lastSaved = now;
      unawaited(save());
    }
    return true;
  }

  void _rolloverIfNeeded() {
    final today = _today;
    if (_date == today) return;

    _date = today;
    _steps = 0;
    _meters = 0;
    _lastLat = null;
    _lastLon = null;
    unawaited(save());
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dateKey, _date);
    await prefs.setDouble(_stepsKey, _steps);
    await prefs.setDouble(_metersKey, _meters);
  }

  static double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    const toRadians = pi / 180;

    final dLat = (lat2 - lat1) * toRadians;
    final dLon = (lon2 - lon1) * toRadians;
    final a =
        pow(sin(dLat / 2), 2) +
        cos(lat1 * toRadians) * cos(lat2 * toRadians) * pow(sin(dLon / 2), 2);
    return 2 * earthRadius * atan2(sqrt(a), sqrt(1 - a));
  }
}
