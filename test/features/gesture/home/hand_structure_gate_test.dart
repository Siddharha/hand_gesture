import 'package:flutter_test/flutter_test.dart';

import 'package:hand_gesture/features/gesture/home/presentation/viewmodel/hand_structure_gate.dart';

/// A structurally sound frame, with the confidence the model reported for it.
HandFrameCheck ok([double confidence = 0.9]) =>
    (isValid: true, confidence: confidence);

/// A frame whose skeleton did not hold up. Its confidence is deliberately high:
/// a broken hand the model feels good about is exactly the case the gate is
/// there for.
HandFrameCheck bad([double confidence = 0.99]) =>
    (isValid: false, confidence: confidence);

void main() {
  group('a single hand', () {
    test('is withheld until it has been sound for the full run of frames', () {
      final gate = HandStructureGate(framesToTrust: 4);

      expect(gate.admit([ok()]), [null]);
      expect(gate.admit([ok()]), [null]);
      expect(gate.admit([ok()]), [null]);
      expect(gate.admit([ok()]), [0.9]);
    });

    test('reports the confidence of the frame that completed the run', () {
      final gate = HandStructureGate(framesToTrust: 3);

      gate.admit([ok(0.61)]);
      gate.admit([ok(0.72)]);

      // The third frame is the one the decision is made on.
      expect(gate.admit([ok(0.84)]), [0.84]);
    });

    test('later frames keep the deciding number rather than replacing it', () {
      final gate = HandStructureGate(framesToTrust: 2);

      gate.admit([ok(0.55)]);
      expect(gate.admit([ok(0.80)]), [0.80]);

      // The hand is still held; the reading it was admitted on stands.
      expect(gate.admit([ok(0.42)]), [0.80]);
      expect(gate.admit([ok(0.97)]), [0.80]);
    });

    test('one bad frame costs the whole run, not one frame', () {
      final gate = HandStructureGate(framesToTrust: 3);

      gate.admit([ok()]);
      gate.admit([ok()]);
      expect(gate.admit([ok()]), [0.9]);

      expect(gate.admit([bad()]), [null]);
      expect(gate.admit([ok()]), [null]);
      expect(gate.admit([ok()]), [null]);
      expect(gate.admit([ok()]), [0.9]);
    });

    test('re-earning trust reports the new deciding frame', () {
      final gate = HandStructureGate(framesToTrust: 2);

      gate.admit([ok(0.70)]);
      expect(gate.admit([ok(0.75)]), [0.75]);

      gate.admit([bad()]);
      gate.admit([ok(0.30)]);
      expect(gate.admit([ok(0.35)]), [0.35]);
    });

    test('a hand that never settles is never admitted', () {
      final gate = HandStructureGate(framesToTrust: 3);

      for (var i = 0; i < 10; i++) {
        expect(gate.admit([i.isEven ? ok() : bad()]), [null]);
      }
    });

    test('one frame is enough when that is all that is asked', () {
      final gate = HandStructureGate(framesToTrust: 1);

      expect(gate.admit([ok(0.66)]), [0.66]);
    });
  });

  group('two hands', () {
    test('earn their place separately, each with its own number', () {
      final gate = HandStructureGate(framesToTrust: 3);

      expect(gate.admit([ok(0.5), bad()]), [null, null]);
      expect(gate.admit([ok(0.6), ok(0.6)]), [null, null]);
      expect(gate.admit([ok(0.7), ok(0.8)]), [0.7, null]);
      expect(gate.admit([ok(0.4), ok(0.9)]), [0.7, 0.9]);
    });

    test('one going bad does not unseat the other', () {
      final gate = HandStructureGate(framesToTrust: 2);

      gate.admit([ok(0.8), ok(0.7)]);
      expect(gate.admit([ok(0.8), ok(0.7)]), [0.8, 0.7]);
      expect(gate.admit([bad(), ok(0.6)]), [null, 0.7]);
    });
  });

  group('hands coming and going', () {
    test('a slot that empties does not vouch for whoever fills it next', () {
      final gate = HandStructureGate(framesToTrust: 3);

      gate.admit([ok(0.8), ok(0.8)]);
      gate.admit([ok(0.8), ok(0.8)]);
      expect(gate.admit([ok(0.8), ok(0.8)]), [0.8, 0.8]);

      // The second hand leaves, then a different one arrives in its slot.
      expect(gate.admit([ok(0.8)]), [0.8]);
      expect(gate.admit([ok(0.8), ok(0.95)]), [0.8, null]);
    });

    test('no hands at all admits nothing and complains about nothing', () {
      final gate = HandStructureGate(framesToTrust: 2);

      gate.admit([ok()]);
      expect(gate.admit(const []), isEmpty);
      expect(gate.admit([ok()]), [null]);
    });

    test('reset puts every hand back to owing the full run', () {
      final gate = HandStructureGate(framesToTrust: 2);

      gate.admit([ok(0.6)]);
      expect(gate.admit([ok(0.7)]), [0.7]);

      gate.reset();
      expect(gate.admit([ok(0.8)]), [null]);
      expect(gate.admit([ok(0.9)]), [0.9]);
    });
  });
}
