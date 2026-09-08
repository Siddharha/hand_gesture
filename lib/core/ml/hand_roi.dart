import 'dart:math' as math;

import 'geometry.dart';

/// Builds the crop the landmark model runs on.
///
/// MediaPipe never feeds the landmark model a raw bounding box. It rotates the
/// region so the hand points "up", squares it, expands it well past the palm,
/// and shifts it toward the fingers. Getting these constants wrong yields
/// landmarks that are subtly but persistently wrong, so they are kept here with
/// their MediaPipe names.
abstract final class HandRoi {
  /// Stand the hand upright: the wrist→middle-finger vector points to 90°.
  static const _targetAngle = math.pi / 2;

  /// `palm_detection_to_roi`: keypoint 0 is the wrist, keypoint 2 the middle
  /// finger MCP.
  static const palmWristKeypoint = 0;
  static const palmMiddleFingerKeypoint = 2;
  static const _palmScale = 2.6;
  static const _palmShiftY = -0.5;

  /// `hand_landmarks_to_roi`: landmark 0 is the wrist, landmark 9 the middle
  /// finger MCP.
  static const landmarkWristIndex = 0;
  static const landmarkMiddleFingerIndex = 9;
  static const _landmarkScale = 2.0;
  static const _landmarkShiftY = -0.1;

  /// ROI for a palm the detector found.
  ///
  /// [box] and [keypoints] are in the same normalised space; [aspectRatio] is
  /// that space's width / height.
  static RotatedRect fromPalmDetection({
    required NormalizedRect box,
    required List<(double, double)> keypoints,
    required double aspectRatio,
  }) {
    final (startX, startY) = keypoints[palmWristKeypoint];
    final (endX, endY) = keypoints[palmMiddleFingerKeypoint];

    return _transform(
      base: RotatedRect(
        centerX: box.centerX,
        centerY: box.centerY,
        width: box.width,
        height: box.height,
        rotation: rotationFromKeypoints(
          startX: startX,
          startY: startY,
          endX: endX,
          endY: endY,
          targetAngle: _targetAngle,
          aspectRatio: aspectRatio,
        ),
      ),
      scale: _palmScale,
      shiftY: _palmShiftY,
      aspectRatio: aspectRatio,
    );
  }

  /// ROI for the next frame, derived from the landmarks of this one.
  ///
  /// This is what lets the pipeline skip the palm detector: as long as the hand
  /// keeps being found, its previous position tells us where to look next.
  static RotatedRect fromLandmarks({
    required List<(double, double)> landmarks,
    required double aspectRatio,
  }) {
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;

    for (final (x, y) in landmarks) {
      left = math.min(left, x);
      right = math.max(right, x);
      top = math.min(top, y);
      bottom = math.max(bottom, y);
    }

    final (startX, startY) = landmarks[landmarkWristIndex];
    final (endX, endY) = landmarks[landmarkMiddleFingerIndex];

    return _transform(
      base: RotatedRect(
        centerX: (left + right) / 2,
        centerY: (top + bottom) / 2,
        width: right - left,
        height: bottom - top,
        rotation: rotationFromKeypoints(
          startX: startX,
          startY: startY,
          endX: endX,
          endY: endY,
          targetAngle: _targetAngle,
          aspectRatio: aspectRatio,
        ),
      ),
      scale: _landmarkScale,
      shiftY: _landmarkShiftY,
      aspectRatio: aspectRatio,
    );
  }

  /// MediaPipe's `RectTransformationCalculator`: shift, square, then scale.
  static RotatedRect _transform({
    required RotatedRect base,
    required double scale,
    required double shiftY,
    required double aspectRatio,
  }) {
    return base
        .shifted(0, shiftY, aspectRatio)
        .squaredLong(aspectRatio)
        .scaled(scale, scale);
  }
}
