import 'package:flutter_test/flutter_test.dart';

import 'package:hand_gesture/features/gesture/home/presentation/viewmodel/hand_structure_gate.dart';

void main() {
  group('a single hand', () {
    test('is withheld until it has been sound for the full run of frames', () {
      final gate = HandStructureGate(framesToTrust: 4);

      expect(gate.admit([true]), [false]);
      expect(gate.admit([true]), [false]);
      expect(gate.admit([true]), [false]);
      expect(gate.admit([true]), [true]);
    });

    test('stays trusted for as long as it stays sound', () {
      final gate = HandStructureGate(framesToTrust: 3);

      for (var i = 0; i < 2; i++) {
        gate.admit([true]);
      }
      expect(gate.admit([true]), [true]);
      expect(gate.admit([true]), [true]);
      expect(gate.admit([true]), [true]);
    });

    test('one bad frame costs the whole run, not one frame', () {
      final gate = HandStructureGate(framesToTrust: 3);

      gate.admit([true]);
      gate.admit([true]);
      expect(gate.admit([true]), [true]);

      expect(gate.admit([false]), [false]);
      expect(gate.admit([true]), [false]);
      expect(gate.admit([true]), [false]);
      expect(gate.admit([true]), [true]);
    });

    test('a hand that never settles is never admitted', () {
      final gate = HandStructureGate(framesToTrust: 3);

      for (var i = 0; i < 10; i++) {
        expect(gate.admit([i.isEven]), [false]);
      }
    });

    test('one frame is enough when that is all that is asked', () {
      final gate = HandStructureGate(framesToTrust: 1);

      expect(gate.admit([true]), [true]);
    });
  });

  group('two hands', () {
    test('earn their place separately', () {
      final gate = HandStructureGate(framesToTrust: 3);

      expect(gate.admit([true, false]), [false, false]);
      expect(gate.admit([true, true]), [false, false]);
      expect(gate.admit([true, true]), [true, false]);
      expect(gate.admit([true, true]), [true, true]);
    });

    test('one going bad does not unseat the other', () {
      final gate = HandStructureGate(framesToTrust: 2);

      gate.admit([true, true]);
      expect(gate.admit([true, true]), [true, true]);
      expect(gate.admit([false, true]), [false, true]);
    });
  });

  group('hands coming and going', () {
    test('a slot that empties does not vouch for whoever fills it next', () {
      final gate = HandStructureGate(framesToTrust: 3);

      gate.admit([true, true]);
      gate.admit([true, true]);
      expect(gate.admit([true, true]), [true, true]);

      // The second hand leaves, then a different one arrives in its slot.
      expect(gate.admit([true]), [true]);
      expect(gate.admit([true, true]), [true, false]);
    });

    test('no hands at all admits nothing and complains about nothing', () {
      final gate = HandStructureGate(framesToTrust: 2);

      gate.admit([true]);
      expect(gate.admit(const []), isEmpty);
      expect(gate.admit([true]), [false]);
    });

    test('reset puts every hand back to owing the full run', () {
      final gate = HandStructureGate(framesToTrust: 2);

      gate.admit([true]);
      expect(gate.admit([true]), [true]);

      gate.reset();
      expect(gate.admit([true]), [false]);
      expect(gate.admit([true]), [true]);
    });
  });
}
