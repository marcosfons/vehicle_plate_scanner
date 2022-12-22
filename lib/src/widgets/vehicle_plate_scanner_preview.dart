import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:vehicle_plate_scanner/src/models/brazilian_vehicle_plate.dart';
import 'package:vehicle_plate_scanner/src/vehicle_plate_scanner_controller.dart';
import 'package:vehicle_plate_scanner/src/widgets/vehicle_plates_painter.dart';

class VehiclePlateScannerPreview extends StatefulWidget {
  const VehiclePlateScannerPreview({
    super.key,
    required this.onVehiclePlates,
    required this.plateRect,
    this.onSizePlateRect,
    // required this.plateRectOffset,
  });

  final Function(List<BrazilianVehiclePlate> plates) onVehiclePlates;

  /// Normalized rect where the plate must be placed on the screen
  final Rect plateRect;

  final Rect Function(Size)? onSizePlateRect;

  /// Normalized offset position of the plateRect
  // final Offset plateRectOffset;

  @override
  State<VehiclePlateScannerPreview> createState() =>
      _VehiclePlateScannerPreviewState();
}

class _VehiclePlateScannerPreviewState extends State<VehiclePlateScannerPreview>
    with WidgetsBindingObserver {
  late final _controller = VehiclePlateScannerController(
    onVehiclePlates: widget.onVehiclePlates,
    plateRect: widget.plateRect,
  );

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
  void didUpdateWidget(covariant VehiclePlateScannerPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.plateRect != oldWidget.plateRect) {
      _controller.changePlateRect(widget.plateRect);
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.initialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _init();
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
            AspectRatio(
              aspectRatio: controller.cameraController!.value.aspectRatio,
              child: IgnorePointer(
                child: LayoutBuilder(builder: (context, constraints) {
                  // final biggest = constraints.biggest;
                  // final newRect = Rect.fromLTRB(
                  //   widget.plateRect.left / biggest.width,
                  //   widget.plateRect.top / biggest.height,
                  //   widget.plateRect.right / biggest.width,
                  //   widget.plateRect.bottom / biggest.height,
                  // );

                  late Rect newRect;
                  if (widget.onSizePlateRect != null) {
                    newRect = widget.onSizePlateRect!(constraints.biggest);

                    if (newRect != _controller.plateRect) {
                      _controller.changePlateRect(newRect);
                    }
                  } else {
                    newRect = _controller.plateRect;
                  }

                  return ClipPath(
                    clipper: PlateRectCustomClipper(
                      plateRect: newRect,
                    ),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                  );
                }),
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

class PlateRectCustomClipper extends CustomClipper<Path> {
  final Rect plateRect;

  const PlateRectCustomClipper({
    required this.plateRect,
    // required this.plateRectOffset,
  });

  @override
  Path getClip(Size size) {
    final cutRect = Rect.fromLTRB(
      plateRect.left * size.width,
      plateRect.top * size.height,
      plateRect.right * size.width,
      plateRect.bottom * size.height,
    );

    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cutRect)
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(covariant PlateRectCustomClipper oldClipper) {
    return oldClipper.plateRect != plateRect;
    // oldClipper.plateRectOffset != plateRectOffset;
  }
}
