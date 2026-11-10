/// Границы области Ижевска, для которой собираются места и пройденные зоны.
class IzhevskBounds {
  const IzhevskBounds._();

  static const double south = 56.78;
  static const double west = 53.08;
  static const double north = 56.93;
  static const double east = 53.34;

  /// Формат для Overpass API: юг, запад, север, восток.
  static const String overpass = '$south,$west,$north,$east';
}
