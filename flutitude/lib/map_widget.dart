import 'package:flutter/widgets.dart';

import 'base/location.dart';
import 'fling_controller.dart';
import 'map/layer/map_layer.dart';
import 'map/map_canvas.dart';

class MapWidget extends StatefulWidget {
  final FlingController controller;
  final List<MapLayer> layers;

  const MapWidget({super.key, required this.controller, required this.layers});

  @override
  State<StatefulWidget> createState() {
    return _MapWidgetState();
  }
}

class _MapWidgetState extends State<MapWidget> with TickerProviderStateMixin {
  late FlingController flingController;
  double? zoom;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleUpdate: (details) {
        final screenZoom =
            MapViewState.TILE_SIZE * widget.controller.state.zoom();
        flingController.setCentral(
          widget.controller.state.center -
              Location(
                details.focalPointDelta.dx / screenZoom,
                details.focalPointDelta.dy / screenZoom,
              ),
        );
        if (zoom != null) {
          final delta = details.scale / zoom!;
          flingController.applyZoomDelta(delta, details.localFocalPoint);
        }
        zoom = details.scale;
      },
      onScaleEnd: (details) {
        flingController.endWithFling(details.velocity);
        zoom = null;
      },
      child: StreamBuilder<void>(
        stream: flingController.repaintStream,
        builder: (context, snapshot) {
          return CustomPaint(
            painter: MapCanvas(
              state: widget.controller.state,
              layers: widget.layers,
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    flingController = widget.controller;
    flingController.init(this, setState);
  }

  @override
  void dispose() {
    flingController.dispose();
    super.dispose();
  }
}
