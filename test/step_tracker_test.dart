import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotmap/data/step_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('считает шаги по перемещению GPS', () async {
    final tracker = StepTracker(clock: () => DateTime(2026, 11, 6, 12));
    await tracker.load();

    expect(tracker.addPosition(56.8500, 53.2000), isFalse);
    expect(tracker.addPosition(56.8501, 53.2000), isTrue);

    expect(tracker.meters, closeTo(11.1, 0.5));
    expect(tracker.steps, closeTo(15, 1));
  });

  test('игнорирует GPS-дрожание', () async {
    final tracker = StepTracker(clock: () => DateTime(2026, 11, 6, 12));
    await tracker.load();

    tracker.addPosition(56.8500, 53.2000);
    expect(tracker.addPosition(56.850001, 53.2000), isFalse);
    expect(tracker.steps, 0);
  });

  test('сохраняет и восстанавливает шаги', () async {
    final tracker = StepTracker(clock: () => DateTime(2026, 11, 6, 12));
    await tracker.load();
    tracker.addPosition(56.8500, 53.2000);
    tracker.addPosition(56.8501, 53.2000);
    await tracker.save();

    final restored = StepTracker(clock: () => DateTime(2026, 11, 6, 13));
    await restored.load();

    expect(restored.steps, tracker.steps);
    expect(restored.meters, closeTo(tracker.meters, 0.01));
  });

  test('сбрасывает шаги на следующий день', () async {
    var now = DateTime(2026, 11, 6, 23, 59);
    final tracker = StepTracker(clock: () => now);
    await tracker.load();
    tracker.addPosition(56.8500, 53.2000);
    tracker.addPosition(56.8501, 53.2000);
    await tracker.save();
    expect(tracker.steps, greaterThan(0));

    now = DateTime(2026, 11, 7, 0, 5);
    final nextDay = StepTracker(clock: () => now);
    await nextDay.load();

    expect(nextDay.steps, 0);
    expect(nextDay.meters, 0);
  });
}
