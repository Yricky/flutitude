import 'dart:async';

import 'package:flutter_lru_cache/lru_cache.dart';
import 'package:flutter_playground/base/q_tree_key.dart';
import 'package:flutter_playground/log.dart';
import 'package:flutter_playground/map/layer/map_tiles.dart';
import 'package:flutter_playground/map/layer/utils.dart';
import 'package:flutter_playground/map/map_canvas.dart';

abstract class MapLayer {
  double zoomResolution();
  void dispose();
  MapTile? getTile({required int key, MapViewState? state});

  Stream<int> getTileChangeStream();
}

class FallbackLayer extends MapLayer {
  final MapLayer _inner;
  final MapTile Function(int key) _fallback;

  FallbackLayer(this._inner, this._fallback);

  @override
  MapTile? getTile({required int key, MapViewState? state}) {
    return _inner.getTile(key: key, state: state) ?? _fallback(key);
  }

  @override
  Stream<int> getTileChangeStream() => _inner.getTileChangeStream();
  @override
  void dispose() {
    _inner.dispose();
  }

  @override
  double zoomResolution() {
    return _inner.zoomResolution();
  }
}

class AsyncMapLayer extends MapLayer {
  final double _res;
  final Future<MapTile> Function(int key) _tileLoader;
  final _tiles = LRUCache<int, MapTile>(2000);
  final _semaphore = Semaphore(16);
  final _loadingTiles = <int, Future<MapTile>>{};
  final StreamController<int> _tileUpdates = StreamController.broadcast();

  AsyncMapLayer(this._tileLoader, this._res);

  @override
  MapTile? getTile({required int key, MapViewState? state}) {
    if (!_tiles.containsKey(key)) {
      loadTile(key: key, state: state);
    }
    return _tiles[key];
  }

  @override
  Stream<int> getTileChangeStream() => _tileUpdates.stream;

  Future<void> loadTile({required int key, MapViewState? state}) async {
    await _semaphore.acquire();
    if (_tiles.containsKey(key) || _loadingTiles.containsKey(key)) {
      _semaphore.release();
      return;
    }
    if (state == null || state.isVisible(key, _res)) {
      try {
        final future = _tileLoader(key);
        _loadingTiles[key] = future;

        final tile = await future;
        _tiles[key] = tile;
        _tileUpdates.add(key);
      } catch (e) {
        print("catch:${e}");
      } finally {
        _loadingTiles.remove(key);
      }
    } else {
      logger.d("tile not visible:${key.keyString()}");
    }
    _semaphore.release();
  }

  @override
  void dispose() {
    _tileUpdates.close();
    _tiles.clear();
    _loadingTiles.clear();
  }

  @override
  double zoomResolution() {
    return _res;
  }
}

Future<MapTile> Function(int key) urlAndCacheImageTileLiader(
  String Function(int) urlBuilder,
  String cacheDir,
  String Function(int) cacheKeyBuilder,
) {
  final FileCache cache = FileCache(cacheDir);
  return (int key) async {
    final url = urlBuilder(key);
    final cacheKey = cacheKeyBuilder(key);
    final file = await cache.read(cacheKey);
    if (file != null) {
      final image = await decodeImage(file);
      return ImageMapTile(image);
    }
    final response = await fetchBytes(url);
    final image = await decodeImage(response);
    cache.write(cacheKey, response);
    return ImageMapTile(image);
  };
}
