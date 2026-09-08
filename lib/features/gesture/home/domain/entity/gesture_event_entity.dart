import 'hand_entity.dart';
import 'hand_gesture_entity.dart';

enum GestureEventType {
  /// A hand has started making this shape.
  began,

  /// It has stopped — the shape changed, or the hand left the frame.
  ended,
}

/// A change in what a hand is doing.
///
/// Emitted on transitions only, not per frame: a shape held for two seconds
/// produces one [GestureEventType.began] and one [GestureEventType.ended], so
/// an action fires once rather than sixty times. The per-frame view of the same
/// data is `HomeState.poses`, for anything that wants to track continuously.
class GestureEventEntity {
  const GestureEventEntity({
    required this.type,
    required this.pose,
    required this.handedness,
    required this.handIndex,
    required this.at,
    this.heldFor = Duration.zero,
  });

  final GestureEventType type;
  final HandPoseEntity pose;
  final Handedness handedness;

  /// Which tracked hand this is, stable while that hand stays in frame.
  final int handIndex;

  final DateTime at;

  /// How long the shape was held. Zero on [GestureEventType.began]; on `ended`
  /// it is the full duration, which is what "hold to confirm" actions need.
  final Duration heldFor;

  HandGesture get gesture => pose.gesture;

  bool get isBegan => type == GestureEventType.began;

  bool get isEnded => type == GestureEventType.ended;

  /// Whether this is a shape the recogniser could name, as opposed to a bare
  /// finger count. Actions usually want to filter on this.
  bool get isNamed => pose.gesture != HandGesture.unknown;

  @override
  String toString() => '${type.name} ${pose.label} '
      '(hand $handIndex${heldFor > Duration.zero ? ', held ${heldFor.inMilliseconds}ms' : ''})';
}
