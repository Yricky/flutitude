import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_lru_cache/lru_cache.dart';
import 'package:flutter_playground/base/q_tree_key.dart';
import 'package:flutter_playground/ext/mvt/command_extension.dart';
import 'package:flutter_playground/ext/mvt/draw_kit/draw_cache.dart';
import 'package:flutter_playground/ext/mvt/mvt_tile.dart';
import 'package:flutter_playground/ext/mvt/parse_kit/common.dart';
import 'package:flutter_playground/ext/mvt/vector_tile.pb.dart';
import 'package:flutter_playground/log.dart';
import 'package:flutter_playground/map/layer/map_layer.dart';
import 'package:flutter_playground/map/layer/map_tiles.dart';
import 'package:flutter_playground/map/layer/utils.dart';
import 'package:flutter_playground/map/map_canvas.dart';

class BingTileSet {
  final MvtTile backgroundTile;
  final MvtTile roadTile;
  final MvtTile textTile;

  BingTileSet(
      {required this.backgroundTile,
      required this.roadTile,
      required this.textTile});
}

class BingLayers {
  final double _res;
  final Set<int> _loadingTiles = <int>{};
  final _tiles = LRUCache<int, BingTileSet>(2000);
  final _semaphore = Semaphore(16);
  final StreamController<int> _tileUpdates = StreamController.broadcast();

  final _defaultRoadPaint = Paint()
    ..color = const Color(0xff000000)
    ..style = PaintingStyle.stroke;
  final _defaultBackgroundPaint = Paint()
    ..color = const Color(0xff000000)
    ..style = PaintingStyle.fill;
  final Map<String, Paint> _roadPaints = {};
  final Map<String, Paint> _backgroundPaints = {};

  BingLayers(this._res) {
    _backgroundPaints["vector_background"] = Paint()
      ..color = const Color(0xffffffee)
      ..style = PaintingStyle.fill;
    _backgroundPaints["water_feature"] = Paint()
      ..color = const Color(0xff66ccff)
      ..style = PaintingStyle.fill;
    _backgroundPaints["water_pattern_area"] = Paint()
      ..color = const Color(0xff66ccff)
      ..style = PaintingStyle.fill;
    _backgroundPaints["continent"] = Paint()
      ..color = const Color(0xffccccff)
      ..style = PaintingStyle.fill;
    _backgroundPaints["island"] = Paint()
      ..color = const Color(0xffccccff)
      ..style = PaintingStyle.fill;
    _backgroundPaints["land_cover_urban"] = Paint()
      ..color = const Color.fromARGB(255, 255, 210, 120)
      ..style = PaintingStyle.fill;
    _backgroundPaints["tourist_structure"] = Paint()
      ..color = const Color(0xff66ccff)
      ..style = PaintingStyle.fill;
    _backgroundPaints["educational_structure"] = Paint()
      ..color = const Color(0xff9999ff)
      ..style = PaintingStyle.fill;
    _backgroundPaints["airport"] = Paint()
      ..color = const Color.fromARGB(255, 255, 102, 222)
      ..style = PaintingStyle.fill;

    _roadPaints["country_region"] = Paint()
      ..color = const Color.fromARGB(255, 177, 177, 177)
      ..style = PaintingStyle.stroke;
    _roadPaints["road"] = Paint()
      ..color = const Color.fromARGB(255, 255, 175, 55)
      ..style = PaintingStyle.stroke;
    _roadPaints["road_hd"] = Paint()
      ..color = const Color.fromARGB(255, 255, 175, 55)
      ..style = PaintingStyle.stroke;
    _roadPaints["railway_cn"] = Paint()
      ..color = const Color.fromARGB(255, 100, 100, 100)
      ..style = PaintingStyle.stroke;
    _roadPaints["railway"] = Paint()
      ..color = const Color.fromARGB(255, 100, 100, 100)
      ..style = PaintingStyle.stroke;
  }

  BingTileSet? getTile(int key, MapViewState? state) {
    if (!_tiles.containsKey(key)) {
      loadTile(key: key, state: state);
    }
    return _tiles[key];
  }

  Future<void> loadTile({required int key, MapViewState? state}) async {
    await _semaphore.acquire();
    if (_tiles.containsKey(key) || _loadingTiles.contains(key)) {
      _semaphore.release();
      return;
    }
    if (state == null || state.isVisible(key, _res)) {
      try {
        final future = fetchBytes(
                "https://r2.dynamic.tiles.ditu.live.com/comp/ch/${key.depth}-${key.x}-${key.y}.mvt?mkt=zh-CN,en-US&it=G,AP,L,LA&jp=0&js=1&tj=1&ur=cn&cstl=s23&mvt=1&features=mvt,mvttxtmaxw,mvtfcall,lsoft&og=1&st=bld%7Cv:0_g%7Cpv:1&sv=9.27")
            .then((value) {
          return compute(Tile.fromBuffer, value);
        }).then((value) {
          return parseBingTile(value);
        });
        _loadingTiles.add(key);
        final tile = await future;
        _tiles[key] = tile;
        _tileUpdates.add(key);
      } finally {
        _loadingTiles.remove(key);
      }
    } else {
      logger.d("bing tile not visible:${key.keyString()}");
    }
    _semaphore.release();
  }

  BingTileSet parseBingTile(Tile tile) {
    final layers = tile.layers;
    final List<DrawCacheItem> itemsB = [];
    final List<DrawCacheItem> itemsR = [];
    final List<DrawCacheItem> itemsT = [];
    for (final layer in layers) {
      final features = layer.features;
      for (final feature in features) {
        final props = parseFeatureProps(layer, feature);
        final name = props['name'];
        final geometry = feature.geometry;
        switch (feature.type) {
          case Tile_GeomType.POLYGON:
            final path = Path()..fillType = PathFillType.nonZero;
            List<Offset> polygon = [];
            double cursorX = 0;
            double cursorY = 0;

            for (int i = 0; i < geometry.length;) {
              final cmd = geometry[i];
              final commandId = cmd.commandId;
              final parameterCount = cmd.count;

              double lastX = 0;
              double lastY = 0;

              switch (commandId) {
                case GeoCmd.moveTo: // MoveTo
                  cursorX += geometry[i + 1].parameterValue;
                  cursorY += geometry[i + 2].parameterValue;
                  lastX = cursorX / layer.extent;
                  lastY = cursorY / layer.extent;
                  polygon.add(Offset(lastX, lastY));
                  i += 3;
                  break;

                case GeoCmd.lineTo: // LineTo
                  for (int j = 0; j < parameterCount; j++) {
                    cursorX += geometry[i + 1 + j * 2].parameterValue;
                    cursorY += geometry[i + 2 + j * 2].parameterValue;

                    final nowX = cursorX / layer.extent;
                    final nowY = cursorY / layer.extent;
                    polygon.add(Offset(nowX, nowY));
                    if ((nowY - lastY).abs() > 0.03 ||
                        (nowX - lastX).abs() > 0.03 ||
                        j == parameterCount - 1) {
                      lastX = nowX;
                      lastY = nowY;
                    }
                  }
                  i += 1 + parameterCount * 2;
                  break;

                case GeoCmd.closePath: // ClosePath
                  path.addPolygon(polygon, true);
                  polygon = [];
                  i += 1;
                  break;

                default:
                  i = geometry.length;
                  break;
              }
            }
            Paint? paint = _backgroundPaints[layer.name];
            if (paint == null) {
              print("POLYGON layer:${layer.name}");
              paint = _defaultBackgroundPaint;
            }
            itemsB.add(Polygon(path: path, paint: paint));
            break;
          case Tile_GeomType.LINESTRING:
            double cursorX = 0;
            double cursorY = 0;
            List<Offset>? line = null;
            final path = Path();

            for (int i = 0; i < geometry.length;) {
              final cmd = geometry[i];
              final commandId = cmd.commandId;
              final parameterCount = cmd.count;

              double lastX = 0;
              double lastY = 0;

              switch (commandId) {
                case GeoCmd.moveTo: // MoveTo
                  if (line != null) {
                    clipLine(line, const Rect.fromLTWH(0, 0, 1, 1))
                        .forEach((l) {
                      path.moveTo(l[0].dx, l[0].dy);
                      for (int j = 1; j < l.length; j++) {
                        path.lineTo(l[j].dx, l[j].dy);
                      }
                    });
                  }
                  cursorX += geometry[i + 1].parameterValue;
                  cursorY += geometry[i + 2].parameterValue;
                  lastX = cursorX / layer.extent;
                  lastY = cursorY / layer.extent;
                  line = [Offset(lastX, lastY)];
                  i += 3;
                  break;

                case GeoCmd.lineTo: // LineTo
                  for (int j = 0; j < parameterCount; j++) {
                    cursorX += geometry[i + 1 + j * 2].parameterValue;
                    cursorY += geometry[i + 2 + j * 2].parameterValue;

                    lastX = cursorX / layer.extent;
                    lastY = cursorY / layer.extent;
                    if (line != null) {
                      final offset = Offset(lastX, lastY);
                      line.add(offset);
                    }
                  }
                  i += 1 + parameterCount * 2;
                  break;

                case GeoCmd.closePath: // ClosePath
                  i += 1;
                  break;

                default:
                  i = geometry.length;
                  break;
              }
            }
            Paint? paint = _roadPaints[layer.name];
            // paint.strokeWidth = 1;
            if (paint == null) {
              print("LINE layer:${layer.name}");
              paint = _defaultRoadPaint;
            }
            if (line != null) {
              clipLine(line, const Rect.fromLTWH(0, 0, 1, 1)).forEach((l) {
                path.moveTo(l[0].dx, l[0].dy);
                for (int j = 1; j < l.length; j++) {
                  path.lineTo(l[j].dx, l[j].dy);
                }
              });
            }
            itemsR.add(Lines(path: path, paint: paint));
            break;
          case Tile_GeomType.POINT:
            final cmd = geometry[0];
            final count = cmd.count;
            final list = Float32List(count * 2);
            for (int i = 0; i < count * 2; i++) {
              list[i] =
                  geometry[i + 1].parameterValue.toDouble() / layer.extent;
            }
            if (list.length == 2 && name != null && name.isNotEmpty) {
              final textPainter = TextPainter(
                text: TextSpan(text: name),
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
              );
              textPainter.layout();
              itemsT.add(TextPoint(
                position: Offset(list[0], list[1]),
                texts: [
                  TextPainter(
                    text: TextSpan(
                        text: name,
                        style: TextStyle(
                          fontSize: 12,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 2
                            ..color = const Color(0xff000000),
                        )),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                  )..layout(),
                  TextPainter(
                    text: TextSpan(
                        text: name,
                        style: TextStyle(
                          fontSize: 12,
                          foreground: Paint()
                            ..style = PaintingStyle.fill
                            ..color = const Color(0xffffffff),
                        )),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                  )..layout()
                ],
              ));
            } else {
              itemsT.add(Points(list));
            }
            break;
          case Tile_GeomType.UNKNOWN:
            break;
        }
      }
    }
    return BingTileSet(
        backgroundTile: MvtTile(itemsB),
        roadTile: MvtTile(itemsR),
        textTile: MvtTile(itemsT));
  }

  Stream<int> getTileChangeStream() => _tileUpdates.stream;
}

class BingMapLayer extends MapLayer {
  final BingLayers _layers;
  final MapTile? Function(BingTileSet?) _tileGetter;
  BingMapLayer(this._layers, this._tileGetter);

  @override
  void dispose() {}

  @override
  MapTile? getTile({required int key, MapViewState? state}) {
    return _tileGetter(_layers.getTile(key, state));
  }

  @override
  Stream<int> getTileChangeStream() {
    return _layers._tileUpdates.stream;
  }

  @override
  double zoomResolution() {
    return _layers._res;
  }
}
