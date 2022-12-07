import 'dart:math';
import 'dart:ui';

class BrazilianVehiclePlate {
  final String _plate;
  final Rect _boundingBox;
  final List<Point<int>> _cornerPoints;

  String get plate => _plate;
  // bool get isTheNewModel => _isNewModel;
  Rect get boundingBox => _boundingBox;
  List<Point<int>> get cornerPoints => _cornerPoints;

  BrazilianVehiclePlate(
    this._plate,
    this._boundingBox,
    this._cornerPoints,
  );

  BrazilianVehiclePlate.fromPlatformData(Map data)
      : _plate = data['plate'],
        _boundingBox = Rect.fromLTRB(
          data['box']['l'],
          data['box']['t'],
          data['box']['r'],
          data['box']['b'],
        ),
        _cornerPoints = (data['corners'] as List)
            .map(
              (corner) => Point<int>(
                corner['x'] as int,
                corner['y'] as int,
              ),
            )
            .toList();

  Map toPlatformData() {
    return {
      'plate': _plate,
      'box': {
        'l': boundingBox.left,
        't': boundingBox.top,
        'r': boundingBox.right,
        'b': boundingBox.bottom,
      },
      'corners': _cornerPoints
          .map(
            (cornerPoint) => {
              'x': cornerPoint.x,
              'y': cornerPoint.y,
            },
          )
          .toList()
    };
  }
}
