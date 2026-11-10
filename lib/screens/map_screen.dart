import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/achievements_store.dart';
import '../data/explored_zones_grid.dart';
import '../data/explored_zones_store.dart';
import '../data/spots_refresh_store.dart';
import '../data/spots_repository.dart';
import '../data/step_tracker.dart';
import '../data/visited_spots_store.dart';
import '../models/achievement.dart';
import '../models/spot.dart';
import '../models/spot_category.dart';
import '../services/location_service.dart';
import '../services/map_tile_cache.dart';
import '../utils/formatters.dart';
import '../widgets/category_filter_bar.dart';
import '../widgets/explored_zones_layer.dart';
import '../widgets/offline_map_sheet.dart';
import '../widgets/spot_cluster_layer.dart';
import '../widgets/spot_details_sheet.dart';
import 'achievements_screen.dart';
import 'nearby_screen.dart';
import 'spots_list_screen.dart';

enum _MapAction { refresh, toggleZones, offlineMap }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.tileCache});

  final MapTileCache? tileCache;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _izhevskCenter = LatLng(56.8528, 53.2115);

  final _mapController = MapController();
  final _spotsRepository = SpotsRepository();
  final _spotsRefreshStore = SpotsRefreshStore();
  final _visitedStore = VisitedSpotsStore();
  final _locationService = LocationService();
  final _exploredZonesStore = ExploredZonesStore();
  final _achievementsStore = AchievementsStore();
  final _stepTracker = StepTracker();

  List<Spot> _spots = const [];
  Set<String> _visitedIds = <String>{};
  Set<String> _exploredZones = <String>{};
  Set<String> _announcedAchievements = <String>{};
  int _zonesVersion = 0;
  SpotCategory? _filter;
  String? _selectedSpotId;

  Position? _position;
  StreamSubscription<Position>? _positionSubscription;

  bool _loading = true;
  bool _refreshing = false;
  bool _locating = false;
  bool _showZones = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    unawaited(_stepTracker.save());
    _spotsRepository.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_loadError != null) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final spots = await _spotsRepository.loadSnapshot();
      final visited = await _visitedStore.load();
      final exploredZones = await _exploredZonesStore.load();
      final announced = await _achievementsStore.load();
      await _stepTracker.load();

      // Достижения, открытые до этого запуска, не показываем как новые.
      final unlockedNow = buildAchievements(
        spots: spots,
        visitedIds: visited,
        exploredZones: exploredZones.length,
      ).where((achievement) => achievement.isUnlocked).map((item) => item.id);
      final announcedWithCurrent = {...announced, ...unlockedNow};
      await _achievementsStore.save(announcedWithCurrent);

      if (!mounted) return;

      _exploredZones = exploredZones;
      _announcedAchievements = announcedWithCurrent;

      setState(() {
        _spots = spots;
        _visitedIds = visited;
        _loading = false;
      });

      unawaited(_refreshSpotsIfStale());
      unawaited(_startLocation(showErrors: true));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Не удалось открыть сохранённые места: $error';
      });
    }
  }

  List<Spot> get _visibleSpots {
    final filter = _filter;
    if (filter == null) return _spots;
    return _spots.where((spot) => spot.category == filter).toList();
  }

  List<SpotCategory> get _availableCategories {
    return SpotCategory.values
        .where((category) => _spots.any((spot) => spot.category == category))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleSpots = _visibleSpots;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Спотмап · Ижевск',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              _spots.isEmpty
                  ? 'Загружаем места…'
                  : 'Открыто ${_visitedIds.length} из ${_spots.length} · '
                        '${stepsLabel(_stepTracker.steps)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Список всех мест',
            onPressed: _openSpotsList,
            icon: const Icon(Icons.list_alt),
          ),
          IconButton(
            tooltip: 'Что рядом',
            onPressed: _openNearby,
            icon: const Icon(Icons.near_me_outlined),
          ),
          IconButton(
            tooltip: 'Достижения',
            onPressed: _openAchievements,
            icon: const Icon(Icons.emoji_events_outlined),
          ),
          PopupMenuButton<_MapAction>(
            tooltip: 'Ещё',
            onSelected: _onMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _MapAction.refresh,
                enabled: !_refreshing,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _refreshing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    const SizedBox(width: 12),
                    const Text('Обновить места из OSM'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _MapAction.toggleZones,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showZones
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _showZones
                          ? 'Скрыть пройденные зоны'
                          : 'Показать пройденные зоны',
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _MapAction.offlineMap,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.offline_pin_outlined),
                    SizedBox(width: 12),
                    Text('Офлайн-карта'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Material(
            color: theme.colorScheme.surface,
            child: CategoryFilterBar(
              selected: _filter,
              categories: _availableCategories,
              onSelected: (category) {
                setState(() => _filter = category);
              },
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _izhevskCenter,
              initialZoom: 13.2,
              minZoom: 10,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, _) {
                if (_selectedSpotId != null) {
                  setState(() => _selectedSpotId = null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.spotmap',
                maxZoom: 19,
                tileProvider: widget.tileCache?.tileProvider,
              ),
              if (_showZones)
                ExploredZonesLayer(
                  exploredZones: _exploredZones,
                  version: _zonesVersion,
                ),
              if (_position != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(_position!.latitude, _position!.longitude),
                      radius: _position!.accuracy,
                      useRadiusInMeter: true,
                      color: Colors.blue.withAlpha(28),
                      borderColor: Colors.blue.withAlpha(90),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              SpotClusterLayer(
                spots: visibleSpots,
                visitedIds: _visitedIds,
                selectedSpotId: _selectedSpotId,
                onSpotTap: (spot) => unawaited(_openSpot(spot)),
                onClusterTap: (center, zoom) {
                  _mapController.move(center, zoom);
                },
              ),
              if (_position != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_position!.latitude, _position!.longitude),
                      width: 26,
                      height: 26,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Color(0x44000000), blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              SimpleAttributionWidget(
                source: const Text('OpenStreetMap contributors'),
                alignment: Alignment.bottomLeft,
              ),
            ],
          ),
          if (_loading)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text('Загружаем места Ижевска…'),
                    ],
                  ),
                ),
              ),
            ),
          if (_loadError != null)
            Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 36),
                      const SizedBox(height: 12),
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _bootstrap,
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_refreshing)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _locating ? null : _goToMe,
        tooltip: 'Где я',
        child: _locating
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _position == null
                    ? Icons.location_searching
                    : Icons.my_location,
              ),
      ),
    );
  }

  void _onMenuAction(_MapAction action) {
    switch (action) {
      case _MapAction.refresh:
        unawaited(_refreshSpots(silent: false));
      case _MapAction.toggleZones:
        setState(() => _showZones = !_showZones);
      case _MapAction.offlineMap:
        unawaited(_openOfflineMap());
    }
  }

  double? _distanceTo(Spot spot) {
    final position = _position;
    if (position == null) return null;
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      spot.lat,
      spot.lon,
    );
  }

  Future<void> _openSpot(Spot spot) async {
    final distance = _distanceTo(spot);
    setState(() => _selectedSpotId = spot.id);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var visited = _visitedIds.contains(spot.id);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SpotDetailsSheet(
              spot: spot,
              distanceMeters: distance,
              visited: visited,
              onToggleVisited: () async {
                await _toggleVisited(spot);
                if (context.mounted) {
                  setSheetState(() {
                    visited = _visitedIds.contains(spot.id);
                  });
                }
              },
            );
          },
        );
      },
    );

    if (mounted) {
      setState(() => _selectedSpotId = null);
    }
  }

  Future<void> _toggleVisited(Spot spot) async {
    final nowVisited = !_visitedIds.contains(spot.id);

    setState(() {
      if (nowVisited) {
        _visitedIds.add(spot.id);
      } else {
        _visitedIds.remove(spot.id);
      }
    });

    await _visitedStore.save(_visitedIds);
    final newAchievements = await _takeNewAchievements();

    if (!mounted) return;
    final message = nowVisited
        ? 'Отмечено: ${spot.name}'
        : 'Отметка снята: ${spot.name}';
    _showMessage(
      newAchievements.isEmpty
          ? message
          : '$message · Достижение: ${_achievementNames(newAchievements)}',
    );
  }

  Future<void> _refreshSpotsIfStale() async {
    if (!await _spotsRefreshStore.isStale()) return;
    await _refreshSpots(silent: true);
  }

  Future<void> _refreshSpots({required bool silent}) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);

    try {
      final fresh = await _spotsRepository.fetchFresh();
      if (!mounted) return;
      setState(() {
        _spots = fresh;
        _loadError = null;
      });
      unawaited(_spotsRefreshStore.markRefreshed());
      if (!silent) {
        _showMessage('Загружено ${fresh.length} мест из OpenStreetMap');
      }
    } on SpotsLoadException catch (error) {
      if (!mounted) return;
      if (!silent) {
        _showMessage(
          'Не удалось обновить: ${error.message}. '
          'Показаны сохранённые места.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (!silent) {
        _showMessage('Не удалось обновить данные: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _startLocation({required bool showErrors}) async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;

      setState(() => _locating = false);
      _applyPosition(position);
      _listenToPosition();
    } on LocationException catch (error) {
      if (!mounted) return;
      setState(() => _locating = false);
      if (showErrors) {
        _showMessage(
          error.message,
          action: kIsWeb
              ? null
              : SnackBarAction(
                  label: 'Настройки',
                  onPressed: () {
                    unawaited(Geolocator.openAppSettings());
                  },
                ),
        );
      }
    }
  }

  void _listenToPosition() {
    _positionSubscription ??= _locationService.positionStream().listen(
      (position) {
        if (!mounted) return;
        _applyPosition(position);
      },
      onError: (_) {
        if (!mounted) return;
        _showMessage('Не удалось обновить геопозицию');
      },
    );
  }

  void _applyPosition(Position position) {
    final previous = _position;
    final previousZonesVersion = _zonesVersion;

    _clearZoneAt(position);
    _stepTracker.addPosition(position.latitude, position.longitude);

    if (!mounted) return;

    // Не перестраиваем всю карту из-за каждого GPS-тика: обновляем экран,
    // только когда пользователь заметно сдвинулся, изменилась точность
    // или открылась новая зона.
    final moved =
        previous == null ||
        Geolocator.distanceBetween(
              previous.latitude,
              previous.longitude,
              position.latitude,
              position.longitude,
            ) >=
            2;
    final accuracyChanged =
        previous != null && (previous.accuracy - position.accuracy).abs() >= 20;

    if (!moved && !accuracyChanged && previousZonesVersion == _zonesVersion) {
      return;
    }

    setState(() => _position = position);
  }

  void _clearZoneAt(Position position) {
    final zone = ExploredZonesGrid.zoneFor(
      position.latitude,
      position.longitude,
    );
    if (zone == null || _exploredZones.contains(zone.key)) return;

    _exploredZones.add(zone.key);
    _zonesVersion++;
    unawaited(_exploredZonesStore.save(_exploredZones));
    unawaited(_announceNewAchievements());
  }

  Future<List<Achievement>> _takeNewAchievements() async {
    final newOnes =
        buildAchievements(
              spots: _spots,
              visitedIds: _visitedIds,
              exploredZones: _exploredZones.length,
            )
            .where(
              (achievement) =>
                  achievement.isUnlocked &&
                  !_announcedAchievements.contains(achievement.id),
            )
            .toList(growable: false);

    if (newOnes.isEmpty) return const <Achievement>[];

    _announcedAchievements.addAll(newOnes.map((item) => item.id));
    await _achievementsStore.save(_announcedAchievements);
    return newOnes;
  }

  Future<void> _announceNewAchievements() async {
    final newOnes = await _takeNewAchievements();
    if (newOnes.isEmpty || !mounted) return;
    _showMessage('Достижение: ${_achievementNames(newOnes)}');
  }

  String _achievementNames(List<Achievement> achievements) {
    return achievements.map((item) => '«${item.title}»').join(', ');
  }

  Future<void> _openSpotsList() async {
    final selected = await Navigator.of(context).push<Spot>(
      MaterialPageRoute(
        builder: (_) => SpotsListScreen(
          spots: _spots,
          visitedIds: Set<String>.of(_visitedIds),
          position: _position,
        ),
      ),
    );

    if (selected == null || !mounted) return;

    _mapController.move(selected.point, 16);
    await _openSpot(selected);
  }

  Future<void> _openNearby() async {
    if (_position == null) {
      await _startLocation(showErrors: true);
    }

    final position = _position;
    if (!mounted || position == null) return;

    final selected = await Navigator.of(context).push<Spot>(
      MaterialPageRoute(
        builder: (_) => NearbyScreen(
          spots: _spots,
          visitedIds: Set<String>.of(_visitedIds),
          position: LatLng(position.latitude, position.longitude),
        ),
      ),
    );

    if (selected == null || !mounted) return;

    _mapController.move(selected.point, 16);
    await _openSpot(selected);
  }

  Future<void> _openAchievements() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AchievementsScreen(
          spots: _spots,
          visitedIds: Set<String>.of(_visitedIds),
          exploredZones: _exploredZones.length,
        ),
      ),
    );
  }

  Future<void> _openOfflineMap() async {
    final cache = widget.tileCache;
    if (cache == null) {
      _showMessage('Кэш карты недоступен на этом устройстве.');
      return;
    }

    final camera = _mapController.camera;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => OfflineMapSheet(
        cache: cache,
        bounds: camera.visibleBounds,
        zoom: camera.zoom,
      ),
    );
  }

  Future<void> _goToMe() async {
    final position = _position;
    if (position == null) {
      await _startLocation(showErrors: true);
      final newPosition = _position;
      if (newPosition != null) {
        _mapController.move(
          LatLng(newPosition.latitude, newPosition.longitude),
          16,
        );
      }
      return;
    }

    _mapController.move(LatLng(position.latitude, position.longitude), 16);
  }

  void _showMessage(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: action,
          duration: const Duration(seconds: 4),
        ),
      );
  }
}
