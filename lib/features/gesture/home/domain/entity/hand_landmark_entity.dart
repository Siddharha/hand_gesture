/// The 21 hand landmarks MediaPipe returns, in the order the model emits them.
enum HandLandmarkType {
  wrist,
  thumbCmc,
  thumbMcp,
  thumbIp,
  thumbTip,
  indexMcp,
  indexPip,
  indexDip,
  indexTip,
  middleMcp,
  middlePip,
  middleDip,
  middleTip,
  ringMcp,
  ringPip,
  ringDip,
  ringTip,
  pinkyMcp,
  pinkyPip,
  pinkyDip,
  pinkyTip;

  /// The fingertips, in thumb-to-pinky order.
  static const tips = [thumbTip, indexTip, middleTip, ringTip, pinkyTip];
}

/// A single landmark, normalised to the frame as the user sees it.
///
/// [x] and [y] are in `[0, 1]` (left-to-right, top-to-bottom). [z] is depth
/// relative to the wrist in the same units as [x] — negative is toward the
/// camera — and is far less accurate than the other two.
class HandLandmarkEntity {
  const HandLandmarkEntity({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HandLandmarkEntity && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

/// Bones of the hand skeleton, as index pairs into a hand's landmark list.
/// Used to draw the hand and to reason about finger poses.
const handSkeletonConnections = <(HandLandmarkType, HandLandmarkType)>[
  // Thumb.
  (HandLandmarkType.wrist, HandLandmarkType.thumbCmc),
  (HandLandmarkType.thumbCmc, HandLandmarkType.thumbMcp),
  (HandLandmarkType.thumbMcp, HandLandmarkType.thumbIp),
  (HandLandmarkType.thumbIp, HandLandmarkType.thumbTip),
  // Index.
  (HandLandmarkType.wrist, HandLandmarkType.indexMcp),
  (HandLandmarkType.indexMcp, HandLandmarkType.indexPip),
  (HandLandmarkType.indexPip, HandLandmarkType.indexDip),
  (HandLandmarkType.indexDip, HandLandmarkType.indexTip),
  // Middle.
  (HandLandmarkType.indexMcp, HandLandmarkType.middleMcp),
  (HandLandmarkType.middleMcp, HandLandmarkType.middlePip),
  (HandLandmarkType.middlePip, HandLandmarkType.middleDip),
  (HandLandmarkType.middleDip, HandLandmarkType.middleTip),
  // Ring.
  (HandLandmarkType.middleMcp, HandLandmarkType.ringMcp),
  (HandLandmarkType.ringMcp, HandLandmarkType.ringPip),
  (HandLandmarkType.ringPip, HandLandmarkType.ringDip),
  (HandLandmarkType.ringDip, HandLandmarkType.ringTip),
  // Pinky and palm edge.
  (HandLandmarkType.ringMcp, HandLandmarkType.pinkyMcp),
  (HandLandmarkType.pinkyMcp, HandLandmarkType.pinkyPip),
  (HandLandmarkType.pinkyPip, HandLandmarkType.pinkyDip),
  (HandLandmarkType.pinkyDip, HandLandmarkType.pinkyTip),
  (HandLandmarkType.wrist, HandLandmarkType.pinkyMcp),
];
