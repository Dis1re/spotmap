import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../services/map_tile_cache.dart';

/// Настройки офлайн-карты: предзагрузка текущего вида и очистка кэша.
class OfflineMapSheet extends StatefulWidget {
  const OfflineMapSheet({
    super.key,
    required this.cache,
    required this.bounds,
    required this.zoom,
  });

  final MapTileCache cache;
  final LatLngBounds bounds;
  final double zoom;

  @override
  State<OfflineMapSheet> createState() => _OfflineMapSheetState();
}

class _OfflineMapSheetState extends State<OfflineMapSheet> {
  bool _downloading = false;
  bool _clearing = false;
  int _done = 0;
  int _total = 0;
  int? _saved;
  String? _error;

  int get _minZoom => max(10, min(16, widget.zoom.floor() - 1));

  int get _maxZoom => min(16, max(_minZoom, widget.zoom.floor() + 2));

  int get _tileCount {
    return MapTileCache.tilesForBounds(
      widget.bounds,
      _minZoom,
      _maxZoom,
      limit: MapTileCache.maxPrefetchTiles + 1,
    ).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileCount = _tileCount;
    final capped = tileCount > MapTileCache.maxPrefetchTiles;
    final planned = min(tileCount, MapTileCache.maxPrefetchTiles);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.offline_pin_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Офлайн-карта',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Просмотренные тайлы карты сохраняются автоматически. '
              'Можно заранее скачать текущий вид — он откроется без интернета.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                capped
                    ? 'Будет сохранено $planned тайлов из $tileCount '
                          '(зумы $_minZoom–$_maxZoom). Лимит нужен, чтобы '
                          'не перегружать сервер карт.'
                    : 'Будет сохранено $planned тайлов '
                          '(зумы $_minZoom–$_maxZoom).',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _total == 0 ? null : _done / _total,
              ),
              const SizedBox(height: 6),
              Text(
                _total == 0 ? 'Готовим список тайлов…' : '$_done из $_total',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (_saved != null && !_downloading) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF2E7D32),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Сохранено $_saved тайлов. Этот вид доступен офлайн.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null && !_downloading) ...[
              const SizedBox(height: 12),
              Text(
                'Не удалось скачать карту: $_error',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _downloading || _clearing ? null : _download,
                icon: const Icon(Icons.download_for_offline_outlined),
                label: const Text('Скачать текущий вид'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _downloading || _clearing ? null : _clearCache,
                icon: _clearing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: const Text('Очистить кэш карты'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _done = 0;
      _total = 0;
      _saved = null;
      _error = null;
    });

    try {
      final saved = await widget.cache.prefetch(
        bounds: widget.bounds,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _done = done;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _saved = saved;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Очистить кэш карты?'),
        content: const Text(
          'Удалятся сохранённые тайлы. Для загрузки карты снова '
          'понадобится интернет.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      await widget.cache.clear();
      if (!mounted) return;
      setState(() {
        _clearing = false;
        _saved = null;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Кэш карты очищен')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _clearing = false;
        _error = '$error';
      });
    }
  }
}
