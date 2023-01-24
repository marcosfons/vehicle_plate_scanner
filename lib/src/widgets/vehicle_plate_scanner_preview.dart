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

  bool _error = false;

  @override
  void initState() {
    super.initState();

    _init();
  }

  void _init() async {
    try {
      if (_error == false) {
        await _controller.init();
      }

      if ((_controller.cameras?.length ?? 0) > 0) {
        await _controller.changeCamera(_controller.cameras!.first);
      } else {
        await _controller.loadCameras();
      }
    } catch (e) {
      setState(() {
        _error = true;
      });
    }
  }

  // @override
  // void didUpdateWidget(covariant VehiclePlateScannerPreview oldWidget) {
  //   super.didUpdateWidget(oldWidget);

  //   if (widget.plateRect != oldWidget.plateRect) {
  //     _controller.changePlateRect(widget.plateRect);
  //     setState(() {});
  //   }
  // }

  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   if (!_controller.initialized) {
  //     return;
  //   }

  //   if (state == AppLifecycleState.inactive) {
  //     _controller.dispose();
  //   } else if (state == AppLifecycleState.resumed) {
  //     _init();
  //   }
  // }

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
          return _LoadingScreenWidget(
            tryAgain: _error ? _init : null,
          );
        }
        return CameraPreview(
          controller.cameraController!,
        );
        // if (controller.memoryImage == null) {
        // if (controller.lastPlates.isEmpty) {
        // }
        // return Column(
        //   children: [
        //     Expanded(
        //       child: CameraPreview(
        //         controller.cameraController!,
        //       ),
        //     ),
        //     Expanded(
        //       child: Row(
        //         children: [
        //           // Expanded(child: Image.memory(controller.memoryImage!)),
        //           Expanded(
        //             child: Padding(
        //               padding: const EdgeInsets.only(
        //                 top: 12,
        //                 left: 6,
        //                 right: 6,
        //               ),
        //               child: ListView.builder(
        //                 itemCount: controller.lastPlates.length,
        //                 itemBuilder: (context, index) {
        //                   final plate = controller.lastPlates[index];

        //                   return Padding(
        //                     padding: const EdgeInsets.only(bottom: 2),
        //                     child: Text(
        //                       '${plate.plate}  Changes: ${plate.combinationChanges}',
        //                       style: TextStyle(
        //                         fontSize: plate.plate == 'QOO-4429' ? 23 : 17,
        //                       ),
        //                     ),
        //                   );
        //                 },
        //               ),
        //             ),
        //           ),
        //         ],
        //       ),
        //     ),
        //   ],
        // );

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
            // AspectRatio(
            //   aspectRatio: controller.cameraController!.value.aspectRatio,
            //   child: IgnorePointer(
            //     child: LayoutBuilder(builder: (context, constraints) {
            //       // final biggest = constraints.biggest;
            //       // final newRect = Rect.fromLTRB(
            //       //   widget.plateRect.left / biggest.width,
            //       //   widget.plateRect.top / biggest.height,
            //       //   widget.plateRect.right / biggest.width,
            //       //   widget.plateRect.bottom / biggest.height,
            //       // );

            //       late Rect newRect;
            //       if (widget.onSizePlateRect != null) {
            //         newRect = widget.onSizePlateRect!(constraints.biggest);

            //         if (newRect != _controller.plateRect) {
            //           _controller.changePlateRect(newRect);
            //         }
            //       } else {
            //         newRect = _controller.plateRect;
            //       }

            //       return ClipPath(
            //         clipper: PlateRectCustomClipper(
            //           plateRect: newRect,
            //         ),
            //         child: Container(
            //           color: Colors.black.withOpacity(0.3),
            //         ),
            //       );
            //     }),
            //   ),
            // ),
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 12),
            //   child: Column(
            //     mainAxisSize: MainAxisSize.min,
            //     children: [
            //       Row(
            //         children: ResolutionPreset.values
            //             .map(
            //               (res) => Expanded(
            //                 child: TextButton(
            //                   onPressed: () =>
            //                       _controller.changeResolutionPreset(res),
            //                   child: Text(
            //                     res.name,
            //                     style: const TextStyle(
            //                       color: Colors.white,
            //                       fontSize: 14,
            //                       fontWeight: FontWeight.bold,
            //                     ),
            //                   ),
            //                 ),
            //               ),
            //             )
            //             .toList(),
            //       ),
            //       const SizedBox(height: 12),
            //       Row(
            //         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //         children: controller.cameras!
            //             .map(
            //               (camera) => IconButton(
            //                 color: Colors.white,
            //                 icon: const Icon(Icons.camera),
            //                 onPressed: () => _controller.changeCamera(camera),
            //               ),
            //             )
            //             .toList(),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        );
      },
    );
  }
}

class _LoadingScreenWidget extends StatelessWidget {
  const _LoadingScreenWidget({required this.tryAgain});

  final void Function()? tryAgain;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          const CircularProgressIndicator(
            strokeWidth: 1.3,
            color: Colors.white,
          ),
          const SizedBox(height: 20),
          if (tryAgain != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: ElevatedButton(
                onPressed: tryAgain!,
                child: const Text('Tentar novamente'),
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
