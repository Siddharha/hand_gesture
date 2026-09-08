import 'dart:math' as math;

import '../../../../../core/usecase/usecase.dart';
import '../entity/hand_entity.dart';
import '../entity/hand_gesture_entity.dart';
import '../entity/hand_landmark_entity.dart';

class RecognizeHandGestureParams {
  const RecognizeHandGestureParams({
    required this.hand,
    required this.frameAspectRatio,
  });

  final HandEntity hand;

  /// Landmarks are normalised to frame width and height separately, so a step
  /// of 0.1 is a different number of pixels on each axis. Distances are only
  /// comparable once that is undone.
  final double frameAspectRatio;
}

/// Names the shape a hand is making, from its landmarks alone.
///
/// Everything here is a ratio between distances, so it holds regardless of how
/// big the hand is, how far away it is, or which way it is rotated — no
/// thresholds in pixels, and no assumption that the hand is upright.
class RecognizeHandGestureUseCase
    implements SyncUseCase<HandPoseEntity, RecognizeHandGestureParams> {
  const RecognizeHandGestureUseCase();

  /// A finger counts as extended when the straight-line distance from knuckle
  /// to tip is at least this share of the distance travelled along the finger.
  /// A straight finger scores 1.0; a curled one drops well below.
  static const _straightnessThreshold = 0.80;

  /// The thumb barely curls — it folds *across* the palm instead, so it is
  /// judged by how far the tip sits from the far side of the hand compared to
  /// its own knuckle. Tucked, the tip moves inward and the ratio falls below 1.
  static const _thumbReachRatio = 1.1;

  /// How close the thumb and index tips must be, relative to palm width, to
  /// read as a deliberate pinch.
  static const _pinchDistance = 0.45;

  @override
  HandPoseEntity call(RecognizeHandGestureParams params) {
    final hand = params.hand;
    if (hand.landmarks.length != HandLandmarkType.values.length) {
      return const HandPoseEntity.unknown();
    }

    final aspect = params.frameAspectRatio;
    final extended = <Finger>{};

    if (_isThumbExtended(hand, aspect)) extended.add(Finger.thumb);
    if (_isFingerExtended(hand, Finger.indexFinger, aspect)) {
      extended.add(Finger.indexFinger);
    }
    if (_isFingerExtended(hand, Finger.middle, aspect)) extended.add(Finger.middle);
    if (_isFingerExtended(hand, Finger.ring, aspect)) extended.add(Finger.ring);
    if (_isFingerExtended(hand, Finger.pinky, aspect)) extended.add(Finger.pinky);

    return HandPoseEntity(
      gesture: _classify(hand, extended, aspect),
      extendedFingers: extended,
    );
  }

  HandGesture _classify(HandEntity hand, Set<Finger> extended, double aspect) {
    // The OK sign is not a finger-count pattern: the index curls to meet the
    // thumb, so it has to be checked before the patterns below would call it
    // "three".
    if (_isOkSign(hand, extended, aspect)) return HandGesture.ok;

    final thumb = extended.contains(Finger.thumb);
    final index = extended.contains(Finger.indexFinger);
    final middle = extended.contains(Finger.middle);
    final ring = extended.contains(Finger.ring);
    final pinky = extended.contains(Finger.pinky);

    return switch ((thumb, index, middle, ring, pinky)) {
      (false, false, false, false, false) => HandGesture.fist,
      // A lone thumb points somewhere, and which way changes the meaning.
      (true, false, false, false, false) =>
        _isThumbAbove(hand) ? HandGesture.thumbsUp : HandGesture.thumbsDown,
      (false, true, false, false, false) => HandGesture.one,
      (false, true, true, false, false) => HandGesture.two,
      (false, true, true, true, false) => HandGesture.three,
      (true, true, true, false, false) => HandGesture.three,
      (false, true, true, true, true) => HandGesture.four,
      (true, true, true, true, true) => HandGesture.openPalm,
      (false, true, false, false, true) => HandGesture.rockOn,
      (true, false, false, false, true) => HandGesture.shaka,
      (true, true, false, false, false) => HandGesture.gun,
      _ => HandGesture.unknown,
    };
  }

  bool _isFingerExtended(HandEntity hand, Finger finger, double aspect) {
    final (mcp, pip, dip, tip) = _jointsOf(finger);

    final travelled = _distance(hand, mcp, pip, aspect) +
        _distance(hand, pip, dip, aspect) +
        _distance(hand, dip, tip, aspect);
    if (travelled <= 0) return false;

    return _distance(hand, mcp, tip, aspect) / travelled >= _straightnessThreshold;
  }

  bool _isThumbExtended(HandEntity hand, double aspect) {
    // Measured against the pinky knuckle: the far side of the palm is a stable
    // reference whichever way the hand is turned.
    final tipReach = _distance(
      hand,
      HandLandmarkType.thumbTip,
      HandLandmarkType.pinkyMcp,
      aspect,
    );
    final knuckleReach = _distance(
      hand,
      HandLandmarkType.thumbMcp,
      HandLandmarkType.pinkyMcp,
      aspect,
    );
    if (knuckleReach <= 0) return false;

    return tipReach / knuckleReach >= _thumbReachRatio;
  }

  bool _isOkSign(HandEntity hand, Set<Finger> extended, double aspect) {
    final ringOut = extended.contains(Finger.ring);
    final middleOut = extended.contains(Finger.middle);
    final pinkyOut = extended.contains(Finger.pinky);
    final indexOut = extended.contains(Finger.indexFinger);

    if (!middleOut || !ringOut || !pinkyOut || indexOut) return false;

    final palmWidth = _distance(
      hand,
      HandLandmarkType.indexMcp,
      HandLandmarkType.pinkyMcp,
      aspect,
    );
    if (palmWidth <= 0) return false;

    final pinch = _distance(
      hand,
      HandLandmarkType.thumbTip,
      HandLandmarkType.indexTip,
      aspect,
    );
    return pinch / palmWidth <= _pinchDistance;
  }

  /// Whether the thumb points up the screen. Frame coordinates put y at the
  /// top, so "above" is a smaller y than the wrist.
  bool _isThumbAbove(HandEntity hand) =>
      hand.landmark(HandLandmarkType.thumbTip).y <
      hand.landmark(HandLandmarkType.wrist).y;

  double _distance(
    HandEntity hand,
    HandLandmarkType a,
    HandLandmarkType b,
    double aspect,
  ) {
    final first = hand.landmark(a);
    final second = hand.landmark(b);
    // Back into a square space, so x and y are the same unit.
    final dx = (first.x - second.x) * aspect;
    final dy = first.y - second.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  (HandLandmarkType, HandLandmarkType, HandLandmarkType, HandLandmarkType) _jointsOf(
    Finger finger,
  ) {
    return switch (finger) {
      Finger.indexFinger => (
          HandLandmarkType.indexMcp,
          HandLandmarkType.indexPip,
          HandLandmarkType.indexDip,
          HandLandmarkType.indexTip,
        ),
      Finger.middle => (
          HandLandmarkType.middleMcp,
          HandLandmarkType.middlePip,
          HandLandmarkType.middleDip,
          HandLandmarkType.middleTip,
        ),
      Finger.ring => (
          HandLandmarkType.ringMcp,
          HandLandmarkType.ringPip,
          HandLandmarkType.ringDip,
          HandLandmarkType.ringTip,
        ),
      Finger.pinky => (
          HandLandmarkType.pinkyMcp,
          HandLandmarkType.pinkyPip,
          HandLandmarkType.pinkyDip,
          HandLandmarkType.pinkyTip,
        ),
      Finger.thumb => (
          HandLandmarkType.thumbCmc,
          HandLandmarkType.thumbMcp,
          HandLandmarkType.thumbIp,
          HandLandmarkType.thumbTip,
        ),
    };
  }
}
