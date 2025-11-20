import 'package:flutitude/base/q_tree_key.dart';
import 'package:flutitude/base/wcs.dart';
import 'package:flutitude/fling_controller.dart';
import 'package:flutitude/map/layer/map_tiles.dart';
import 'package:flutitude/map_widget.dart';
import 'package:flutitude_app/bing.dart';
import 'package:flutter/material.dart';
import 'package:flutitude/base/location.dart';
import 'package:flutitude/map/map_canvas.dart';
import 'package:flutitude/map/layer/map_layer.dart';

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

class _MyHomePageState extends State<MyHomePage> {
  final FlingController flingController = FlingController(MapViewState(
    center: const Location(0.5, 0.5),
    zoomLvl: 1.5,
  ));

  final BingLayers bingLayers = BingLayers(0);

  final List<MapLayer> layers = [
    FallbackLayer(
        AsyncMapLayer(
            urlAndCacheImageTileLiader(
                (key) {
                  return "https://gwxc.shipxy.com/tile.g?z=${key.depth}&x=${key.x}&y=${key.y}";
                },
                null,
                (key) {
                  return "${key.depth}_${key.x}_${key.y}.png";
                }),
            0.4), (int k) {
      return SolidTile(Color.fromRGBO(
        (k.depth * 8) % 256,
        (255 - k.depth * 8) % 256,
        ((k.x + k.y) % 2 == 0) ? k.depth % 256 : (255 - k.depth) % 256,
        1.0,
      )) as MapTile;
    }),
  ];
  final WCS wcs = const WebMercator();

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
    for (var element in layers) {
      element.getTileChangeStream().listen((event) {
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          Positioned.fill(
              child: MapWidget(controller: flingController, layers: layers)),
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.white.withAlpha(200),
              child: Text(
                  "${flingController.state.center.x},${flingController.state.center.y}\n${wcs.toLatLng(flingController.state.center)}"),
            ),
          ),
        ],
      ),
    );
  }
}
