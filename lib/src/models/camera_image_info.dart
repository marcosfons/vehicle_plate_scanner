import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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

  /// The sensor orientation of the camera
  final int cameraSensorOrientation;

  final int orientation;

  final CameraLensDirection lensDirection;

  final int uniqueIdentifier;

  const CameraImageInfo({
    required this.image,
    required this.cameraSensorOrientation,
    required this.orientation,
    required this.lensDirection,
    required this.uniqueIdentifier,
  });

  Future<InputImage> toInputImage() async {
    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(cameraSensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = orientation;
      if (lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation =
            (cameraSensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (cameraSensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) throw Exception('Not found rotation');

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      throw Exception('Invalid format');
    }

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) {
      throw Exception('Wrong number of planes for image');
    }
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  /// Transform this image instance to an `InputImage` from the `google_ml_kit` package
  // Future<InputImage> toInputImage() async {
  //   final allBytes = WriteBuffer();

  //   for (final plane in image.planes) {
  //     allBytes.putUint8List(plane.bytes);
  //   }
  //   final bytes = allBytes.done().buffer.asUint8List();

  //   final imageSize = Size(image.width.toDouble(), image.height.toDouble());

  //   // TODO(marcosfons): Need to handle correctly the device rotation
  //   final imageRotation =
  //       InputImageRotationValue.fromRawValue(cameraSensorOrientation) ??
  //           InputImageRotation.rotation0deg;

  //   final inputImageFormat =
  //       InputImageFormatValue.fromRawValue(image.format.raw) ??
  //           InputImageFormat.nv21;

  //   final planeData = image.planes.map(
  //     (Plane plane) {
  //       return InputImagePlaneMetadata(
  //         bytesPerRow: plane.bytesPerRow,
  //         height: plane.height,
  //         width: plane.width,
  //       );
  //     },
  //   ).toList();

  //   final inputImageData = InputImageData(
  //     size: imageSize,
  //     imageRotation: imageRotation,
  //     // inputImageFormat: InputImageFormat.yuv420,
  //     inputImageFormat: inputImageFormat,
  //     planeData: planeData,
  //   );

  //   return InputImage.fromBytes(
  //     bytes: bytes,
  //     inputImageData: inputImageData,
  //   );
  // }
}
