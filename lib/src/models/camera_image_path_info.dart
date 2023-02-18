import 'package:flutter/foundation.dart';

@immutable
class CameraImagePathInfo {
  /// The image provided by the `camera` package
  final String imagePath;

  final int uniqueIdentifier;

  const CameraImagePathInfo({
    required this.imagePath,
    required this.uniqueIdentifier,
  });
}
