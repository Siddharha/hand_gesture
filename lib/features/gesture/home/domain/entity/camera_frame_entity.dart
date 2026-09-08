import 'dart:typed_data';

/// Pixel layout of a frame as it arrives from the platform.
enum CameraFrameFormat { yuv420, bgra8888 }

/// One plane of a frame, with the strides needed to index into it.
class CameraPlaneEntity {
  const CameraPlaneEntity({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel = 1,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;
}

/// A single frame off the camera stream, plus everything needed to read it in
/// the orientation the user sees.
class CameraFrameEntity {
  const CameraFrameEntity({
    required this.planes,
    required this.format,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.mirrored,
    required this.capturedAt,
  });

  final List<CameraPlaneEntity> planes;
  final CameraFrameFormat format;

  /// Dimensions as delivered by the sensor, before [rotationDegrees].
  final int width;
  final int height;

  /// Clockwise rotation that stands the frame upright on screen.
  final int rotationDegrees;

  /// Whether the frame is mirrored for display, as front cameras are.
  final bool mirrored;

  /// When the frame reached Dart. The gap between this and the moment a result
  /// is emitted is the lag the user actually sees in the overlay.
  final DateTime capturedAt;

  bool get swapsAxes => ((rotationDegrees ~/ 90) % 4).isOdd;

  int get uprightWidth => swapsAxes ? height : width;

  int get uprightHeight => swapsAxes ? width : height;

  double get uprightAspectRatio => uprightWidth / uprightHeight;
}
