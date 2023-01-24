import 'package:flutter/foundation.dart';
import 'package:vehicle_plate_scanner/vehicle_plate_scanner.dart';

@immutable
class BrazilianVehiclePlatesResult {
  /// An identifier of this result based on the [CameraImage] used to produce it.
  ///
  /// Is the hashcode from the image passed as parameter
  final int id;

  /// The plates found in the image, and some combinations that can be too.
  final List<BrazilianVehiclePlate> plates;

  const BrazilianVehiclePlatesResult(this.id, this.plates);
}
