import 'dart:math' as math;

/// An axis-aligned rectangle in normalised `[0, 1]` image space.
class NormalizedRect {
  const NormalizedRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;

  double get bottom => top + height;

  double get centerX => left + width / 2;

  double get centerY => top + height / 2;

  double get area => width * height;

  /// Intersection-over-union with [other], used by non-max suppression.
  double iou(NormalizedRect other) {
    final interLeft = math.max(left, other.left);
    final interTop = math.max(top, other.top);
    final interRight = math.min(right, other.right);
    final interBottom = math.min(bottom, other.bottom);

    if (interRight <= interLeft || interBottom <= interTop) return 0;

    final intersection = (interRight - interLeft) * (interBottom - interTop);
    final union = area + other.area - intersection;
    return union <= 0 ? 0 : intersection / union;
  }
}

/// A rectangle that may be rotated about its centre, in normalised image space.
///
/// This is how MediaPipe expresses a region of interest: the crop fed to the
/// landmark model is rotated so the hand always arrives upright.
class RotatedRect {
  const RotatedRect({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
    this.rotation = 0,
  });

  final double centerX;
  final double centerY;
  final double width;
  final double height;

  /// Clockwise rotation in radians.
  final double rotation;

  /// Grows the rect about its centre, keeping the rotation.
  RotatedRect scaled(double scaleX, double scaleY) => RotatedRect(
        centerX: centerX,
        centerY: centerY,
        width: width * scaleX,
        height: height * scaleY,
        rotation: rotation,
      );

  /// Makes the rect square by taking its longer side — TFLite crops are square.
  ///
  /// [aspectRatio] is the image's width / height: normalised space is not
  /// isotropic, so the shorter axis has to be corrected before comparing sides.
  RotatedRect squaredLong(double aspectRatio) {
    final longSide = math.max(width * aspectRatio, height);
    return RotatedRect(
      centerX: centerX,
      centerY: centerY,
      width: longSide / aspectRatio,
      height: longSide,
      rotation: rotation,
    );
  }

  /// Shifts the centre along the rect's own (rotated) axes.
  ///
  /// The rotation has to happen in square space, so each axis' contribution to
  /// the other is corrected by [aspectRatio] - exactly as MediaPipe's
  /// `RectTransformationCalculator` does. Without it a rotated shift drifts
  /// sideways on any non-square frame, and the crop slides off the hand.
  RotatedRect shifted(double shiftX, double shiftY, double aspectRatio) {
    final cos = math.cos(rotation);
    final sin = math.sin(rotation);

    return RotatedRect(
      centerX: centerX + width * shiftX * cos - height * shiftY * sin / aspectRatio,
      centerY: centerY + aspectRatio * width * shiftX * sin + height * shiftY * cos,
      width: width,
      height: height,
      rotation: rotation,
    );
  }

  /// Maps a point given in this rect's local `[0, 1]` space back into image
  /// space — how landmark outputs are lifted out of the crop.
  (double, double) toImageSpace(double localX, double localY, double aspectRatio) {
    final cos = math.cos(rotation);
    final sin = math.sin(rotation);

    // Offset from the rect centre, in local units, corrected for aspect so the
    // rotation happens in a square space.
    final dx = (localX - 0.5) * width * aspectRatio;
    final dy = (localY - 0.5) * height;

    return (
      centerX + (dx * cos - dy * sin) / aspectRatio,
      centerY + (dx * sin + dy * cos),
    );
  }

  /// The axis-aligned bounds of this rect, ignoring rotation.
  NormalizedRect get bounds => NormalizedRect(
        left: centerX - width / 2,
        top: centerY - height / 2,
        width: width,
        height: height,
      );
}

/// The rotation that brings the vector `start → end` onto [targetAngle],
/// measured clockwise in radians. MediaPipe uses this to stand the hand up
/// before cropping.
double rotationFromKeypoints({
  required double startX,
  required double startY,
  required double endX,
  required double endY,
  required double targetAngle,
  required double aspectRatio,
}) {
  // Work in square space so the angle is not skewed by the image aspect.
  final dx = (endX - startX) * aspectRatio;
  final dy = endY - startY;
  return _normalizeRadians(targetAngle - math.atan2(-dy, dx));
}

double _normalizeRadians(double angle) {
  return angle - 2 * math.pi * ((angle + math.pi) / (2 * math.pi)).floor();
}
