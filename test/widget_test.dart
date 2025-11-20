// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutitude/base/location.dart';
import 'package:flutitude/base/q_tree_key.dart';
import 'package:flutitude/map/layer/map_layer.dart';
import 'package:flutitude/map/layer/map_tiles.dart';
import 'package:flutitude/map/map_canvas.dart';
import 'package:flutitude/map_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // runApp(const MyApp());
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // // Verify that our counter starts at 0.
    // expect(find.text('0'), findsOneWidget);
    // expect(find.text('1'), findsNothing);
    //
    // // Tap the '+' icon and trigger a frame.
    // await tester.tap(find.byIcon(Icons.add));
    // await tester.pump();
    //
    // // Verify that our counter has incremented.
    // expect(find.text('0'), findsNothing);
    // expect(find.text('1'), findsOneWidget);
  });
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
  final MapViewState state = MapViewState(
    center: const Location(0.5, 0.5),
    zoomLvl: 1.5,
  );

  // final BingLayers bingLayers = BingLayers(0);

  final List<MapLayer> layers = [
    FallbackLayer(
        AsyncMapLayer(
            urlAndCacheImageTileLiader(
                (key) {
                  return "https://gwxc.shipxy.com/tile.g?z=${key.depth}&x=${key.x}&y=${key.y}";
                },
                "tiles/img",
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

  double? zoom;

  _MyHomePageState() {
    // layers.add(BingMapLayer(bingLayers, (s) {
    //   return s?.backgroundTile;
    // }));
    // layers.add(BingMapLayer(bingLayers, (s) {
    //   return s?.roadTile;
    // }));
    // layers.add(BingMapLayer(bingLayers, (s) {
    //   return s?.textTile;
    // }));
    // bingLayers.getTileChangeStream().listen((event) {
    //   setState(() {});
    // });
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
            // Expanded(
            //     child:MapWidget(state: state, layers: layers)
            // )
          ],
        ),
      ),
    );
  }
}

