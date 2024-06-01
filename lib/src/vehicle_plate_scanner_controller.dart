import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:vehicle_plate_scanner/src/models/brazilian_vehicle_plate.dart';
import 'package:vehicle_plate_scanner/src/models/brazilian_vehicle_plates_result.dart';
import 'package:vehicle_plate_scanner/src/models/camera_image_info.dart';
import 'package:vehicle_plate_scanner/src/vehicle_plate_recognizer.dart';

class VehiclePlateScannerController extends ChangeNotifier
    implements ValueListenable<VehiclePlateScannerController> {
  static List<CameraDescription>? _cameras;

  late final _plateRecognizer = VehiclePlateRecognizer();

  final Logger _log = Logger();

  bool closed = false;

  Rect plateRect;

  CameraController? _cameraController;
  ResolutionPreset _defaultResolutionPreset;
  CameraDescription? _currentCamera;
  bool _initialized = false;
  bool _processing = false;

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

  Future<void> init() async {
    // TODO(marcosfons): Error handling
    await _plateRecognizer.init();

    await loadCameras();
  }

  Future<void> loadCameras() async {
    try {
      _cameras = await availableCameras();
    } catch (e, st) {
      _log.e('Error getting available cameras', error: e, stackTrace: st);
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

  Future<void> stopAll() async {
    _initialized = false;
    _currentCamera = null;
    notifyListeners();

    if (_cameraController != null) {
      final controller = _cameraController;
      _cameraController = null;

      if (controller?.value.isStreamingImages ?? false) {
        controller?.stopImageStream();
      }

      await controller?.dispose();
    }
    notifyListeners();
  }

  Future<void> changeCamera(CameraDescription camera) async {
    _initialized = false;
    _currentCamera = null;
    notifyListeners();

    if (_cameraController != null) {
      final controller = _cameraController;
      _cameraController = null;

      if (controller?.value.isStreamingImages ?? false) {
        controller?.stopImageStream();
      }

      await controller?.dispose();
    }

    _processing = false;

    _cameraController = CameraController(
      camera,
      _defaultResolutionPreset,
      enableAudio: false,
      // imageFormatGroup: Platform.isAndroid
      //     ? ImageFormatGroup.nv21
      //     : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    await _cameraController!.setFlashMode(FlashMode.off);
    await _cameraController!
        .lockCaptureOrientation(DeviceOrientation.portraitUp);

    await _cameraController!.startImageStream(_onCameraImage);

    _initialized = true;
    _currentCamera = camera;
    notifyListeners();
  }

  void _onPlatesResult(BrazilianVehiclePlatesResult result) {
    _currentPlates = result.plates;
    notifyListeners();

    onVehiclePlates(_currentPlates);
  }

  void _onCameraImage(CameraImage image) async {
    if (_processing) {
      return;
    }

    _processing = true;

    try {
      final cameraImageInfo = CameraImageInfo(
        image: image,
        cameraDescription: _currentCamera!,
        deviceOrientation: DeviceOrientation.portraitUp,
        uniqueIdentifier: image.hashCode,
      );

      if (closed) return;

      final result = await _plateRecognizer
          .processImage(cameraImageInfo)
          .timeout(const Duration(seconds: 15));
      _onPlatesResult(result);
    } catch (e, st) {
      _log.e('Error processing image', error: e, stackTrace: st);
    } finally {
      await Future.delayed(const Duration(milliseconds: 150));
      _processing = false;
    }
  }

  @override
  Future<void> dispose() async {
    closed = true;
    _initialized = false;

    if (_cameraController?.value.isStreamingImages ?? false) {
      await _cameraController?.stopImageStream();
    }
    await _cameraController?.dispose();
    _cameraController = null;

    Future.delayed(
      const Duration(seconds: 1),
      () => _plateRecognizer.dispose(),
    );

    super.dispose();
  }

  @override
  get value => this;
}
