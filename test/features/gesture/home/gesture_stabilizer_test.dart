import 'package:flutter_test/flutter_test.dart';

import 'package:hand_gesture/features/gesture/home/domain/entity/hand_gesture_entity.dart';
import 'package:hand_gesture/features/gesture/home/presentation/viewmodel/gesture_stabilizer.dart';

HandPoseEntity poseOf(HandGesture gesture) =>
    HandPoseEntity(gesture: gesture, extendedFingers: const {});

void main() {
  test('a new shape has to hold before it replaces the old one', () {
    final stabilizer = GestureStabilizer(framesToConfirm: 3);
    final fist = poseOf(HandGesture.fist);
    final palm = poseOf(HandGesture.openPalm);

    expect(stabilizer.stabilize([fist]), [fist]);
    expect(stabilizer.stabilize([palm]), [fist]);
    expect(stabilizer.stabilize([palm]), [fist]);
    expect(stabilizer.stabilize([palm]), [palm]);
  });

  test('a flicker back to the old shape starts the new one over', () {
    final stabilizer = GestureStabilizer(framesToConfirm: 3);
    final fist = poseOf(HandGesture.fist);
    final palm = poseOf(HandGesture.openPalm);

    stabilizer.stabilize([fist]);
    stabilizer.stabilize([palm]);
    expect(stabilizer.stabilize([fist]), [fist]);
    expect(stabilizer.stabilize([palm]), [fist]);
    expect(stabilizer.stabilize([palm]), [fist]);
  });

  group('a withheld hand', () {
    test('shows nothing rather than the last shape it made', () {
      final stabilizer = GestureStabilizer(framesToConfirm: 3);
      stabilizer.stabilize([poseOf(HandGesture.two)]);

      expect(stabilizer.stabilize([null]), [null]);
      expect(stabilizer.stabilize([null]), [null]);
    });

    test('is shown straight away when it comes back, like a new hand', () {
      final stabilizer = GestureStabilizer(framesToConfirm: 3);
      stabilizer.stabilize([poseOf(HandGesture.two)]);
      stabilizer.stabilize([null]);

      final palm = poseOf(HandGesture.openPalm);
      expect(stabilizer.stabilize([palm]), [palm]);
    });

    test('does not hold up the hand beside it', () {
      final stabilizer = GestureStabilizer(framesToConfirm: 2);
      final fist = poseOf(HandGesture.fist);
      final one = poseOf(HandGesture.one);

      expect(stabilizer.stabilize([null, fist]), [null, fist]);
      expect(stabilizer.stabilize([one, fist]), [one, fist]);
    });
  });

  test('a hand leaving takes its history with it', () {
    final stabilizer = GestureStabilizer(framesToConfirm: 3);
    final fist = poseOf(HandGesture.fist);
    final palm = poseOf(HandGesture.openPalm);

    stabilizer.stabilize([fist]);
    stabilizer.stabilize(const []);

    // The next hand in that slot is a first sight, not a candidate change.
    expect(stabilizer.stabilize([palm]), [palm]);
  });
}
