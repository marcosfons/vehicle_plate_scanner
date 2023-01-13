import 'dart:async';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:vehicle_plate_scanner/src/models/brazilian_vehicle_plate.dart';
import 'package:vehicle_plate_scanner/src/models/camera_image_info.dart';

class VehiclePlateRecognizer {
  final Rect firstPlateRect;

  late final Isolate _isolate;
  late final ReceivePort _receivePort;

  final _runningReceivePort = Completer<SendPort>();
  final _controller = StreamController<List<BrazilianVehiclePlate>>();
  late final _streamIterator = StreamIterator(_controller.stream);

  VehiclePlateRecognizer(this.firstPlateRect);

  Future<void> init() async {
    _receivePort = ReceivePort();

    _receivePort.listen(_handleData);

    _isolate = await Isolate.spawn(
      _VehiclePlateRecognizerBackground._run,
      _receivePort.sendPort,
    );

    await _runningReceivePort.future;
  }

  Future<List<BrazilianVehiclePlate>> processImage(
    CameraImageInfo cameraImageInfo,
  ) async {
    if (!_runningReceivePort.isCompleted) {
      throw Exception(
          'PlateRecognizer not initialized correctly.\nCall init() first.');
    }

    final port = await _runningReceivePort.future;

    port.send(cameraImageInfo);

    // TODO(marcosfons): Add better handling here.
    // In the future, multiple images could be sended at the same time
    // Here it should check for an id, or something like that by using `takeWhile`
    final hasSomeValue = await _streamIterator.moveNext();

    return hasSomeValue ? _streamIterator.current : [];
  }

  void _handleData(dynamic data) {
    if (data is List<BrazilianVehiclePlate>) {
      _controller.add(data);
    } else if (data is SendPort) {
      final rootIsolateToken = RootIsolateToken.instance!;
      data.send(rootIsolateToken);
      // data.send(firstPlateRect);
      _runningReceivePort.complete(data);
    }
  }

  void changePlateRect(Rect newRect) async {
    final port = await _runningReceivePort.future;
    port.send(newRect);
  }

  Future<void> dispose() async {
    _receivePort.close();
    _controller.close();
    _isolate.kill();
  }
}

/// The portion of the [VehiclePlateRecognizer] that runs on the background isolate.
///
/// This is where we use the new feature Background Isolate Channels, which
/// allows us to use plugins from background isolates.
class _VehiclePlateRecognizerBackground {
  _VehiclePlateRecognizerBackground(this._sendPort);

  Rect? plateRect;

  static final _plateRegex =
      RegExp(r'([A-Z]{3}[0-9][0-9A-Z][0-9]{2})|([A-Z]{3}.[0-9]{4})');

  static final _newPlateRegex = RegExp(r'([A-Z]{3}[0-9][0-9A-Z][0-9]{2})');

  final SendPort _sendPort;

  late final textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Initialization logic of this background isolate.
  /// This is the entrypoint for the background isolate sent to [Isolate.spawn].
  static void _run(SendPort sendPort) {
    final receivePort = ReceivePort();

    sendPort.send(receivePort.sendPort);
    final backgroundInstance = _VehiclePlateRecognizerBackground(sendPort);

    receivePort.listen(
      backgroundInstance._handleCommand,
      onDone: backgroundInstance.dispose,
    );
  }

  /// Handle the [data] received from the [ReceivePort].
  Future<void> _handleCommand(dynamic data) async {
    if (data is RootIsolateToken) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(data);
    } else if (data is CameraImageInfo) {
      final inputImage = await data.toInputImage();

      final plates = await _processPlatesFromInputImage(
        inputImage,
        textRecognizer,
      );

      // if (plates.isNotEmpty) {
      //   print('Converting image to PNG');
      //   final stopwatch = Stopwatch();
      //   try {
      //     stopwatch.start();
      //     final myImage =
      //         convertImageWithVehiclePlate(data.image, plates.first);
      //     print(
      //         'ELAPSED: ${stopwatch.elapsedMilliseconds}  -   ${stopwatch.elapsed} ');

      //     print(myImage != null);
      //     print(myImage?.length);
      //     print(myImage?.lengthInBytes);
      //   } catch (e, st) {
      //     print(
      //         'ELAPSED: ${stopwatch.elapsedMilliseconds}  -   ${stopwatch.elapsed} ');
      //     print('Deu algum erro ao sla o q');

      //     print(e.toString());
      //     print(st.toString());
      //   }
      // }

      _sendPort.send(plates);
    } else if (data is Rect) {
      plateRect = data;
    }
  }

  /// Release the resources used in this isolate.
  Future<void> dispose() async {
    print('Finishing background VehiclePlateRecognizer isolate');
    await textRecognizer.close();
  }

  Future<List<BrazilianVehiclePlate>> _processPlatesFromInputImage(
    InputImage inputImage,
    TextRecognizer textRecognizer,
  ) async {
    try {
      final recognizedText = await textRecognizer.processImage(inputImage);

      final brazilianPlates = <BrazilianVehiclePlate>[];

      // const oldMappings = {
      //   '0': ['O', 'D', 'Q'],
      //   'D': ['0', 'O', 'Q'],
      //   'O': ['0', 'D', 'Q'],
      //   'Q': ['0', 'D', 'O'],
      // };

      const mappings = {
        '0': ['O', 'D', 'Q'],
        'D': ['0', 'O', 'Q'],
        'O': ['0', 'D', 'Q'],
        'Q': ['0', 'D', 'O'],
        '1': ['L', 'I'],
        'L': ['1', 'I'],
        'I': ['L', '1'],
      };

      for (TextBlock block in recognizedText.blocks) {
        String text = block.text.toUpperCase();

        final boundingBox = Rect.fromLTRB(
          block.boundingBox.left / inputImage.inputImageData!.size.width,
          block.boundingBox.top / inputImage.inputImageData!.size.height,
          block.boundingBox.right / inputImage.inputImageData!.size.width,
          block.boundingBox.bottom / inputImage.inputImageData!.size.height,
        );

        if (_plateRegex.hasMatch(text)) {
          brazilianPlates.addAll(_plateRegex
              .allMatches(text)
              .map((match) => match.group(0).toString())
              .map(
                (plate) => BrazilianVehiclePlate(
                    plate, 0, boundingBox, block.cornerPoints, 0, true),
              ));
        }

        if (text.length == 7 || text.length == 8) {
          final newCombinations = _mappings(text, mappings)
              .where((combination) => _plateRegex.hasMatch(combination.text));

          for (final combination in newCombinations) {
            brazilianPlates.addAll(_plateRegex
                .allMatches(combination.text)
                .map((match) => match.group(0).toString())
                .map(
                  (plate) => BrazilianVehiclePlate(
                    plate,
                    combination.changes,
                    boundingBox,
                    block.cornerPoints,
                    0,
                    true,
                  ),
                ));
          }
        }
      }

      // brazilianPlates
      //     .sort((a, b) => a.errorToPlateRect.compareTo(b.errorToPlateRect));
      brazilianPlates
          .sort((a, b) => a.combinationChanges.compareTo(b.combinationChanges));

      return brazilianPlates;
    } catch (e, st) {
      print('Error processing input image');
      print(e);
      print(st.toString());
      rethrow;
    }
  }

  List<_Combination> _mappings(
    String text,
    Map<String, List<String>> mappings,
  ) {
    final combinations = [
      _Combination(text, 0),
    ];

    for (int i = 0; i < text.length; i++) {
      final combinationsLength = combinations.length;

      for (int j = 0; j < combinationsLength; j++) {
        final mapping = mappings[combinations[j].text[i]];

        if (mapping != null) {
          final currentCombination = combinations[j];
          final splitted = currentCombination.text.split('');

          for (final letter in mapping) {
            splitted[i] = letter;
            combinations.add(
              _Combination(
                splitted.join(),
                currentCombination.changes + 1,
              ),
            );
          }
        }
      }
    }

    return combinations;
  }
}

class _Combination {
  final String text;
  final int changes;

  const _Combination(this.text, this.changes);

  @override
  bool operator ==(o) =>
      o is _Combination && text == o.text && changes == o.changes;

  @override
  int get hashCode => text.hashCode ^ changes.hashCode;
}

Uint8List? convertImageWithVehiclePlate(
  CameraImage image,
  BrazilianVehiclePlate vehiclePlate,
) {
  try {
    final stopwatch = Stopwatch()..start();
    img.Image convertedImage = convertYUV420ToImage(image);
    stopwatch.stop();
    print('ELAPSED CONVERTING YUV420: ${stopwatch.elapsedMilliseconds}');
    stopwatch.reset();

    stopwatch.start();
    int previousIndex = vehiclePlate.cornerPoints.length - 1;
    for (int i = 0; i < vehiclePlate.cornerPoints.length; i++) {
      convertedImage = img.drawLine(
        convertedImage,
        x1: convertedImage.width - vehiclePlate.cornerPoints[i].y,
        x2: convertedImage.width - vehiclePlate.cornerPoints[previousIndex].y,
        y1: vehiclePlate.cornerPoints[i].x,
        y2: vehiclePlate.cornerPoints[previousIndex].x,
        color: img.ColorInt8.rgb(110, 0, 0),
        thickness: 5,
      );

      previousIndex = i;
    }

    stopwatch.stop();
    print('ELAPSED DRAWING: ${stopwatch.elapsedMilliseconds}');
    stopwatch.reset();

    if (convertedImage.width > 800) {
      stopwatch.start();
      print('LAST WIDTH ${convertedImage.width}');
      convertedImage = img.copyResize(convertedImage, width: 800);
      stopwatch.stop();
      print('ELAPSED RESIZING: ${stopwatch.elapsedMilliseconds}');
      stopwatch.reset();
    }

    stopwatch.start();
    final bytes = img.encodeJpg(convertedImage);
    stopwatch.stop();
    print('ELAPSED CONVERTING PNG: ${stopwatch.elapsedMilliseconds}');

    return bytes;
  } catch (e, st) {
    print(
        'An error has occurred while converting cameraimage with vehicle plate');
    print(e.toString());
    print(st.toString());
    return null;
  }
}

Uint8List? convertImagetoPng(CameraImage image) {
  assert(image.format.group == ImageFormatGroup.yuv420);
  try {
    final stopwatch = Stopwatch()..start();
    img.Image convertedImage = convertYUV420ToImage(image);
    print('ELAPSED CONVERTING: ${stopwatch.elapsedMilliseconds}');

    if (convertedImage.width > 1024) {
      convertedImage = img.copyResize(convertedImage, width: 1024);
    }

    final stopwatch2 = Stopwatch()..start();
    final bytes = img.encodePng(convertedImage);
    print('ELAPSED CONVERTING2: ${stopwatch2.elapsedMilliseconds}');
    return bytes;
  } catch (e) {
    rethrow;
  }
}

const shift = (0xFF << 24);
img.Image convertYUV420ToImage(CameraImage image) {
  assert(image.planes[1].bytesPerPixel != null);

  final int width = image.width;
  final int height = image.height;
  final int uvRowStride = image.planes[1].bytesPerRow;
  final int uvPixelStride = image.planes[1].bytesPerPixel!;

  print("uvRowStride: $uvRowStride");
  print("uvPixelStride: $uvPixelStride");

  // imgLib -> Image package from https://pub.dartlang.org/packages/image
  final newImage =
      img.Image(width: height, height: width); // Create Image buffer

  // Fill image buffer with plane[0] from YUV420_888
  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      final int uvIndex =
          uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
      final int index = y * width + x;

      final yp = image.planes[0].bytes[index];
      final up = image.planes[1].bytes[uvIndex];
      final vp = image.planes[2].bytes[uvIndex];
      // Calculate pixel color
      int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
      int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
          .round()
          .clamp(0, 255);
      int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
      // color: 0x FF  FF  FF  FF
      //           A   B   G   R
      newImage.setPixelRgb(height - y - 1, x, r, g, b);
    }
  }

  return newImage;
}
