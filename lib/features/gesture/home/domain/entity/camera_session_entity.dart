/// Which camera a session is using.
enum CameraLens { front, back }

/// A running camera session, described in terms the UI needs: how to lay the
/// preview out and which way round it is.
class CameraSessionEntity {
  const CameraSessionEntity({
    required this.lens,
    required this.previewWidth,
    required this.previewHeight,
    required this.sensorOrientation,
    required this.isMirrored,
  });

  final CameraLens lens;

  /// Preview dimensions in upright (display) orientation.
  final double previewWidth;
  final double previewHeight;
  final int sensorOrientation;
  final bool isMirrored;

  double get aspectRatio => previewWidth / previewHeight;
}
