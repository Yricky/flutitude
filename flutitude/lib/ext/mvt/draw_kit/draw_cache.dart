// 绘制缓存，其中的坐标均为瓦片内归一化坐标
import 'dart:typed_data';

import 'package:flutter/painting.dart';

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
  final Paint paint;

  Lines({required this.path, required this.paint});
}

class Polygon extends DrawCacheItem {
  final Path path;
  final Paint paint;

  Polygon({required this.path, required this.paint});
}
