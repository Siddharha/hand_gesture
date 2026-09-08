import '../../domain/entity/hand_gesture_entity.dart';

/// Holds a gesture until a new one has been seen consistently.
///
/// Raw per-frame classification flickers: at ~26fps a finger crossing the
/// extended/curled threshold flips the label several times a second, and a
/// label that changes faster than it can be read is worse than a slightly late
/// one. A new shape has to hold for [framesToConfirm] frames before it is
/// shown, which costs about a tenth of a second and removes the noise.
///
/// State is kept per hand slot, so two hands are smoothed independently.
class GestureStabilizer {
  GestureStabilizer({this.framesToConfirm = 3});

  final int framesToConfirm;
  final List<_Slot> _slots = [];

  /// Returns the poses to display, given this frame's raw classifications.
  List<HandPoseEntity> stabilize(List<HandPoseEntity> poses) {
    // A hand that went away takes its history with it; reusing the slot for a
    // different hand would smear one hand's gesture onto another.
    if (_slots.length > poses.length) {
      _slots.removeRange(poses.length, _slots.length);
    }

    final stable = <HandPoseEntity>[];
    for (var i = 0; i < poses.length; i++) {
      if (i >= _slots.length) {
        // First sight of this hand: show it straight away rather than making
        // the user wait for confirmation of something that was never wrong.
        _slots.add(_Slot(poses[i]));
        stable.add(poses[i]);
        continue;
      }

      stable.add(_slots[i].update(poses[i], framesToConfirm));
    }

    return stable;
  }

  void reset() => _slots.clear();
}

class _Slot {
  _Slot(this.reported);

  HandPoseEntity reported;
  HandPoseEntity? candidate;
  int candidateFrames = 0;

  HandPoseEntity update(HandPoseEntity pose, int framesToConfirm) {
    if (pose == reported) {
      candidate = null;
      candidateFrames = 0;
      return reported;
    }

    if (pose == candidate) {
      candidateFrames++;
      if (candidateFrames >= framesToConfirm) {
        reported = pose;
        candidate = null;
        candidateFrames = 0;
      }
    } else {
      candidate = pose;
      candidateFrames = 1;
    }

    return reported;
  }
}
