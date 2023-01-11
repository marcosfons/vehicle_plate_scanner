import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class BrazilianVehiclePlate {
  final String plate;

  /// The amount of changes that was necessary to create this plate combination
  ///
  /// If the reader could correctly read the plate this is equals to 0
  final int combinationChanges;

  final Rect boundingBox;
  final List<Point<int>> cornerPoints;

  final double errorToPlateRect;
  final bool insideRect;

  const BrazilianVehiclePlate(
    this.plate,
    this.combinationChanges,
    this.boundingBox,
    this.cornerPoints,
    this.errorToPlateRect,
    this.insideRect,
  );
}
