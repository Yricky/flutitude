import 'dart:ui';

import 'package:flutitude/ext/mvt/vector_tile.pbserver.dart';
import 'package:flutitude/log.dart';

Map<String, String> parseFeatureProps(Tile_Layer layer, Tile_Feature feature) {
  final props = <String, String>{};
  final tags = feature.tags;
  for (var i = 0; i < tags.length - 1; i += 2) {
    final keyIndex = tags[i];
    final valIndex = tags[i + 1];
    if (keyIndex < layer.keys.length && valIndex < layer.values.length) {
      props[layer.keys[keyIndex]] = layer.values[valIndex].stringValue;
    }
  }
  return props;
}

// 将输入的线段的圈定的矩形范围内的图形裁剪出来
List<List<Offset>> clipLine(List<Offset> line, Rect rect) {
  if (line.length < 2) return [];

  final result = <List<Offset>>[];
  var currentLine = <Offset>[];

  // 检查每个点是否在矩形内
  for (var i = 0; i < line.length - 1; i++) {
    final p1 = line[i];
    final p2 = line[i + 1];

    // if ((p1 - p2).distance < 0.0001) continue;

    if (rect.fullContains(p1) && rect.fullContains(p2)) {
      if (currentLine.isEmpty) {
        currentLine.add(p1);
      }
      currentLine.add(p2);
    } else if (rect.fullContains(p1) && !rect.fullContains(p2)) {
      if (currentLine.isEmpty) {
        currentLine.add(p1);
      }
      final intersections = _findIntersections(p1, p2, rect);

      if (intersections[0] != currentLine.last) {
        logger.i(
            "PathO | p1:${p1.keyString},p2:${p2.keyString},last:${currentLine.last.keyString},inter:${intersections[0].keyString}");
        currentLine.add(intersections[0]);
      }
      result.add(currentLine);
      currentLine = [];
    } else if (!rect.fullContains(p1) && rect.fullContains(p2)) {
      final intersections = _findIntersections(p1, p2, rect);
      if (intersections[0] == p2) {
        currentLine = [intersections[0]];
      } else {
        logger.i(
            "PathI | p1:${p1.keyString},p2:${p2.keyString},inter:${intersections[0].keyString}");
        currentLine = [intersections[0], p2];
      }
    } else {
      final intersections = _findIntersections(p1, p2, rect);
      if (intersections.length > 1) {
        logger.d("intersections:${intersections}");
        result.add([intersections[0], intersections[1]]);
      }
    }
  }

  // 添加最后一段有效线段
  if (currentLine.length > 1) {
    result.add(currentLine);
  }
  return result;
}

// 计算线段与矩形边界的交点
List<Offset> _findIntersections(Offset p1, Offset p2, Rect rect) {
  final intersections = <Offset>[];

  // 矩形四条边的坐标
  final left = rect.left;
  final right = rect.right;
  final top = rect.top;
  final bottom = rect.bottom;

  // 线段方程参数
  final dx = p2.dx - p1.dx;
  final dy = p2.dy - p1.dy;

  // 检查与左边界的交点
  if (dx != 0 &&
      ((p1.dx <= left && p2.dx >= left) || (p1.dx >= left && p2.dx <= left))) {
    final t = (left - p1.dx) / dx;
    final y = p1.dy + t * dy;
    if (y >= top && y <= bottom) {
      intersections.add(Offset(left, y));
    }
  }

  // 检查与右边界的交点
  if (dx != 0 &&
      ((p1.dx <= right && p2.dx >= right) ||
          (p1.dx >= right && p2.dx <= right))) {
    final t = (right - p1.dx) / dx;
    final y = p1.dy + t * dy;
    if (y >= top && y <= bottom) {
      intersections.add(Offset(right, y));
    }
  }

  // 检查与上边界的交点
  if (dy != 0 &&
      ((p1.dy <= top && p2.dy >= top) || (p1.dy >= top && p2.dy <= top))) {
    final t = (top - p1.dy) / dy;
    final x = p1.dx + t * dx;
    if (x >= left && x <= right) {
      intersections.add(Offset(x, top));
    }
  }

  // 检查与下边界的交点
  if (dy != 0 &&
      ((p1.dy <= bottom && p2.dy >= bottom) ||
          (p1.dy >= bottom && p2.dy <= bottom))) {
    final t = (bottom - p1.dy) / dy;
    final x = p1.dx + t * dx;
    if (x >= left && x <= right) {
      intersections.add(Offset(x, bottom));
    }
  }

  return intersections;
}

extension OffsetExt on Offset {
  String get keyString => "(${dx.toStringAsFixed(5)},${dy.toStringAsFixed(5)})";
}

extension RectExt on Rect {
  bool fullContains(Offset offset) {
    return offset.dx >= left &&
        offset.dx <= right &&
        offset.dy >= top &&
        offset.dy <= bottom;
  }
}
