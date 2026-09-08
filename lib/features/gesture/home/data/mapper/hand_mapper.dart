import '../../../../../core/ml/geometry.dart';
import '../../domain/entity/hand_entity.dart';
import '../../domain/entity/hand_landmark_entity.dart';
import '../model/hand_landmark_model.dart';

/// Lifts landmark model output out of its crop and into frame space.
abstract final class HandMapper {
  /// Above this the `lr` head is read as the right hand.
  static const _rightHandThreshold = 0.5;

  /// How confident the `lr` head must be before we name a hand at all.
  static const _handednessMargin = 0.1;

  static HandEntity toEntity({
    required HandLandmarkModel model,
    required RotatedRect roi,
    required double aspectRatio,
    required bool mirrored,
  }) {
    final landmarks = <HandLandmarkEntity>[];

    for (final (x, y, z) in model.landmarks) {
      final (frameX, frameY) = roi.toImageSpace(x, y, aspectRatio);
      landmarks.add(HandLandmarkEntity(x: frameX, y: frameY, z: z * roi.width));
    }

    return HandEntity(
      landmarks: landmarks,
      handedness: _handedness(model.handednessScore, mirrored: mirrored),
      score: model.score,
    );
  }

  /// A mirrored preview swaps left and right: the hand on the right of a
  /// selfie view is the user's left hand.
  static Handedness _handedness(double score, {required bool mirrored}) {
    if ((score - _rightHandThreshold).abs() < _handednessMargin) {
      return Handedness.unknown;
    }

    final isRight = score > _rightHandThreshold;
    return (isRight != mirrored) ? Handedness.right : Handedness.left;
  }
}
