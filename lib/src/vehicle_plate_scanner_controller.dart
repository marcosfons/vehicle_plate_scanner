import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vehicle_plate_scanner/src/models/brazilian_vehicle_plate.dart';
import 'package:vehicle_plate_scanner/src/models/brazilian_vehicle_plates_result.dart';
import 'package:vehicle_plate_scanner/src/models/camera_image_info.dart';
import 'package:vehicle_plate_scanner/src/vehicle_plate_recognizer.dart';

class VehiclePlateScannerController extends ChangeNotifier
    implements ValueListenable<VehiclePlateScannerController> {
  static List<CameraDescription>? _cameras;

  late final _plateRecognizer = VehiclePlateRecognizer();

  bool closed = false;

  Rect plateRect;

  CameraController? _cameraController;
  ResolutionPreset _defaultResolutionPreset;
  CameraDescription? _currentCamera;
  bool _initialized = false;
  bool _processing = false;

  StreamSubscription<BrazilianVehiclePlatesResult>? _cameraImageSubscription;

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

  Future<void> init() async {
    // TODO(marcosfons): Error handling
    await _plateRecognizer.init();

    await loadCameras();
  }

  Future<void> loadCameras() async {
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

      await (_cameraImageSubscription?.cancel() ?? Future.value());
      _cameraImageSubscription = null;

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

      await (_cameraImageSubscription?.cancel() ?? Future.value());
      _cameraImageSubscription = null;

      await controller?.dispose();
    }

    _processing = false;

    _cameraController = CameraController(
      camera,
      _defaultResolutionPreset,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    await _cameraController!.setFlashMode(FlashMode.off);

    await _cameraController!.startImageStream(_onCameraImage);

    _initialized = true;
    _currentCamera = camera;
    notifyListeners();
  }

  Stream<BrazilianVehiclePlatesResult> _cameraImagePathStream() async* {
    while (true) {
      try {
        final fileImage = await _cameraController!.takePicture();

        try {
          if (closed) return;
          final result =
              await _plateRecognizer.processImageFromFilePath(fileImage.path);

          yield result;
        } catch (e, st) {
          print('Error processing image');
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

        await Future.delayed(const Duration(milliseconds: 2));
      } catch (e) {
        yield const BrazilianVehiclePlatesResult(0, []);

        await Future.delayed(const Duration(milliseconds: 10));
      }
    }
  }

  void _onPlatesResult(BrazilianVehiclePlatesResult result) {
    _currentPlates = result.plates;
    notifyListeners();

    onVehiclePlates(_currentPlates);

    // if (_currentPlates.isNotEmpty) {
    //   lastPlates = _currentPlates;
    // }

    // if (_currentPlates.isNotEmpty) {
    //   memoryImage = convertImageWithVehiclePlate(image, _currentPlates.first);
    //   lastPlates = List.from(_currentPlates);
    //   notifyListeners();
    // }
  }

  void _changeCameraStreamToCameraCaptureStream() async {
    if (_cameraController?.value.isStreamingImages ?? false) {
      _cameraController?.stopImageStream();
    }

    _processing = false;

    _cameraImageSubscription = _cameraImagePathStream().listen(_onPlatesResult);
  }

  void _onCameraImage(CameraImage image) async {
    if (_processing) {
      return;
    }

    _processing = true;

    if (Platform.isAndroid) {
      for (final plane in image.planes) {
        if (image.width != plane.bytesPerRow) {
          return _changeCameraStreamToCameraCaptureStream();
        }
      }
    }

    try {
      final orientations = {
        DeviceOrientation.portraitUp: 0,
        DeviceOrientation.landscapeLeft: 90,
        DeviceOrientation.portraitDown: 180,
        DeviceOrientation.landscapeRight: 270,
      };

      final cameraImageInfo = CameraImageInfo(
        image: image,
        cameraSensorOrientation: _currentCamera!.sensorOrientation,
        orientation: orientations[_cameraController!.value.deviceOrientation]!,
        lensDirection: _currentCamera!.lensDirection,
        uniqueIdentifier: image.hashCode,
      );

      if (closed) return;

      final result = await _plateRecognizer.processImage(cameraImageInfo);
      _onPlatesResult(result);
    } catch (e, st) {
      print(e.toString());
      print(st.toString());
    }

    Future.delayed(
      const Duration(milliseconds: 2),
      () => _processing = false,
    );
  }

  @override
  Future<void> dispose() async {
    closed = true;
    _initialized = false;
    await _cameraImageSubscription?.cancel();

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
