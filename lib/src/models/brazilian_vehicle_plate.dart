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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;

    return other is BrazilianVehiclePlate &&
        other.plate == plate &&
        other.combinationChanges == combinationChanges &&
        other.boundingBox == boundingBox &&
        other.insideRect == insideRect;
  }

  @override
  int get hashCode {
    return plate.hashCode ^
        combinationChanges.hashCode ^
        boundingBox.hashCode ^
        cornerPoints.hashCode ^
        insideRect.hashCode ^
        errorToPlateRect.hashCode;
  }
}
