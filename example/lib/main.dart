import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vehicle_plate_scanner/vehicle_plate_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle plate scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxSide = max(mediaQuery.size.width, mediaQuery.size.height);
    final size = Size(mediaQuery.size.width / mediaQuery.size.width,
        mediaQuery.size.height / mediaQuery.size.height);

    const aspectRatio = 40 / 13;

    final cutRect = Rect.fromCenter(
      center: size.center(const Offset(0, 0)),
      width: size.width - 0.1,
      height: size.width / aspectRatio,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle plate scanner'),
        actions: const [],
      ),
      body: Stack(
        children: [
          VehiclePlateScannerPreview(
            onVehiclePlates: (plates) {
              if (plates.isNotEmpty) {
                print(plates
                    .map((plate) =>
                        '${plate.plate}: ${plate.combinationChanges}')
                    .join(',   '));
                print('');
              }
            },
            plateRect: cutRect,
          ),
        ],
      ),
    );
  }
}
