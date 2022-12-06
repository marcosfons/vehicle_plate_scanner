import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:vehicle_plate_scanner/src/camera_image_info.dart';

class PlateRecognizer {
  static Future<Set<String>> recognizePlates(CameraImageInfo imageData) async {
    return flutterCompute(
      _processPlatesFromCameraImageData,
      imageData.exportToPlatformData(),
    );
  }

  @pragma('vm:entry-point')
  static Future<Set<String>> _processPlatesFromCameraImageData(
    Map<String, dynamic> message,
  ) async {
    final cameraImageData = CameraImageInfo.fromPlatformData(message);

    final inputImage = await cameraImageData.toInputImage();
    final plates = await _processPlatesFromInputImage(inputImage);
    return plates;
  }

  static final plateRegex =
      RegExp(r'([A-Z]{3}[0-9][0-9A-Z][0-9]{2})|([A-Z]{3}.[0-9]{4})');

  static Future<Set<String>> _processPlatesFromInputImage(
    InputImage inputImage,
  ) async {
    late TextRecognizer textRecognizer;

    try {
      textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      final recognizedText = await textRecognizer.processImage(inputImage);

      final Set<String> plates = {};

      for (TextBlock block in recognizedText.blocks) {
        final String text = block.text;

        if (plateRegex.hasMatch(text)) {
          plates.addAll(plateRegex
              .allMatches(text)
              .map((match) => match.group(0).toString()));
        }
      }

      return plates;
    } catch (e, st) {
      print('Error processing input image');
      print(e);
      print(st.toString());
      rethrow;
    } finally {
      await textRecognizer.close();
    }
  }
}
