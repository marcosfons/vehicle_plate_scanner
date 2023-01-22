import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:vehicle_plate_scanner/src/models/brazilian_vehicle_plate.dart';
import 'package:vehicle_plate_scanner/src/models/camera_image_info.dart';
import 'package:vehicle_plate_scanner/src/vehicle_plate_recognizer.dart';

class VehiclePlateScannerController extends ChangeNotifier
    implements ValueListenable<VehiclePlateScannerController> {
  static List<CameraDescription>? _cameras;

  late final _plateRecognizer = VehiclePlateRecognizer(plateRect);

  Rect plateRect;

  CameraController? _cameraController;
  ResolutionPreset _defaultResolutionPreset;
  CameraDescription? _currentCamera;
  bool _initialized = false;
  bool _processing = false;
  Timer? _timer;

  // Uint8List? memoryImage;
  // List<BrazilianVehiclePlate> lastPlates = [];

  List<BrazilianVehiclePlate> _currentPlates = [];

  final Function(List<BrazilianVehiclePlate>) onVehiclePlates;

  VehiclePlateScannerController({
    required this.onVehiclePlates,
    required this.plateRect,
    ResolutionPreset resolutionPreset = ResolutionPreset.high,
  }) : _defaultResolutionPreset = resolutionPreset;

  CameraController? get cameraController => _cameraController;
  List<CameraDescription>? get cameras => _cameras;
  List<BrazilianVehiclePlate> get currentPlates => _currentPlates;
  CameraDescription? get currentCamera => _currentCamera;

  bool get initialized => _initialized;

  void changePlateRect(Rect newRect) {
    plateRect = newRect;
    _plateRecognizer.changePlateRect(newRect);
  }

  Future<void> init() async {
    // TODO(marcosfons): Error handling
    await _plateRecognizer.init();

    try {
      _cameras = await availableCameras();
    } catch (e) {
      _cameras = [];
    }
  }

  Future<void> changeResolutionPreset(ResolutionPreset resolutionPreset) async {
    if (resolutionPreset == _defaultResolutionPreset) {
      return;
    }

    _defaultResolutionPreset = resolutionPreset;
    notifyListeners();

    if (_cameraController != null) {
      return changeCamera(_cameraController!.description);
    }
  }

  Future<void> changeCamera(CameraDescription camera) async {
    _initialized = false;
    _currentCamera = null;
    notifyListeners();

    if (_cameraController != null) {
      final controller = _cameraController;
      _cameraController = null;

      // await controller?.stopImageStream();
      await controller?.dispose();
    }
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }

    _processing = false;

    _cameraController = CameraController(
      camera,
      _defaultResolutionPreset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();
    // await _cameraController!.startImageStream(_onImage);

    await _cameraController!.setFlashMode(FlashMode.off);

    _timer = Timer.periodic(
      const Duration(milliseconds: 1),
      (timer) {
        _captureAndProcessImage();
      },
    );

    _initialized = true;
    _currentCamera = camera;
    notifyListeners();
  }

  Future<void> _captureAndProcessImage() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _processing == true) {
      return;
    }

    _processing = true;

    late final XFile? fileImage;

    try {
      final stopwatch = Stopwatch()..start();
      fileImage = await _cameraController!.takePicture();
      stopwatch.stop();

      print(
          'Image taken ${stopwatch.elapsedMilliseconds}  -  ${fileImage.path} ${fileImage.length()}');
    } catch (e, st) {
      print('Error occurred while taking picture');
      print(e.toString());
      print(st.toString());
      await Future.delayed(const Duration(milliseconds: 20));

      _processing = false;
      return;
    }

    try {
      _currentPlates =
          await _plateRecognizer.processImageFromFilePath(fileImage.path);
      notifyListeners();

      onVehiclePlates(_currentPlates);
    } catch (e, st) {
      print('Error processing images');
      print(e.toString());
      print(st.toString());
    }

    try {
      final file = File(fileImage.path);
      await file.delete();
    } catch (e, st) {
      print('Error deleting image');
      print(e.toString());
      print(st.toString());
    }

    _processing = false;
  }

  void _onImage(CameraImage image) async {
    if (_processing) {
      return;
    }

    _processing = true;

    try {
      final cameraImageInfo = CameraImageInfo(
        image: image,
        cameraSensorOrientation: _currentCamera!.sensorOrientation,
        // cameraSensorOrientation: _cameraController.value.recordingOrientation,
      );

      _currentPlates = await _plateRecognizer.processImage(cameraImageInfo);
      notifyListeners();

      // if (_currentPlates.isNotEmpty) {
      //   memoryImage = convertImageWithVehiclePlate(image, _currentPlates.first);
      //   lastPlates = List.from(_currentPlates);
      //   notifyListeners();
      // }

      onVehiclePlates(_currentPlates);
    } catch (e, st) {
      print(e.toString());
      print(st.toString());
    }

    _processing = false;
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
    _timer?.cancel();
    // await _cameraController?.stopImageStream();
    await _cameraController?.dispose();

    await _plateRecognizer.dispose();

    super.dispose();
  }

  @override
  get value => this;
}
