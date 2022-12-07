import 'package:flutter/material.dart';
import 'package:vehicle_plate_scanner/src/models/brazilian_vehicle_plate.dart';

class VehiclePlatesPainter extends CustomPainter {
  final List<BrazilianVehiclePlate> _vehiclePlates;

  VehiclePlatesPainter(this._vehiclePlates);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..strokeWidth = 3.0
      ..color = Colors.red
      ..style = PaintingStyle.stroke;

    for (final plate in _vehiclePlates) {
      final rect = Rect.fromLTRB(
        plate.boundingBox.left * size.height,
        plate.boundingBox.top * size.width,
        plate.boundingBox.right * size.height,
        plate.boundingBox.bottom * size.width,
      );
      canvas.drawRect(rect, paint);

      // if (plate.cornerPoints.isNotEmpty) {
      //   final firstPoint = plate.cornerPoints.first;
      //   final path = Path();

      //   path.moveTo(firstPoint.x.toDouble(), firstPoint.y.toDouble());

      //   for (final cornerPoint in plate.cornerPoints) {
      //     path.lineTo(cornerPoint.x.toDouble(), cornerPoint.y.toDouble());
      //   }
      //   path.lineTo(firstPoint.x.toDouble(), firstPoint.y.toDouble());

      //   canvas.drawPath(path, pathPaint);
      // }
    }
  }

  @override
  bool shouldRepaint(VehiclePlatesPainter oldDelegate) {
    return oldDelegate._vehiclePlates != _vehiclePlates;
  }
}
