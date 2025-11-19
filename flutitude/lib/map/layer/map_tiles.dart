import 'dart:ui';

abstract class MapTile {
  void draw(Canvas canvas, Paint paint, Rect rect);
}

class ImageMapTile implements MapTile {
  final Image image;
  final Rect _imgRect;
  ImageMapTile(this.image)
      : _imgRect = Rect.fromLTWH(
            0, 0, image.width.toDouble(), image.height.toDouble());
  @override
  void draw(Canvas canvas, Paint paint, Rect rect) {
    canvas.drawImageRect(image, _imgRect, rect, paint);
  }
}

class SolidTile implements MapTile {
  final Color color;
  SolidTile(this.color);
  @override
  void draw(Canvas canvas, Paint paint, Rect rect) {
    canvas.drawRect(rect, paint..color = color);
  }
}
