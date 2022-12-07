import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:vehicle_plate_scanner/src/models/brazilian_vehicle_plate.dart';
import 'package:vehicle_plate_scanner/src/models/camera_image_info.dart';

class PlateRecognizer {
  late final FlutterIsolate _isolate;
  final _runningReceivePort = Completer<SendPort>();

  late final ReceivePort _receivePort;

  late final StreamSubscription _dataSubscription;

  final _controller = StreamController<List<BrazilianVehiclePlate>>();
  late final _streamIterator = StreamIterator(_controller.stream);

  Future<void> init() async {
    _receivePort = ReceivePort();

    _isolate = await FlutterIsolate.spawn(
      processPlatesIsolate,
      _receivePort.sendPort,
    );

    _dataSubscription = _receivePort.listen(_handleData);

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
    port.send(cameraImageInfo.exportToPlatformData());

    // TODO(marcosfons): Add better handling here.
    // In the future, multiple images could be sended at the same time
    // Here it should check for an id, or something like that by using `takeWhile`
    final hasSomeValue = await _streamIterator.moveNext();

    return hasSomeValue ? _streamIterator.current : [];
  }

  void _handleData(dynamic data) {
    if (data is SendPort) {
      _runningReceivePort.complete(data);
    } else if (data is List) {
      _controller.add(data
          .map((plate) => BrazilianVehiclePlate.fromPlatformData(plate))
          .toList());
    }
  }

  Future<void> dispose() async {
    (await _runningReceivePort.future).send('exit');
    await _dataSubscription.cancel();
    _receivePort.close();
    _isolate.kill();
    _controller.close();
  }

  @pragma('vm:entry-point')
  static void processPlatesIsolate(SendPort sendPort) {
    ReceivePort mainToIsolateStream = ReceivePort();
    sendPort.send(mainToIsolateStream.sendPort);

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    late StreamSubscription inDataSubscription;

    inDataSubscription = mainToIsolateStream.listen((data) async {
      if (data is Map<String, dynamic>) {
        final cameraImageData = CameraImageInfo.fromPlatformData(data);

        final inputImage = await cameraImageData.toInputImage();
        final plates = await _processPlatesFromInputImage(
          inputImage,
          textRecognizer,
        );

        sendPort.send(
          plates.map((plate) => plate.toPlatformData()).toList(),
        );
      }
      //  else if (data is String && data == 'exit') {
      //   acceptingData = false;
      //   await inDataSubscription.cancel();
      // }
    }, onDone: () async {
      print('FINISHING ISOLATE');

      try {
        await textRecognizer.close();
        mainToIsolateStream.close();
      } catch (e, st) {
        print('AN ERROR HAS OCCURRED WHILE FINISHING ISOLATE');
        print(e.toString());
        print(st.toString());
      }
    });
  }

  static final plateRegex =
      RegExp(r'([A-Z]{3}[0-9][0-9A-Z][0-9]{2})|([A-Z]{3}.[0-9]{4})');

  static Future<List<BrazilianVehiclePlate>> _processPlatesFromInputImage(
    InputImage inputImage,
    TextRecognizer textRecognizer,
  ) async {
    try {
      final recognizedText = await textRecognizer.processImage(inputImage);

      final Set<String> plates = {};

      final List<BrazilianVehiclePlate> brazilianPlates = [];

      for (TextBlock block in recognizedText.blocks) {
        final String text = block.text;

        if (plateRegex.hasMatch(text)) {
          final boundingBox = Rect.fromLTRB(
            block.boundingBox.left / inputImage.inputImageData!.size.width,
            block.boundingBox.top / inputImage.inputImageData!.size.height,
            block.boundingBox.right / inputImage.inputImageData!.size.width,
            block.boundingBox.bottom / inputImage.inputImageData!.size.height,
          );
          // plates.addAll(plateRegex
          //     .allMatches(text)
          //     .map((match) => match.group(0).toString()));

          brazilianPlates.addAll(plateRegex
              .allMatches(text)
              .map((match) => match.group(0).toString())
              .map(
                (plate) => BrazilianVehiclePlate(
                  plate,
                  boundingBox,
                  block.cornerPoints,
                ),
              ));
        }
      }

      return brazilianPlates;
    } catch (e, st) {
      print('Error processing input image');
      print(e);
      print(st.toString());
      rethrow;
    }
  }
}
