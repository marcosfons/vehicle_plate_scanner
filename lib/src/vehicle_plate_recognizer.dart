import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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

      final List<BrazilianVehiclePlate> brazilianPlates = [];

      for (TextBlock block in recognizedText.blocks) {
        String text = block.text;

        if (text.length == 7 && text.contains('u')) {
          text = text.toUpperCase();
        }

        if (_plateRegex.hasMatch(text)) {
          final boundingBox = Rect.fromLTRB(
            block.boundingBox.left / inputImage.inputImageData!.size.width,
            block.boundingBox.top / inputImage.inputImageData!.size.height,
            block.boundingBox.right / inputImage.inputImageData!.size.width,
            block.boundingBox.bottom / inputImage.inputImageData!.size.height,
          );
          // plates.addAll(plateRegex
          //     .allMatches(text)
          //     .map((match) => match.group(0).toString()));

          // double error = 0;

          // if (plateRect != null) {
          //   // Sum the distance between the two LeftTop points to the error
          //   error += sqrt(pow(plateRect!.left - boundingBox.left, 2) +
          //       pow(plateRect!.top - boundingBox.top, 2));

          //   // Sum the distance between the two RightBottom points to the error
          //   error += sqrt(pow(plateRect!.right - boundingBox.right, 2) +
          //       pow(plateRect!.bottom - boundingBox.bottom, 2));
          // }

          // print('PR: $plateRect     BB: $boundingBox');

          // bool insideRect = plateRect != null &&
          //     plateRect!.contains(Offset(boundingBox.left, boundingBox.top)) &&
          //     plateRect!
          //         .contains(Offset(boundingBox.left, boundingBox.bottom)) &&
          //     plateRect!.contains(Offset(boundingBox.right, boundingBox.top)) &&
          //     plateRect!
          //         .contains(Offset(boundingBox.right, boundingBox.bottom));

          brazilianPlates.addAll(_plateRegex
              .allMatches(text)
              .map((match) => match.group(0).toString())
              .map(
                (plate) => BrazilianVehiclePlate(
                  plate,
                  boundingBox,
                  block.cornerPoints,
                  0,
                  true,
                ),
              ));
        } else if (text.length == 7 && text.contains('O')) {
          final combinations = <String>[];
          combinations.add(text);

          for (int i = 0; i < text.length; i++) {
            final combinationsLength = combinations.length;

            for (int j = 0; j < combinationsLength; j++) {
              if (combinations[j][i] == 'O') {
                final splitted = combinations[j].split('');
                splitted[i] = '0';
                combinations.add(splitted.join());
              }
            }
          }

          final boundingBox = Rect.fromLTRB(
            block.boundingBox.left / inputImage.inputImageData!.size.width,
            block.boundingBox.top / inputImage.inputImageData!.size.height,
            block.boundingBox.right / inputImage.inputImageData!.size.width,
            block.boundingBox.bottom / inputImage.inputImageData!.size.height,
          );

          for (final combination in combinations
              .where((combination) => _newPlateRegex.hasMatch(combination))) {
            brazilianPlates.addAll(_plateRegex
                .allMatches(combination)
                .map((match) => match.group(0).toString())
                .map(
                  (plate) => BrazilianVehiclePlate(
                    plate,
                    boundingBox,
                    block.cornerPoints,
                    0,
                    true,
                  ),
                ));
          }
        }
      }

      brazilianPlates
          .sort((a, b) => a.errorToPlateRect.compareTo(b.errorToPlateRect));

      return brazilianPlates;
    } catch (e, st) {
      print('Error processing input image');
      print(e);
      print(st.toString());
      rethrow;
    }
  }
}
