import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotmap/data/spot_location_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('сохраняет и загружает исправленные координаты', () async {
    final store = SpotLocationStore();
    await store.save({
      'node/1': const LatLng(56.85, 53.20),
      'node/2': const LatLng(56.86, 53.21),
    });

    final loaded = await SpotLocationStore().load();

    expect(loaded.length, 2);
    expect(loaded['node/1']!.latitude, closeTo(56.85, 1e-9));
    expect(loaded['node/1']!.longitude, closeTo(53.20, 1e-9));
    expect(loaded['node/2']!.latitude, closeTo(56.86, 1e-9));
  });

  test('возвращает пустую карту при повреждённых данных', () async {
    SharedPreferences.setMockInitialValues({
      'spot_location_overrides_v1': 'not json',
    });

    final loaded = await SpotLocationStore().load();

    expect(loaded, isEmpty);
  });
}
