

import 'package:flutter/widgets.dart';

import 'base/location.dart';
import 'fling_controller.dart';
import 'map/layer/map_layer.dart';
import 'map/map_canvas.dart';

class MapWidget extends StatefulWidget{
  final MapViewState state;
  final List<MapLayer> layers;

  const MapWidget({super.key, required this.state, required this.layers});


  @override
  State<StatefulWidget> createState() {
    return _MapWidgetState();
  }
}

class _MapWidgetState extends State<MapWidget> with TickerProviderStateMixin{
  late FlingController flingController;
  double? zoom;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return GestureDetector(
        onScaleUpdate: (details) {
          setState(() {
            final screenZoom =
                MapViewState.TILE_SIZE * widget.state.zoom();
            flingController.setCentral(widget.state.center -
                Location(details.focalPointDelta.dx / screenZoom,
                    details.focalPointDelta.dy / screenZoom));
            if (zoom != null) {
              final delta = details.scale / zoom!;
              flingController.applyZoomDelta(
                  delta, details.localFocalPoint);
            }
            zoom = details.scale;
          });
        },
        onScaleEnd: (details) {
          flingController.endWithFling(details.velocity);
          zoom = null;
        },
        child: CustomPaint(
          painter: MapCanvas(state: widget.state, layers: widget.layers),
        ));
  }


  @override
  void initState() {
    super.initState();
    flingController = FlingController(widget.state, this, setState);
    flingController.init();
  }

  @override
  void dispose() {
    flingController.dispose();
    super.dispose();
  }
}