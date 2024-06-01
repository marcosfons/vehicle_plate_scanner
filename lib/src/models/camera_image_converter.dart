import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logger/logger.dart';

class CameraImageConverter {
  static const _cameraOrientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  static const _supportedAndroidFormats = {
    InputImageFormat.nv21,
    InputImageFormat.yuv_420_888
  };

  final log = Logger(level: Level.info);

  Uint8List? _imageForYUVToNV21Conversion;
  int? _imageLengthForYUVToNV21Conversion;

  InputImageRotation? _getInputImageRotation(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _cameraOrientations[deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    return rotation;
  }

  Future<InputImage?> inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) async {
    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas

    InputImageRotation? rotation =
        _getInputImageRotation(camera, deviceOrientation);
    if (rotation == null) return null;

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && !_supportedAndroidFormats.contains(format)) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    // since format is constraint to nv21 or bgra8888, both only have one plane
    // if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: format == InputImageFormat.yuv_420_888
          ? _yuv420ThreePlanesToNV21(image.planes, image.width, image.height)
          : plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  Uint8List _yuv420ThreePlanesToNV21(
    List<Plane> yuv420888planes,
    int width,
    int height,
  ) {
    final int imageSize = width * height;

    final Stopwatch clock = Stopwatch()..start();
    final newImageLength = imageSize + 2 * (imageSize ~/ 4);
    if (_imageForYUVToNV21Conversion == null ||
        _imageLengthForYUVToNV21Conversion != newImageLength) {
      log.d(
          'Allocating new Uint8List for scanner. Old size: ${_imageLengthForYUVToNV21Conversion ?? 0}, New size: $newImageLength');
      _imageForYUVToNV21Conversion = Uint8List(newImageLength);
      _imageLengthForYUVToNV21Conversion = newImageLength;
      log.d('Time elapsed to allocate: ${clock.elapsedMilliseconds}ms');
      clock.reset();
    }

    if (_areUVPlanesNV21(yuv420888planes, width, height)) {
      // Copy the Y values.
      _imageForYUVToNV21Conversion!
          .setRange(0, imageSize, yuv420888planes[0].bytes);

      final Uint8List uBuffer = yuv420888planes[1].bytes;
      final Uint8List vBuffer = yuv420888planes[2].bytes;

      // Get the first V value from the V buffer, since the U buffer does not contain it.
      // vBuffer.get(out, imageSize, 1);
      _imageForYUVToNV21Conversion!.setRange(imageSize, imageSize + 1, vBuffer);
      // Copy the first U value and the remaining VU values from the U buffer.
      _imageForYUVToNV21Conversion!
          .setRange(imageSize + 1, imageSize + 1 + uBuffer.length, uBuffer);
      log.d(
          'Time elapsed to set values for NV21: ${clock.elapsedMilliseconds}ms');
    } else {
      log.d(
          'Fallback to copying the UV values one by one, which is slower but also works.');
      // Unpack Y.
      _unpackPlane(yuv420888planes[0], width, height,
          _imageForYUVToNV21Conversion!, 0, 1);
      // Unpack U.
      _unpackPlane(yuv420888planes[1], width, height,
          _imageForYUVToNV21Conversion!, imageSize + 1, 2);
      // Unpack V.
      _unpackPlane(yuv420888planes[2], width, height,
          _imageForYUVToNV21Conversion!, imageSize, 2);
      log.d('Time elapsed to unpack: ${clock.elapsedMilliseconds}ms');
    }

    return _imageForYUVToNV21Conversion!;
  }

  bool _areUVPlanesNV21(List<Plane> planes, int width, int height) {
    final int imageSize = width * height;

    final Uint8List uBuffer = planes[1].bytes;
    final Uint8List vBuffer = planes[2].bytes;

    final Uint8List vBufferShifted = Uint8List.sublistView(vBuffer, 1);

    int vBufferShiftedSize = vBufferShifted.length;

    // Check that the buffers are equal and have the expected number of elements.
    final bool areNV21 = (vBufferShiftedSize == (2 * imageSize ~/ 4 - 2)) &&
        (_compareTwoBuffers(
            vBufferShifted, uBuffer, planes[0].bytesPerRow * 2));

    return areNV21;
  }

  bool _compareTwoBuffers(
    Uint8List buffer1,
    Uint8List buffer2,
    int lengthToCompare,
  ) {
    for (int i = 0; i < lengthToCompare; i++) {
      if (buffer1[i] != buffer2[i]) {
        return false;
      }
    }
    return true;
  }

  void _unpackPlane(
    Plane plane,
    int width,
    int height,
    Uint8List out,
    int offset,
    int pixelStride,
  ) {
    Uint8List buffer = plane.bytes;

    final int rowStride = (plane.bytesPerRow);
    // Compute the size of the current plane.
    // We assume that it has the aspect ratio as the original image.
    int numRow = (buffer.length + rowStride - 1) ~/ rowStride;
    if (numRow == 0) {
      return;
    }
    int scaleFactor = height ~/ numRow;
    int numCol = width ~/ scaleFactor;

    // Extract the data in the output buffer.
    int outputPos = offset;
    int rowStart = 0;
    for (int row = 0; row < numRow; row++) {
      int inputPos = rowStart;
      for (int col = 0; col < numCol; col++) {
        out[outputPos] = buffer[inputPos];
        outputPos += pixelStride;
        inputPos += pixelStride;
      }
      rowStart += rowStride;
    }
  }
}
