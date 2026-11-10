String formatDistance(double? meters) {
  if (meters == null) return 'расстояние неизвестно';
  final value = meters < 0 ? 0.0 : meters;

  if (value < 1000) return '${value.round()} м';
  return '${(value / 1000).toStringAsFixed(1)} км';
}

String formatNumber(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
}

String stepsLabel(int value) {
  final lastTwo = value % 100;
  final last = value % 10;
  final word = (lastTwo >= 11 && lastTwo <= 14)
      ? 'шагов'
      : switch (last) {
          1 => 'шаг',
          2 || 3 || 4 => 'шага',
          _ => 'шагов',
        };
  return '${formatNumber(value)} $word';
}
