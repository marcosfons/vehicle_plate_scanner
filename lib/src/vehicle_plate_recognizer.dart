import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:vehicle_plate_scanner/src/models/brazilian_vehicle_plate.dart';
import 'package:vehicle_plate_scanner/src/models/brazilian_vehicle_plates_result.dart';
import 'package:vehicle_plate_scanner/src/models/camera_image_converter.dart';
import 'package:vehicle_plate_scanner/src/models/camera_image_info.dart';
import 'package:vehicle_plate_scanner/src/models/camera_image_path_info.dart';

class VehiclePlateRecognizer {
  late final Isolate _isolate;
  late final ReceivePort _receivePort;

  final _runningReceivePort = Completer<SendPort>();
  final _controller =
      StreamController<BrazilianVehiclePlatesResult>.broadcast();

  Stream<BrazilianVehiclePlatesResult> get outVehiclePlatesStream =>
      _controller.stream;

  Future<void> init() async {
    _receivePort = ReceivePort();

    _receivePort.listen(_handleData);

    _isolate = await Isolate.spawn(
      _VehiclePlateRecognizerBackground._run,
      _receivePort.sendPort,
      onError: _receivePort.sendPort,
    );

    await _runningReceivePort.future;
  }

  Future<BrazilianVehiclePlatesResult> processImage(
    CameraImageInfo cameraImageInfo,
  ) async {
    if (!_runningReceivePort.isCompleted) {
      throw Exception(
          'PlateRecognizer not initialized correctly.\nCall init() first.');
    }

    final port = await _runningReceivePort.future;

    port.send(cameraImageInfo);

    // Will wait for 50 events until cancel the listen
    int counter = 50;

    await for (final result in _controller.stream) {
      if (result.id == cameraImageInfo.uniqueIdentifier) {
        return result;
      } else if (counter == 0) {
        break;
      }

      counter--;
    }

    return BrazilianVehiclePlatesResult(
      cameraImageInfo.uniqueIdentifier,
      const [],
    );
  }

  Future<BrazilianVehiclePlatesResult> processImageFromFilePath(
    String imagePath,
  ) async {
    if (!_runningReceivePort.isCompleted) {
      throw Exception(
          'PlateRecognizer not initialized correctly.\nCall init() first.');
    }

    final port = await _runningReceivePort.future;

    port.send(CameraImagePathInfo(
      imagePath: imagePath,
      uniqueIdentifier: imagePath.hashCode,
    ));

    // Will wait for 50 events until cancel the listen
    int counter = 50;

    await for (final result in _controller.stream) {
      if (result.id == imagePath.hashCode) {
        return result;
      } else if (counter == 0) {
        break;
      }

      counter--;
    }

    return BrazilianVehiclePlatesResult(imagePath.hashCode, const []);
  }

  void _handleData(dynamic data) {
    if (data is BrazilianVehiclePlatesResult) {
      _controller.add(data);
    } else if (data is SendPort) {
      final rootIsolateToken = RootIsolateToken.instance!;
      data.send(rootIsolateToken);
      // data.send(firstPlateRect);
      _runningReceivePort.complete(data);
    } else if (data is List<String?> && data.length == 2) {
      final error = RemoteError(data[0] as String, data[1] as String);
      _controller.addError(error, error.stackTrace);
    }
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

  bool closed = false;

  static final _plateRegex =
      RegExp(r'([A-Z]{3}[0-9][0-9A-Z][0-9]{2})|([A-Z]{3}.[0-9]{4})');

  static final _imageConverter = CameraImageConverter();

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
    } else if (data is String) {
      final inputImage = InputImage.fromFilePath(data);

      if (closed) return;
      final plates = await _processPlatesFromInputImage(
        inputImage,
        textRecognizer,
      );

      final result = BrazilianVehiclePlatesResult(data.hashCode, plates);

      if (closed) return;

      _sendPort.send(result);
    } else if (data is CameraImageInfo) {
      final inputImage = await _imageConverter.inputImageFromCameraImage(
        data.image,
        data.cameraDescription,
        data.deviceOrientation,
      );
      if (closed || inputImage == null) return;

      final plates =
          await _processPlatesFromInputImage(inputImage, textRecognizer);

      final result =
          BrazilianVehiclePlatesResult(data.uniqueIdentifier, plates);

      if (closed) return;

      _sendPort.send(result);
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
      if (closed) return [];
      final recognizedText = await textRecognizer.processImage(inputImage);
      if (closed) return [];

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

      final width = inputImage.metadata?.size.width ?? 1;
      final height = inputImage.metadata?.size.height ?? 1;

      final foundPlates = <String>{};

      for (TextBlock block in recognizedText.blocks) {
        final String text = block.text.toUpperCase();

        final boundingBox = Rect.fromLTRB(
          block.boundingBox.left / width,
          block.boundingBox.top / height,
          block.boundingBox.right / width,
          block.boundingBox.bottom / height,
        );

        if (_plateRegex.hasMatch(text)) {
          brazilianPlates.addAll(_plateRegex
              .allMatches(text)
              .map((match) => match.group(0).toString())
              .map(
                (plate) => BrazilianVehiclePlate(
                    plate, 0, boundingBox, block.cornerPoints, 0, true),
              ));
          foundPlates.add(text);
        }

        if (text.length == 7 || text.length == 8) {
          final newCombinations = _mappings(text, mappings)
              .where((combination) => _plateRegex.hasMatch(combination.text));

          for (final combination in newCombinations) {
            if (!(foundPlates.contains(combination.text))) {
              foundPlates.add(text);
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
      }

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
