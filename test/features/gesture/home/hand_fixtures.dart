import 'dart:math' as math;

import 'package:hand_gesture/features/gesture/home/domain/entity/hand_entity.dart';
import 'package:hand_gesture/features/gesture/home/domain/entity/hand_landmark_entity.dart';

/// Builds a canonical hand: palm at the bottom, fingers pointing up the frame.
///
/// Extended fingers run straight up from the knuckle; curled ones fold back
/// down so the knuckle-to-tip chord collapses, which is exactly what the
/// straightness measure keys on.
HandEntity buildHand({
  bool thumb = false,
  bool index = false,
  bool middle = false,
  bool ring = false,
  bool pinky = false,
  double thumbTipX = 0.26,
  double thumbTipY = 0.62,
  bool overrideThumbTip = false,
}) {
  final points = List<HandLandmarkEntity>.filled(
    21,
    const HandLandmarkEntity(x: 0, y: 0, z: 0),
  );

  void put(HandLandmarkType type, double x, double y) {
    points[type.index] = HandLandmarkEntity(x: x, y: y, z: 0);
  }

  put(HandLandmarkType.wrist, 0.50, 0.90);

  // Thumb runs down-left from the wrist; extended reaches away from the palm,
  // tucked folds back across it.
  put(HandLandmarkType.thumbCmc, 0.44, 0.82);
  put(HandLandmarkType.thumbMcp, 0.38, 0.76);
  if (thumb) {
    put(HandLandmarkType.thumbIp, 0.32, 0.69);
    put(HandLandmarkType.thumbTip, 0.26, 0.62);
  } else {
    put(HandLandmarkType.thumbIp, 0.44, 0.72);
    put(HandLandmarkType.thumbTip, 0.50, 0.69);
  }
  if (overrideThumbTip) {
    put(HandLandmarkType.thumbTip, thumbTipX, thumbTipY);
  }

  final layout = <(bool, double, List<HandLandmarkType>)>[
    (
      index,
      0.44,
      [
        HandLandmarkType.indexMcp,
        HandLandmarkType.indexPip,
        HandLandmarkType.indexDip,
        HandLandmarkType.indexTip,
      ]
    ),
    (
      middle,
      0.50,
      [
        HandLandmarkType.middleMcp,
        HandLandmarkType.middlePip,
        HandLandmarkType.middleDip,
        HandLandmarkType.middleTip,
      ]
    ),
    (
      ring,
      0.56,
      [
        HandLandmarkType.ringMcp,
        HandLandmarkType.ringPip,
        HandLandmarkType.ringDip,
        HandLandmarkType.ringTip,
      ]
    ),
    (
      pinky,
      0.62,
      [
        HandLandmarkType.pinkyMcp,
        HandLandmarkType.pinkyPip,
        HandLandmarkType.pinkyDip,
        HandLandmarkType.pinkyTip,
      ]
    ),
  ];

  for (final (isExtended, x, joints) in layout) {
    put(joints[0], x, 0.60);
    if (isExtended) {
      put(joints[1], x, 0.50);
      put(joints[2], x, 0.44);
      put(joints[3], x, 0.38);
    } else {
      put(joints[1], x, 0.52);
      put(joints[2], x, 0.56);
      put(joints[3], x, 0.60);
    }
  }

  return HandEntity(
    landmarks: points,
    handedness: Handedness.right,
    score: 1,
  );
}

/// Moves a hand around the frame without changing its shape: mirrors it to the
/// other hand, spins it, resizes it, shifts it. Every gesture reading should
/// survive all of these — that is the whole point of measuring ratios.
HandEntity transform(
  HandEntity hand, {
  double rotation = 0,
  double scale = 1,
  double dx = 0,
  double dy = 0,
  bool mirror = false,
}) {
  const cx = 0.5;
  const cy = 0.5;
  final cos = math.cos(rotation);
  final sin = math.sin(rotation);

  return HandEntity(
    landmarks: [
      for (final point in hand.landmarks)
        () {
          final x = mirror ? (1 - point.x) : point.x;
          final ox = x - cx;
          final oy = point.y - cy;
          return HandLandmarkEntity(
            x: cx + (ox * cos - oy * sin) * scale + dx,
            y: cy + (ox * sin + oy * cos) * scale + dy,
            z: point.z,
          );
        }(),
    ],
    // Mirroring a right hand produces a left one.
    handedness: mirror ? Handedness.left : hand.handedness,
    score: hand.score,
  );
}
