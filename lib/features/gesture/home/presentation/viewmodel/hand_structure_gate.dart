/// One hand's structural verdict for a single frame, and how confident the
/// model was about it.
typedef HandFrameCheck = ({bool isValid, double confidence});

/// Withholds a hand until its skeleton has been structurally sound several
/// frames running.
///
/// One good frame is not evidence: the landmark model recovers from a bad ROI
/// within a frame or two, so a single valid-looking skeleton is as likely to be
/// luck as a hand. Requiring [framesToTrust] in a row means a gesture is only
/// ever named from a hand the tracker has actually held on to — at ~26fps the
/// wait costs on the order of a tenth of a second, and it is paid once when the
/// hand appears rather than on every gesture.
///
/// One bad frame breaks the run. Recovering after that costs the full wait
/// again, which is the point: a hand that flickers in and out of validity is
/// exactly the hand whose gestures should not be believed.
///
/// The confidence handed back is the one from the frame that *completed* the
/// run — the frame the decision was actually made on. Later frames keep that
/// number rather than replacing it, so what is reported is the evidence the
/// hand was admitted on, and it holds still long enough to be read instead of
/// twitching every frame.
///
/// State is kept per hand slot, so two hands are admitted independently.
class HandStructureGate {
  HandStructureGate({this.framesToTrust = 4})
      : assert(framesToTrust >= 1, 'a hand has to be seen at least once');

  /// Consecutive structurally valid frames a hand owes before it is read.
  final int framesToTrust;

  final List<_Slot> _slots = [];

  /// Takes this frame's per-hand checks and returns, index aligned, the
  /// confidence each hand was admitted on — or `null` where it has not earned
  /// a gesture yet.
  List<double?> admit(List<HandFrameCheck> frame) {
    // A hand that went away takes its streak with it; reusing the slot for a
    // different hand would let one hand vouch for another.
    if (_slots.length > frame.length) {
      _slots.removeRange(frame.length, _slots.length);
    }

    final admitted = <double?>[];
    for (var i = 0; i < frame.length; i++) {
      if (i >= _slots.length) _slots.add(_Slot());

      admitted.add(_slots[i].update(frame[i], framesToTrust));
    }

    return admitted;
  }

  void reset() => _slots.clear();
}

class _Slot {
  /// Valid frames run up so far, back to zero on any invalid one.
  int streak = 0;

  /// The confidence from the frame that admitted this hand, kept until the
  /// run breaks and has to be earned again.
  double? admittedOn;

  double? update(HandFrameCheck check, int framesToTrust) {
    if (!check.isValid) {
      streak = 0;
      admittedOn = null;
      return null;
    }

    streak++;
    if (streak < framesToTrust) return null;

    // Only the frame that completes the run writes this; every frame after it
    // reports the same decision.
    admittedOn ??= check.confidence;
    return admittedOn;
  }
}
