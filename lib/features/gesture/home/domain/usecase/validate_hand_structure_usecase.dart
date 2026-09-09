import 'dart:math' as math;

import '../../../../../core/usecase/usecase.dart';
import '../entity/hand_entity.dart';
import '../entity/hand_landmark_entity.dart';

class ValidateHandStructureParams {
  const ValidateHandStructureParams({
    required this.hand,
    required this.frameAspectRatio,
  });

  final HandEntity hand;

  /// Landmarks are normalised to frame width and height separately, so
  /// distances are only comparable once that is undone.
  final double frameAspectRatio;
}

/// Says whether a set of landmarks could actually be a hand.
///
/// The landmark model always returns 21 points, whatever it was shown: a
/// half-occluded hand, a face, or the tail of a hand that has already left the
/// frame all come back as a confident-looking skeleton with joints in
/// impossible places. Naming a gesture from one of those produces a wrong
/// answer rather than no answer, so the shape is sanity-checked first.
///
/// Every test is either scale-free or measured against the palm, so a hand
/// keeps passing as it moves nearer, further, or turns. The checks are
/// deliberately one-sided wherever the camera can only shorten a distance: a
/// hand tilted away from the lens foreshortens, and a real hand squashed flat
/// by perspective must not be mistaken for a broken one.
class ValidateHandStructureUseCase
    implements SyncUseCase<bool, ValidateHandStructureParams> {
  const ValidateHandStructureUseCase();

  /// Below this the palm has collapsed to a point and every ratio below it is
  /// meaningless — nothing that small is a hand worth reading.
  static const _minPalmLength = 0.01;

  /// Landmarks may sit a little outside the frame — the model extrapolates a
  /// hand running off the edge — but not in another postcode.
  static const _boundsMargin = 0.5;

  /// No single bone reaches further than this share of the palm. The longest
  /// real one is roughly the palm itself.
  static const _maxBoneToPalm = 1.6;

  /// Knuckle to fingertip along the joints, at full stretch, against the palm.
  static const _maxFingerToPalm = 2.6;

  /// Wrist to fingertip. Even a long middle finger on a splayed hand stays
  /// well inside this.
  static const _maxReachToPalm = 3.4;

  /// The knuckles are only laid out across the palm in a view that shows the
  /// back or the front of the hand. Edge on they pile up on top of each other
  /// and their order says nothing, so below this share of the palm the
  /// ordering check is skipped rather than failed.
  static const _minKnuckleSpanToPalm = 0.25;

  /// How far a knuckle may sit off the line from the index knuckle to the
  /// pinky one, as a share of that span. Fingers bend at the joints beyond
  /// them, so these four stay close to a line whatever the hand is doing.
  static const _maxKnuckleDeviation = 0.55;

  /// The fingers, knuckle to tip.
  static const _fingerChains = <List<HandLandmarkType>>[
    [
      HandLandmarkType.indexMcp,
      HandLandmarkType.indexPip,
      HandLandmarkType.indexDip,
      HandLandmarkType.indexTip,
    ],
    [
      HandLandmarkType.middleMcp,
      HandLandmarkType.middlePip,
      HandLandmarkType.middleDip,
      HandLandmarkType.middleTip,
    ],
    [
      HandLandmarkType.ringMcp,
      HandLandmarkType.ringPip,
      HandLandmarkType.ringDip,
      HandLandmarkType.ringTip,
    ],
    [
      HandLandmarkType.pinkyMcp,
      HandLandmarkType.pinkyPip,
      HandLandmarkType.pinkyDip,
      HandLandmarkType.pinkyTip,
    ],
    [
      HandLandmarkType.thumbCmc,
      HandLandmarkType.thumbMcp,
      HandLandmarkType.thumbIp,
      HandLandmarkType.thumbTip,
    ],
  ];

  /// The four finger knuckles, in the order they cross the palm.
  static const _knuckles = <HandLandmarkType>[
    HandLandmarkType.indexMcp,
    HandLandmarkType.middleMcp,
    HandLandmarkType.ringMcp,
    HandLandmarkType.pinkyMcp,
  ];

  @override
  bool call(ValidateHandStructureParams params) {
    final hand = params.hand;
    if (hand.landmarks.length != HandLandmarkType.values.length) return false;

    final aspect = params.frameAspectRatio;
    if (!aspect.isFinite || aspect <= 0) return false;
    if (!_isOnScreen(hand)) return false;

    final palm = _distance(
      hand,
      HandLandmarkType.wrist,
      HandLandmarkType.middleMcp,
      aspect,
    );
    if (!palm.isFinite || palm < _minPalmLength) return false;

    if (!_bonesArePlausible(hand, palm, aspect)) return false;
    if (!_fingersArePlausible(hand, palm, aspect)) return false;

    return _knucklesAreOrdered(hand, palm, aspect);
  }

  /// Every coordinate is a real number, and near enough the frame to have come
  /// from it.
  bool _isOnScreen(HandEntity hand) {
    for (final landmark in hand.landmarks) {
      if (!landmark.x.isFinite || !landmark.y.isFinite || !landmark.z.isFinite) {
        return false;
      }
      if (landmark.x < -_boundsMargin || landmark.x > 1 + _boundsMargin) {
        return false;
      }
      if (landmark.y < -_boundsMargin || landmark.y > 1 + _boundsMargin) {
        return false;
      }
    }
    return true;
  }

  /// No bone longer than a hand has. Catches the skeleton that has come apart,
  /// where one joint is flung across the frame while the rest stays put.
  bool _bonesArePlausible(HandEntity hand, double palm, double aspect) {
    final limit = palm * _maxBoneToPalm;
    for (final (from, to) in handSkeletonConnections) {
      if (_distance(hand, from, to, aspect) > limit) return false;
    }
    return true;
  }

  /// Each finger is no longer than a finger, measured along its joints, and no
  /// fingertip sits further from the wrist than a finger can reach.
  bool _fingersArePlausible(HandEntity hand, double palm, double aspect) {
    final fingerLimit = palm * _maxFingerToPalm;
    final reachLimit = palm * _maxReachToPalm;

    for (final chain in _fingerChains) {
      var travelled = 0.0;
      for (var i = 0; i + 1 < chain.length; i++) {
        travelled += _distance(hand, chain[i], chain[i + 1], aspect);
      }
      if (travelled > fingerLimit) return false;

      if (_distance(hand, HandLandmarkType.wrist, chain.last, aspect) >
          reachLimit) {
        return false;
      }
    }
    return true;
  }

  /// The four knuckles run across the palm in order and stay near a line.
  ///
  /// This is the check that rejects a plausible-looking but scrambled hand:
  /// fingers bend, so tips go anywhere, but the knuckles are held in a row by
  /// the palm behind them and cannot swap places.
  bool _knucklesAreOrdered(HandEntity hand, double palm, double aspect) {
    final index = hand.landmark(HandLandmarkType.indexMcp);
    final pinky = hand.landmark(HandLandmarkType.pinkyMcp);

    final axisX = (pinky.x - index.x) * aspect;
    final axisY = pinky.y - index.y;
    final span = math.sqrt(axisX * axisX + axisY * axisY);

    // Seen edge on, the knuckles overlap and their order carries no
    // information. Unreadable is not the same as wrong.
    if (span < palm * _minKnuckleSpanToPalm) return true;

    var previous = double.negativeInfinity;
    for (final knuckle in _knuckles) {
      final point = hand.landmark(knuckle);
      final dx = (point.x - index.x) * aspect;
      final dy = point.y - index.y;

      // How far along the index-to-pinky line the knuckle sits, and how far
      // off it.
      final along = (dx * axisX + dy * axisY) / span;
      final across = (dx * axisY - dy * axisX).abs() / span;

      if (across > span * _maxKnuckleDeviation) return false;
      if (along <= previous) return false;
      previous = along;
    }

    return true;
  }

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
}
