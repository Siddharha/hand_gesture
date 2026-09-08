import 'package:flutter_test/flutter_test.dart';

import 'package:hand_gesture/features/gesture/home/domain/entity/hand_entity.dart';
import 'package:hand_gesture/features/gesture/home/domain/entity/hand_gesture_entity.dart';
import 'package:hand_gesture/features/gesture/home/domain/entity/hand_landmark_entity.dart';
import 'package:hand_gesture/features/gesture/home/domain/usecase/recognize_hand_gesture_usecase.dart';

/// Builds a canonical hand: palm at the bottom, fingers pointing up the frame.
///
/// Extended fingers run straight up from the knuckle; curled ones fold back
/// down so the knuckle-to-tip chord collapses, which is exactly what the
/// straightness measure keys on.
HandEntity buildHand({
  bool thumb = false,
  bool index = false,
  bool middle = false,
  bool ring = false,
  bool pinky = false,
  double thumbTipX = 0.26,
  double thumbTipY = 0.62,
  bool overrideThumbTip = false,
}) {
  final points = List<HandLandmarkEntity>.filled(
    21,
    const HandLandmarkEntity(x: 0, y: 0, z: 0),
  );

  void put(HandLandmarkType type, double x, double y) {
    points[type.index] = HandLandmarkEntity(x: x, y: y, z: 0);
  }

  put(HandLandmarkType.wrist, 0.50, 0.90);

  // Thumb runs down-left from the wrist; extended reaches away from the palm,
  // tucked folds back across it.
  put(HandLandmarkType.thumbCmc, 0.44, 0.82);
  put(HandLandmarkType.thumbMcp, 0.38, 0.76);
  if (thumb) {
    put(HandLandmarkType.thumbIp, 0.32, 0.69);
    put(HandLandmarkType.thumbTip, 0.26, 0.62);
  } else {
    put(HandLandmarkType.thumbIp, 0.44, 0.72);
    put(HandLandmarkType.thumbTip, 0.50, 0.69);
  }
  if (overrideThumbTip) {
    put(HandLandmarkType.thumbTip, thumbTipX, thumbTipY);
  }

  final layout = <(bool, double, List<HandLandmarkType>)>[
    (
      index,
      0.44,
      [
        HandLandmarkType.indexMcp,
        HandLandmarkType.indexPip,
        HandLandmarkType.indexDip,
        HandLandmarkType.indexTip,
      ]
    ),
    (
      middle,
      0.50,
      [
        HandLandmarkType.middleMcp,
        HandLandmarkType.middlePip,
        HandLandmarkType.middleDip,
        HandLandmarkType.middleTip,
      ]
    ),
    (
      ring,
      0.56,
      [
        HandLandmarkType.ringMcp,
        HandLandmarkType.ringPip,
        HandLandmarkType.ringDip,
        HandLandmarkType.ringTip,
      ]
    ),
    (
      pinky,
      0.62,
      [
        HandLandmarkType.pinkyMcp,
        HandLandmarkType.pinkyPip,
        HandLandmarkType.pinkyDip,
        HandLandmarkType.pinkyTip,
      ]
    ),
  ];

  for (final (isExtended, x, joints) in layout) {
    put(joints[0], x, 0.60);
    if (isExtended) {
      put(joints[1], x, 0.50);
      put(joints[2], x, 0.44);
      put(joints[3], x, 0.38);
    } else {
      put(joints[1], x, 0.52);
      put(joints[2], x, 0.56);
      put(joints[3], x, 0.60);
    }
  }

  return HandEntity(
    landmarks: points,
    handedness: Handedness.right,
    score: 1,
  );
}

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
}
