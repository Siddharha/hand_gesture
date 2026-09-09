import '../../domain/entity/gesture_event_entity.dart';
import '../../domain/entity/hand_entity.dart';
import '../../domain/entity/hand_gesture_entity.dart';

/// Turns a per-frame stream of poses into begin/end events.
///
/// Feed it the *stabilised* poses: it emits on every change it is shown, so
/// running it on raw classifications would fire several times a second as a
/// finger hovers on a threshold.
///
/// A `null` in place of a pose means the hand is not to be read this frame —
/// its structure has not held together long enough to be trusted. Nothing
/// begins on a slot like that, and anything already in flight there ends, so a
/// listener never acts on a hand the tracker is unsure of.
///
/// State is per hand slot, so two hands raise and drop gestures independently.
class GestureEventTracker {
  /// One entry per hand slot; `null` where the slot holds no gesture.
  final List<_Active?> _active = [];

  /// Compares this frame against the last and returns what changed.
  List<GestureEventEntity> update(
    List<HandEntity> hands,
    List<HandPoseEntity?> poses,
  ) {
    final now = DateTime.now();
    final events = <GestureEventEntity>[];
    final count = hands.length < poses.length ? hands.length : poses.length;

    for (var i = 0; i < count; i++) {
      if (i >= _active.length) _active.add(null);

      final pose = poses[i];
      final active = _active[i];

      // Withheld: end what was held, and start nothing.
      if (pose == null) {
        if (active != null) {
          events.add(_ended(active, i, now));
          _active[i] = null;
        }
        continue;
      }

      if (active == null) {
        _active[i] = _Active(pose, hands[i].handedness, now);
        events.add(_began(pose, hands[i].handedness, i, now));
        continue;
      }

      if (active.pose == pose) continue;

      // A change is an end and a start, in that order, so a listener that
      // reacts to `ended` sees the old shape before the new one arrives.
      events
        ..add(_ended(active, i, now))
        ..add(_began(pose, hands[i].handedness, i, now));
      _active[i] = _Active(pose, hands[i].handedness, now);
    }

    // Hands that left the frame end whatever they were holding, otherwise a
    // listener waiting for `ended` would wait forever.
    for (var i = _active.length - 1; i >= count; i--) {
      final active = _active[i];
      if (active != null) events.add(_ended(active, i, now));
      _active.removeAt(i);
    }

    return events;
  }

  /// Ends everything in flight — for stopping the camera or switching lens,
  /// where gestures do not carry over.
  List<GestureEventEntity> reset() {
    final now = DateTime.now();
    final events = <GestureEventEntity>[];
    for (var i = 0; i < _active.length; i++) {
      final active = _active[i];
      if (active != null) events.add(_ended(active, i, now));
    }
    _active.clear();
    return events;
  }

  GestureEventEntity _began(
    HandPoseEntity pose,
    Handedness handedness,
    int index,
    DateTime now,
  ) {
    return GestureEventEntity(
      type: GestureEventType.began,
      pose: pose,
      handedness: handedness,
      handIndex: index,
      at: now,
    );
  }

  GestureEventEntity _ended(_Active active, int index, DateTime now) {
    return GestureEventEntity(
      type: GestureEventType.ended,
      pose: active.pose,
      handedness: active.handedness,
      handIndex: index,
      at: now,
      heldFor: now.difference(active.since),
    );
  }
}

class _Active {
  const _Active(this.pose, this.handedness, this.since);

  final HandPoseEntity pose;
  final Handedness handedness;
  final DateTime since;
}
