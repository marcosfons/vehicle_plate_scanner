import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// TODO(marcosfons): Improve text here
/// This class holds data for the image and the camera sensor orientation
///
/// The major purpose of this class is provide a easy way to handle in and out
/// data with export/from platformData and provide the sensor orientation too
/// that is needed to the mlkit
class CameraImageInfo {
  /// The image provided by the `camera` package
  late final CameraImage image;

  /// The sensor orientation of the camera
  late final int cameraSensorOrientation;

  CameraImageInfo({
    required this.image,
    required this.cameraSensorOrientation,
  });

  CameraImageInfo.fromPlatformData(Map<String, dynamic> platformData) {
    cameraSensorOrientation = platformData['sensorOrientation'];

    // TODO(marcosfons): Find a way to use fromPlatformInterface instead
    image = CameraImage.fromPlatformData(platformData);
  }

  /// Transform this image instance to an `InputImage` from the `google_ml_kit` package
  Future<InputImage> toInputImage() async {
    final allBytes = WriteBuffer();

    for (var plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());

    final imageRotation =
        InputImageRotationValue.fromRawValue(cameraSensorOrientation) ??
            InputImageRotation.rotation0deg;

    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;

    final planeData = image.planes.map(
      (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );

    return InputImage.fromBytes(
      bytes: bytes,
      inputImageData: inputImageData,
    );
  }

  Map<String, dynamic> exportToPlatformData() {
    final data = <String, dynamic>{
      'sensorOrientation': cameraSensorOrientation,
      'format': image.format.raw,
      'width': image.width,
      'height': image.height,
      'lensAperture': image.lensAperture,
      'sensorExposureTime': image.sensorExposureTime,
      'sensorSensitivity': image.sensorSensitivity,
      'planes': image.planes
          .map((Plane p) => <dynamic, dynamic>{
                'bytes': p.bytes,
                'bytesPerPixel': p.bytesPerPixel,
                'bytesPerRow': p.bytesPerRow,
                'height': p.height,
                'width': p.width
              })
          .toList()
    };

    return data;
  }
}
