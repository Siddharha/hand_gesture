import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:hand_gesture/features/gesture/home/domain/entity/hand_entity.dart';
import 'package:hand_gesture/features/gesture/home/domain/entity/hand_gesture_entity.dart';
import 'package:hand_gesture/features/gesture/home/domain/entity/hand_landmark_entity.dart';
import 'package:hand_gesture/features/gesture/home/domain/usecase/recognize_hand_gesture_usecase.dart';

import 'hand_fixtures.dart';

void main() {
  const recognizer = RecognizeHandGestureUseCase();

  HandPoseEntity recognize(HandEntity hand, {double aspect = 1.0}) => recognizer(
        RecognizeHandGestureParams(hand: hand, frameAspectRatio: aspect),
      );

  group('finger counting', () {
    test('a closed hand has no fingers out', () {
      final pose = recognize(buildHand());

      expect(pose.extendedCount, 0);
      expect(pose.gesture, HandGesture.fist);
    });

    test('an open hand has all five out', () {
      final pose = recognize(
        buildHand(thumb: true, index: true, middle: true, ring: true, pinky: true),
      );

      expect(pose.extendedCount, 5);
      expect(pose.gesture, HandGesture.openPalm);
    });

    test('counts each finger independently', () {
      expect(recognize(buildHand(index: true)).extendedCount, 1);
      expect(recognize(buildHand(index: true, middle: true)).extendedCount, 2);
      expect(
        recognize(buildHand(index: true, middle: true, ring: true)).extendedCount,
        3,
      );
      expect(
        recognize(buildHand(index: true, middle: true, ring: true, pinky: true))
            .extendedCount,
        4,
      );
    });

    test('reports which fingers, not just how many', () {
      final pose = recognize(buildHand(index: true, pinky: true));

      expect(pose.isExtended(Finger.indexFinger), isTrue);
      expect(pose.isExtended(Finger.pinky), isTrue);
      expect(pose.isExtended(Finger.middle), isFalse);
      expect(pose.isExtended(Finger.thumb), isFalse);
    });
  });

  group('named gestures', () {
    test('recognises the common shapes', () {
      expect(recognize(buildHand(index: true)).gesture, HandGesture.one);
      expect(
        recognize(buildHand(index: true, middle: true)).gesture,
        HandGesture.two,
      );
      expect(
        recognize(buildHand(index: true, middle: true, ring: true)).gesture,
        HandGesture.three,
      );
      expect(
        recognize(buildHand(index: true, middle: true, ring: true, pinky: true))
            .gesture,
        HandGesture.four,
      );
      expect(
        recognize(buildHand(thumb: true, index: true)).gesture,
        HandGesture.gun,
      );
      expect(
        recognize(buildHand(index: true, pinky: true)).gesture,
        HandGesture.rockOn,
      );
      expect(
        recognize(buildHand(thumb: true, pinky: true)).gesture,
        HandGesture.shaka,
      );
    });

    test('separates thumbs up from thumbs down by where the thumb points', () {
      // Thumb out and above the wrist (y 0.62 < wrist 0.90).
      expect(recognize(buildHand(thumb: true)).gesture, HandGesture.thumbsUp);

      // Same reach from the palm, but below the wrist.
      final down = buildHand(
        thumb: true,
        overrideThumbTip: true,
        thumbTipX: 0.26,
        thumbTipY: 0.98,
      );
      expect(recognize(down).gesture, HandGesture.thumbsDown);
    });

    test('an unnamed shape still reports its finger count', () {
      // Middle and ring only - deliberately not a gesture we name.
      final pose = recognize(buildHand(middle: true, ring: true));

      expect(pose.gesture, HandGesture.unknown);
      expect(pose.extendedCount, 2);
      expect(pose.label, '2 fingers');
    });

    test('labels a single unnamed finger in the singular', () {
      final pose = recognize(buildHand(middle: true));

      expect(pose.gesture, HandGesture.unknown);
      expect(pose.label, '1 finger');
    });
  });

  test('the reading does not depend on the frame aspect ratio', () {
    // Landmarks are normalised per axis, so a non-square frame stretches them.
    // The recogniser corrects for that; without it, thresholds would drift with
    // the camera resolution.
    final hand = buildHand(index: true, middle: true);

    expect(recognize(hand, aspect: 1.0).gesture, HandGesture.two);
    expect(recognize(hand, aspect: 480 / 720).gesture, HandGesture.two);
    expect(recognize(hand, aspect: 720 / 480).gesture, HandGesture.two);
  });

  test('a hand with the wrong number of landmarks is rejected, not guessed', () {
    final truncated = HandEntity(
      landmarks: const [HandLandmarkEntity(x: 0.5, y: 0.5, z: 0)],
      handedness: Handedness.unknown,
      score: 1,
    );

    expect(recognize(truncated).gesture, HandGesture.unknown);
  });

  group('works regardless of whose hand, or how it is held', () {
    test('a left hand reads the same as a right one', () {
      final right = buildHand(index: true, middle: true);
      final left = transform(right, mirror: true);

      expect(recognize(left).gesture, HandGesture.two);
      expect(recognize(left).extendedCount, 2);
      expect(recognize(left).gesture, recognize(right).gesture);
    });

    test('any in-plane rotation reads the same', () {
      final hand = buildHand(index: true, middle: true);

      for (var degrees = 0; degrees < 360; degrees += 30) {
        final turned = transform(hand, rotation: degrees * math.pi / 180);
        expect(
          recognize(turned).gesture,
          HandGesture.two,
          reason: 'rotated $degrees degrees',
        );
      }
    });

    test('hand size and distance from the camera do not matter', () {
      final hand = buildHand(index: true, middle: true, ring: true, pinky: true);

      // A small hand far away, and a large one filling the frame.
      for (final scale in [0.25, 0.5, 1.0, 1.8]) {
        expect(
          recognize(transform(hand, scale: scale)).gesture,
          HandGesture.four,
          reason: 'scaled ${scale}x',
        );
      }
    });

    test('position in the frame does not matter', () {
      final hand = buildHand(thumb: true, index: true, middle: true, ring: true, pinky: true);

      for (final (dx, dy) in [(-0.3, -0.3), (0.3, -0.2), (0.25, 0.05)]) {
        expect(
          recognize(transform(hand, scale: 0.5, dx: dx, dy: dy)).gesture,
          HandGesture.openPalm,
          reason: 'moved by ($dx, $dy)',
        );
      }
    });

    test('a left hand, rotated, small and off-centre, still reads', () {
      final hand = buildHand(index: true);
      final awkward = transform(
        hand,
        mirror: true,
        rotation: 2.1,
        scale: 0.4,
        dx: 0.22,
        dy: -0.18,
      );

      expect(recognize(awkward).gesture, HandGesture.one);
    });
  });

  group('known limits', () {
    test('thumbs up and down are screen-relative, by design', () {
      // Every other reading is rotation-invariant, but "up" is only meaningful
      // relative to the screen, so turning the hand over flips the answer.
      final up = buildHand(thumb: true);
      expect(recognize(up).gesture, HandGesture.thumbsUp);

      final inverted = transform(up, rotation: math.pi);
      expect(recognize(inverted).gesture, HandGesture.thumbsDown);
    });

    test('a finger curling toward the camera can read as extended', () {
      // The real limit of a 2D measure, and not the one you would guess.
      // Straightness is chord over projected arc, which is what makes it
      // immune to hand size and distance - but it also means it cannot see
      // foreshortening at all. A finger curling directly toward the lens still
      // projects onto a straight line, just a shorter one, so it reads as
      // extended. Gestures have to be made roughly face-on to the camera.
      final hand = buildHand(index: true, middle: true);
      final points = [...hand.landmarks];

      // Collinear in projection, but bunched up: a finger aimed at the camera.
      const x = 0.44;
      points[HandLandmarkType.indexPip.index] =
          const HandLandmarkEntity(x: x, y: 0.55, z: 0);
      points[HandLandmarkType.indexDip.index] =
          const HandLandmarkEntity(x: x, y: 0.53, z: 0);
      points[HandLandmarkType.indexTip.index] =
          const HandLandmarkEntity(x: x, y: 0.52, z: 0);

      final foreshortened = HandEntity(
        landmarks: points,
        handedness: hand.handedness,
        score: hand.score,
      );

      expect(recognize(foreshortened).isExtended(Finger.indexFinger), isTrue);
    });
  });
}
