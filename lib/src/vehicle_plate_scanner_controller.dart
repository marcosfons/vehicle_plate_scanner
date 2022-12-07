import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:vehicle_plate_scanner/src/models/brazilian_vehicle_plate.dart';
import 'package:vehicle_plate_scanner/src/models/camera_image_info.dart';
import 'package:vehicle_plate_scanner/src/vehicle_plate_recognizer.dart';

class VehiclePlateScannerController extends ChangeNotifier
    implements ValueListenable<VehiclePlateScannerController> {
  static List<CameraDescription>? _cameras;

  final _plateRecognizer = PlateRecognizer();

  CameraController? _cameraController;
  ResolutionPreset _defaultResolutionPreset;
  CameraDescription? _currentCamera;
  bool _initialized = false;
  bool _processing = false;

  List<BrazilianVehiclePlate> _currentPlates = [];

  VehiclePlateScannerController({
    ResolutionPreset resolutionPreset = ResolutionPreset.high,
  }) : _defaultResolutionPreset = resolutionPreset;

  CameraController? get cameraController => _cameraController;
  List<CameraDescription>? get cameras => _cameras;
  List<BrazilianVehiclePlate> get currentPlates => _currentPlates;
  CameraDescription? get currentCamera => _currentCamera;

  bool get initialized => _initialized;

  Future<void> init() async {
    if (_cameras != null) {
      return;
    }

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

      await controller?.stopImageStream();
      await controller?.dispose();
    }

    _cameraController = CameraController(
      camera,
      _defaultResolutionPreset,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    await _cameraController!.startImageStream(_onImage);

    _initialized = true;
    _currentCamera = camera;
    notifyListeners();
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
      );

      _currentPlates = await _plateRecognizer.processImage(cameraImageInfo);
      notifyListeners();

      print(_currentPlates);
    } catch (e, st) {
      print(e.toString());
      print(st.toString());
    }

    // await Future.delayed(const Duration(milliseconds: 500));
    _processing = false;
  }

  @override
  Future<void> dispose() async {
    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();

    await _plateRecognizer.dispose();

    super.dispose();
  }

  @override
  get value => this;
}
