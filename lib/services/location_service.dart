import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Обёртка над geolocator: понятные ошибки и одни настройки для всего приложения.
class LocationService {
  static const _streamSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5,
  );

  Future<Position> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationException(
          'Геолокация выключена. Включите GPS и попробуйте снова.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw const LocationException('Доступ к геопозиции запрещён.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw LocationException(
          kIsWeb
              ? 'Геолокация заблокирована. Нажмите на замок в адресной '
                    'строке браузера и разрешите доступ для этого сайта.'
              : 'Доступ к геопозиции запрещён навсегда. '
                    'Разрешите его в настройках приложения.',
        );
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );
    } on LocationException {
      rethrow;
    } catch (error) {
      throw LocationException('Не удалось определить местоположение: $error');
    }
  }

  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(locationSettings: _streamSettings);
  }
}
