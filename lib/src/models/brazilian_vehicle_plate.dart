import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class BrazilianVehiclePlate {
  final String plate;
  final Rect boundingBox;
  final List<Point<int>> cornerPoints;

  const BrazilianVehiclePlate(
    this.plate,
    this.boundingBox,
    this.cornerPoints,
  );
}
