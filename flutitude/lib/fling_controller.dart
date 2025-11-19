
import 'package:flutter/animation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';

import 'base/location.dart';
import 'map/map_canvas.dart';

class FlingController {
  final MapViewState state;
  final AnimationController _controller;
  final Function(VoidCallback) fn;
  late Velocity? _velocityUnit;
  late Location? _lastLocation;

  FlingController(this.state, TickerProvider vsync, this.fn)
      : _controller =
  AnimationController(vsync: vsync, upperBound: double.infinity);

  void init() {
    _controller.addListener(() {
      final screenZoom = MapViewState.TILE_SIZE * state.zoom();
      final velocity = _velocityUnit!;
      double locationDxPerSecond = velocity.pixelsPerSecond.dx / screenZoom;
      double locationDyPerSecond = velocity.pixelsPerSecond.dy / screenZoom;
      final value = _controller.value;

      fn(() {
        if (value.abs() > 0.1 && _lastLocation != null) {
          state.setCentral(_lastLocation! -
              Location(
                  locationDxPerSecond * value, locationDyPerSecond * value));
        }
      });
    });
  }

  void applyZoomDelta(double delta, Offset zoomViewCenter) {
    state.applyZoomDelta(delta, zoomViewCenter);
  }

  void setCentral(Location central) {
    if (_controller.isAnimating) {
      _controller.reset();
    }
    state.setCentral(central);
  }

  void dispose(){
    _controller.dispose();
  }

  void endWithFling(Velocity velocity) {
    if (velocity.pixelsPerSecond == Offset.zero) return;
    _velocityUnit = velocity.clampMagnitude(1.0, 1.0);
    _lastLocation = state.center;
    final simulation = FrictionSimulation(
      0.01,
      0.0,
      velocity.pixelsPerSecond.distance,
    );
    _controller.animateWith(simulation);
  }
}
