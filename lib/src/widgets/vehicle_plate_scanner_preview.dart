import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:vehicle_plate_scanner/src/vehicle_plate_scanner_controller.dart';
import 'package:vehicle_plate_scanner/src/widgets/vehicle_plates_painter.dart';

class VehiclePlateScannerPreview extends StatefulWidget {
  const VehiclePlateScannerPreview({super.key});

  @override
  State<VehiclePlateScannerPreview> createState() =>
      _VehiclePlateScannerPreviewState();
}

class _VehiclePlateScannerPreviewState
    extends State<VehiclePlateScannerPreview> {
  final _controller = VehiclePlateScannerController();

  @override
  void initState() {
    super.initState();

    _init();
  }

  void _init() async {
    await _controller.init();
    if ((_controller.cameras?.length ?? 0) > 0) {
      await _controller.changeCamera(_controller.cameras!.first);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _controller,
      builder: (context, controller, child) {
        if (!controller.initialized || controller.cameraController == null) {
          return const _LoadingScreenWidget();
        }

        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            CameraPreview(
              controller.cameraController!,
              child: CustomPaint(
                foregroundPainter: VehiclePlatesPainter(
                  controller.currentPlates,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: ResolutionPreset.values
                        .map(
                          (res) => Expanded(
                            child: TextButton(
                              onPressed: () =>
                                  _controller.changeResolutionPreset(res),
                              child: Text(
                                res.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: controller.cameras!
                        .map(
                          (camera) => IconButton(
                            color: Colors.white,
                            icon: const Icon(Icons.camera),
                            onPressed: () => _controller.changeCamera(camera),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LoadingScreenWidget extends StatelessWidget {
  const _LoadingScreenWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: const [
          CircularProgressIndicator(
            strokeWidth: 1.3,
            color: Colors.white,
          ),
          SizedBox(
            height: 18,
            width: double.infinity,
          ),
          Text(
            'Carregando',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          )
        ],
      ),
    );
  }
}
