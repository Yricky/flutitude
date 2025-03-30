import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_playground/base/location.dart';
import 'package:flutter_playground/ext/mvt/parse_kit/bing.dart';
import 'package:flutter_playground/map/map_canvas.dart';
import 'package:flutter_playground/map/layer/map_layer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Map Demo page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  final MapViewState state = MapViewState(
    center: const Location(0.5, 0.5),
    zoomLvl: 1.5,
  );

  final BingLayers bingLayers = BingLayers(0);

  final List<MapLayer> layers = [
    // FallbackLayer(
    //     AsyncMapLayer(
    //         urlAndCacheImageTileLiader(
    //             (key) {
    //               return "https://gwxc.shipxy.com/tile.g?z=${key.depth}&x=${key.x}&y=${key.y}";
    //             },
    //             "tiles/img",
    //             (key) {
    //               return "${key.depth}_${key.x}_${key.y}.png";
    //             }),
    //         0.4), (int k) {
    //   return SolidTile(Color.fromRGBO(
    //     (k.depth * 8) % 256,
    //     (255 - k.depth * 8) % 256,
    //     ((k.x + k.y) % 2 == 0) ? k.depth % 256 : (255 - k.depth) % 256,
    //     1.0,
    //   )) as MapTile;
    // }),
  ];

  late FlingController flingController;

  @override
  void initState() {
    super.initState();
    flingController = FlingController(state, this, setState);
    flingController.init();
  }

  @override
  void dispose() {
    flingController._controller.dispose();
    super.dispose();
  }

  double? zoom;

  _MyHomePageState() {
    layers.add(BingMapLayer(bingLayers, (s) {
      return s?.backgroundTile;
    }));
    layers.add(BingMapLayer(bingLayers, (s) {
      return s?.roadTile;
    }));
    layers.add(BingMapLayer(bingLayers, (s) {
      return s?.textTile;
    }));
    bingLayers.getTileChangeStream().listen((event) {
      setState(() {});
    });
    // for (var layer in layers) {
    //   layer.getTileChangeStream().listen((event) {
    //     setState(() {
    //       // print("update:${event.keyString()}");
    //     });
    //   });
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                child: GestureDetector(
                    onScaleUpdate: (details) {
                      setState(() {
                        final screenZoom =
                            MapViewState.TILE_SIZE * state.zoom();
                        flingController.setCentral(state.center -
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
                      painter: MapCanvas(state: state, layers: layers),
                    )))
          ],
        ),
      ),
    );
  }
}

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
    // _controller.fling();
  }
}
