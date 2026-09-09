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
/// State is kept per hand slot, so two hands are admitted independently.
class HandStructureGate {
  HandStructureGate({this.framesToTrust = 4})
      : assert(framesToTrust >= 1, 'a hand has to be seen at least once');

  /// Consecutive structurally valid frames a hand owes before it is read.
  final int framesToTrust;

  /// Valid frames each slot has run up, reset to zero by any invalid one.
  final List<int> _streaks = [];

  /// Takes this frame's per-hand structural verdicts and returns, index
  /// aligned, which hands have now earned a gesture.
  List<bool> admit(List<bool> valid) {
    // A hand that went away takes its streak with it; reusing the slot for a
    // different hand would let one hand vouch for another.
    if (_streaks.length > valid.length) {
      _streaks.removeRange(valid.length, _streaks.length);
    }

    final trusted = <bool>[];
    for (var i = 0; i < valid.length; i++) {
      if (i >= _streaks.length) _streaks.add(0);

      _streaks[i] = valid[i] ? _streaks[i] + 1 : 0;
      trusted.add(_streaks[i] >= framesToTrust);
    }

    return trusted;
  }

  void reset() => _streaks.clear();
}
