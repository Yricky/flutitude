import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter_playground/ext/mvt/command_extension.dart';
import 'package:flutter_playground/ext/mvt/vector_tile.pbserver.dart';
import 'package:flutter_playground/map/layer/map_tiles.dart';

class MvtTile extends MapTile {
  final List<DrawCacheItem> drawCache;

  MvtTile(Tile tile) : drawCache = _parseTile(tile);

  @override
  void draw(Canvas canvas, Paint paint, Rect rect) {
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width, rect.height);
    paint
      ..strokeWidth = 1 / rect.width
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;

    paint.color = const Color(0xffff0000);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), paint);
    paint.color = const Color(0xFF9999ff);

    int tc = 0;
    int pc = 0;
    int lc = 0;
    for (var element in drawCache) {
      switch (element) {
        case TextPoint():
          canvas.save();
          canvas.translate(element.position.dx, element.position.dy);
          canvas.scale(1 / rect.width, 1 / rect.height);
          for (var text in element.texts) {
            text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
          }
          canvas.restore();
          tc++;
          break;
        case Points():
          // paint
          //   ..strokeWidth = 2 / rect.width
          //   ..strokeCap = StrokeCap.round
          //   ..style = PaintingStyle.stroke;
          canvas.drawRawPoints(PointMode.points, element.position, paint);
          pc++;
          break;
        case Lines():
          final path;
          // if (rect.width < 384 || rect.height < 384) {
          //   path = element.lowLevelPath;
          // } else {
          path = element.path;
          // }
          canvas.drawPath(path, paint);
          lc++;
          break;
        default:
      }
    }
    canvas.save();
    canvas.scale(1 / rect.width, 1 / rect.height);
    TextPainter(
      text: TextSpan(
          text: "tc:$tc, lc:$lc, pc: $pc",
          style: TextStyle(
            fontSize: 10,
            foreground: Paint()
              ..style = PaintingStyle.fill
              ..color = const Color(0xffff0000),
          )),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )
      ..layout()
      ..paint(canvas, Offset.zero);
    canvas.restore();
    canvas.restore();
  }
}

// 绘制缓存，其中的坐标均为瓦片内归一化坐标
abstract class DrawCacheItem {
  const DrawCacheItem();
}

class TextPoint extends DrawCacheItem {
  final Offset position;
  final List<TextPainter> texts;

  const TextPoint({required this.position, required this.texts});
}

class Points extends DrawCacheItem {
  final Float32List position;
  const Points(this.position);
}

class Lines extends DrawCacheItem {
  final Path path;
  final Path lowLevelPath;

  const Lines({required this.path, required this.lowLevelPath});
}

List<DrawCacheItem> _parseTile(Tile tile) {
  final layers = tile.layers;
  final List<DrawCacheItem> items = [];
  for (final layer in layers) {
    final features = layer.features;
    for (final feature in features) {
      final props = <String, String>{};
      final tags = feature.tags;
      for (var i = 0; i < tags.length - 1; i += 2) {
        final keyIndex = tags[i];
        final valIndex = tags[i + 1];
        if (keyIndex < layer.keys.length && valIndex < layer.values.length) {
          props[layer.keys[keyIndex]] = layer.values[valIndex].stringValue;
        }
      }
      final geometry = feature.geometry;
      switch (feature.type) {
        case Tile_GeomType.LINESTRING:
          final path = Path();
          final lowLevelPath = Path();
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
                path.moveTo(lastX, lastY);
                lowLevelPath.moveTo(lastX, lastY);
                i += 3;
                break;

              case GeoCmd.lineTo: // LineTo
                for (int j = 0; j < parameterCount; j++) {
                  cursorX += geometry[i + 1 + j * 2].parameterValue;
                  cursorY += geometry[i + 2 + j * 2].parameterValue;

                  final nowX = cursorX / layer.extent;
                  final nowY = cursorY / layer.extent;
                  path.lineTo(nowX, nowY);
                  if ((nowY - lastY).abs() > 0.03 ||
                      (nowX - lastX).abs() > 0.03 ||
                      j == parameterCount - 1) {
                    lowLevelPath.lineTo(nowX, nowY);
                    lastX = nowX;
                    lastY = nowY;
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
          items.add(Lines(path: path, lowLevelPath: lowLevelPath));
          break;
        case Tile_GeomType.POINT:
          final cmd = geometry[0];
          final count = cmd.count;
          final list = Float32List(count * 2);
          for (int i = 0; i < count * 2; i++) {
            list[i] = geometry[i + 1].parameterValue.toDouble() / layer.extent;
          }
          final name = props['name'];
          if (list.length == 2 && name != null && name.isNotEmpty) {
            final textPainter = TextPainter(
              text: TextSpan(text: name),
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
            );
            textPainter.layout();
            items.add(TextPoint(
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
            items.add(Points(list));
          }
          break;
        case Tile_GeomType.POLYGON:
          // TODO: Handle this case.
          break;
        case Tile_GeomType.UNKNOWN:
          break;
      }
    }
  }
  final ret = <DrawCacheItem>[];
  for (var item in items) {
    if (item is Lines && ret.isNotEmpty) {
      final last = ret.last;
      if (last is Lines) {
        last.lowLevelPath.addPath(item.lowLevelPath, Offset.zero);
        last.path.addPath(item.path, Offset.zero);
      } else {
        ret.add(item);
      }
    } else {
      ret.add(item);
    }
  }
  return ret;
}
