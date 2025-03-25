import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_playground/base/location.dart';
import 'package:flutter_playground/base/q_tree_key.dart';
import 'package:flutter_playground/map/layer/map_layer.dart';

class MapCanvas extends CustomPainter {
  final MapViewState state;
  final List<MapLayer> layers;
  final Paint _paint = Paint()..filterQuality = FilterQuality.low;

  MapCanvas({super.repaint, required this.state, required this.layers}) {
    _paint.isAntiAlias = true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final viewSize = size;
    state.viewSize = size;

    final topLeft = state.topLeftLocation(viewSize);
    final bottomRight = state.bottomRightLocation(viewSize);

    for (var layer in layers) {
      final depth = state.depth(layer.zoomResolution());
      final tileSize =
          (MapViewState.TILE_SIZE * pow(2, state.zoomLvl - depth)) + 1;

      final topLeftKey = topLeft.toQTreeKey(depth)!;
      final bottomRightKey = bottomRight.toQTreeKey(depth)!;
      QTreeKey.walk(topLeftKey, bottomRightKey).forEach((k) {
        final location = Location.fromQTreeKey(k);
        final pos = state.locationToViewPos(location, viewSize);
        final rect = Rect.fromLTWH(
          pos.dx,
          pos.dy,
          tileSize,
          tileSize,
        );
        final tile = layer.getTile(key: k, state: state);
        if (tile != null) {
          tile.draw(canvas, _paint, rect);
        }
      });
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class MapViewState {
  static const double TILE_SIZE = 256.0;
  Location center;
  double zoomLvl;
  Size viewSize = Size.zero;

  MapViewState({required this.center, required this.zoomLvl});

  double zoom() => pow(2, zoomLvl).toDouble();

  int depth(double zoomRes) => (zoomLvl + zoomRes).floor();

  bool isVisible(int key, double zoomRes) {
    final z = depth(zoomRes);
    if (z != key.depth) return false;
    final topLeft = topLeftLocation(viewSize).toQTreeKey(z)!;
    final bottomRight = bottomRightLocation(viewSize).toQTreeKey(z)!;
    return key.x >= topLeft.x &&
        key.x <= bottomRight.x &&
        key.y >= topLeft.y &&
        key.y <= bottomRight.y;
  }

  void applyZoomDelta(double delta, Offset zoomViewCenter) {
    final zoomCentral = viewPosToLocation(zoomViewCenter, viewSize);
    zoomLvl += log(delta) / ln2;
    zoomLvl = zoomLvl.clamp(1.0, 18.5);

    final tmpPos = viewPosToLocation(zoomViewCenter, viewSize);
    final tmpCentral = viewPosToLocation(
      Offset(viewSize.width / 2, viewSize.height / 2),
      viewSize,
    );
    setCentral(zoomCentral + tmpCentral - tmpPos);
  }

  void setCentral(Location central) {
    center = central.wrap();
  }

  Location viewPosToLocation(Offset pos, Size viewSize) {
    final z = zoom();
    final dx = (pos.dx - viewSize.width / 2) / (TILE_SIZE * z);
    final dy = (pos.dy - viewSize.height / 2) / (TILE_SIZE * z);
    return Location(center.x + dx, center.y + dy);
  }

  Offset locationToViewPos(Location location, Size viewSize) {
    final z = zoom();
    final dx = (location.x - center.x) * TILE_SIZE * z + viewSize.width / 2;
    final dy = (location.y - center.y) * TILE_SIZE * z + viewSize.height / 2;
    return Offset(dx, dy);
  }

  Location topLeftLocation(Size viewSize) =>
      viewPosToLocation(Offset.zero, viewSize).wrap();

  Location bottomRightLocation(Size viewSize) =>
      viewPosToLocation(Offset(viewSize.width, viewSize.height), viewSize)
          .wrap();
}

class MapView extends StatelessWidget {
  final MapViewState state;
  final List<MapLayer> layers;
  const MapView({super.key, required this.state, required this.layers});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: MapCanvas(state: state, layers: layers),
    );
  }
}
