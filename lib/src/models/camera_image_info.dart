import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// TODO(marcosfons): Improve text here
/// This class holds data for the image and the camera sensor orientation
///
/// The major purpose of this class is provide a easy way to handle in and out
/// data with export/from platformData and provide the sensor orientation too
/// that is needed to the mlkit
@immutable
class CameraImageInfo {
  /// The image provided by the `camera` package
  final CameraImage image;

  final CameraDescription cameraDescription;

  final DeviceOrientation deviceOrientation;

  final int uniqueIdentifier;

  const CameraImageInfo({
    required this.image,
    required this.cameraDescription,
    required this.deviceOrientation,
    required this.uniqueIdentifier,
  });
}
