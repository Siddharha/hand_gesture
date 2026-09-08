import 'hand_landmark_entity.dart';

enum Handedness { left, right, unknown }

/// One tracked hand: its 21 landmarks, which hand it is, and how confident the
/// landmark model was.
class HandEntity {
  const HandEntity({
    required this.landmarks,
    required this.handedness,
    required this.score,
  });

  /// Exactly 21 entries, indexed by [HandLandmarkType].
  final List<HandLandmarkEntity> landmarks;
  final Handedness handedness;

  /// Presence confidence in `[0, 1]`.
  final double score;

  HandLandmarkEntity landmark(HandLandmarkType type) => landmarks[type.index];

  /// Tight bounds around the landmarks, normalised like them.
  ({double left, double top, double right, double bottom}) get bounds {
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;

    for (final landmark in landmarks) {
      if (landmark.x < left) left = landmark.x;
      if (landmark.x > right) right = landmark.x;
      if (landmark.y < top) top = landmark.y;
      if (landmark.y > bottom) bottom = landmark.y;
    }

    return (left: left, top: top, right: right, bottom: bottom);
  }
}
