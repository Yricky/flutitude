import 'dart:ui';

import 'package:flutitude/ext/mvt/draw_kit/draw_cache.dart';
import 'package:flutitude/map/layer/map_tiles.dart';

class MvtTile extends MapTile {
  final List<DrawCacheItem> drawCache;

  MvtTile(this.drawCache);

  @override
  void draw(Canvas canvas, Paint paint, Rect rect) {
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width, rect.height);
    // paint
    //   ..strokeWidth = 1 / rect.width
    //   ..strokeCap = StrokeCap.butt
    //   ..style = PaintingStyle.stroke;

    // paint.color = const Color(0xffff0000);
    // canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), paint);
    // paint.color = const Color(0xFF9999ff);

    // int tc = 0;
    // int pc = 0;
    // int lc = 0;
    // int sc = 0;
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
          // tc++;
          break;
        case Points():
          canvas.drawRawPoints(PointMode.points, element.position, paint);
          // pc++;
          break;
        case Lines():
          // canvas.save();
          // canvas.clipRect(const Rect.fromLTWH(0, 0, 1, 1), doAntiAlias: false);
          element.paint.strokeWidth = 1 / rect.width;
          canvas.drawPath(element.path, element.paint);
          // canvas.restore();
          // lc++;
          break;
        case Polygon():
          canvas.drawPath(element.path, element.paint);
          // sc++;
          break;
        default:
      }
    }

    // canvas.save();
    // canvas.scale(1 / rect.width, 1 / rect.height);
    // TextPainter(
    //   text: TextSpan(
    //       text: "tc:$tc, lc:$lc, pc: $pc, sc: $sc",
    //       style: TextStyle(
    //         fontSize: 10,
    //         foreground: Paint()
    //           ..style = PaintingStyle.fill
    //           ..color = const Color(0xffff0000),
    //       )),
    //   textAlign: TextAlign.center,
    //   textDirection: TextDirection.ltr,
    // )
    //   ..layout()
    //   ..paint(canvas, Offset.zero);
    // canvas.restore();

    canvas.restore();
  }
}
