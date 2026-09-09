import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:hand_gesture/features/gesture/home/domain/entity/hand_entity.dart';
import 'package:hand_gesture/features/gesture/home/domain/entity/hand_landmark_entity.dart';
import 'package:hand_gesture/features/gesture/home/domain/usecase/validate_hand_structure_usecase.dart';

import 'hand_fixtures.dart';

/// Replaces one landmark, leaving the rest of the hand alone.
HandEntity moveLandmark(HandEntity hand, HandLandmarkType type, double x, double y) {
  final points = [...hand.landmarks];
  points[type.index] = HandLandmarkEntity(x: x, y: y, z: 0);
  return HandEntity(
    landmarks: points,
    handedness: hand.handedness,
    score: hand.score,
  );
}

/// Squashes a hand horizontally, the way a wide frame does when coordinates
/// are normalised to each axis separately.
HandEntity squashX(HandEntity hand, double factor) => HandEntity(
      landmarks: [
        for (final point in hand.landmarks)
          HandLandmarkEntity(
            x: 0.5 + (point.x - 0.5) * factor,
            y: point.y,
            z: point.z,
          ),
      ],
      handedness: hand.handedness,
      score: hand.score,
    );

void main() {
  const validator = ValidateHandStructureUseCase();

  bool isValid(HandEntity hand, {double aspect = 1.0}) => validator(
        ValidateHandStructureParams(hand: hand, frameAspectRatio: aspect),
      );

  group('hands that are hands', () {
    test('a fist and an open palm both pass', () {
      expect(isValid(buildHand()), isTrue);
      expect(
        isValid(
          buildHand(thumb: true, index: true, middle: true, ring: true, pinky: true),
        ),
        isTrue,
      );
    });

    test('moving, resizing, spinning and mirroring change nothing', () {
      final hand = buildHand(index: true, middle: true);

      expect(isValid(transform(hand, dx: 0.2, dy: -0.3)), isTrue);
      expect(isValid(transform(hand, scale: 0.35)), isTrue);
      expect(isValid(transform(hand, rotation: math.pi / 2)), isTrue);
      expect(isValid(transform(hand, rotation: math.pi)), isTrue);
      expect(isValid(transform(hand, mirror: true)), isTrue);
    });

    test('a hand running off the edge of the frame still passes', () {
      // The model extrapolates the joints it cannot see, so some land outside
      // [0, 1]. That is normal, not broken.
      expect(isValid(transform(buildHand(index: true), dy: -0.45)), isTrue);
    });

    test('a wide frame squashes x, and the aspect ratio undoes it', () {
      final squashed = squashX(buildHand(index: true, middle: true), 0.5);

      expect(isValid(squashed, aspect: 2.0), isTrue);
    });

    test('seen edge on, the knuckles pile up and are not held against it', () {
      var hand = buildHand(index: true, middle: true, ring: true, pinky: true);
      // Every knuckle at the same point: their order says nothing from here,
      // and unreadable is not the same as wrong.
      for (final knuckle in const [
        HandLandmarkType.indexMcp,
        HandLandmarkType.middleMcp,
        HandLandmarkType.ringMcp,
        HandLandmarkType.pinkyMcp,
      ]) {
        hand = moveLandmark(hand, knuckle, 0.50, 0.60);
      }

      expect(isValid(hand), isTrue);
    });
  });

  group('things that are not hands', () {
    test('the wrong number of landmarks is rejected', () {
      final short = HandEntity(
        landmarks: List.filled(20, const HandLandmarkEntity(x: 0.5, y: 0.5, z: 0)),
        handedness: Handedness.right,
        score: 1,
      );

      expect(isValid(short), isFalse);
    });

    test('a coordinate that is not a number is rejected', () {
      expect(
        isValid(moveLandmark(buildHand(), HandLandmarkType.indexTip, double.nan, 0.4)),
        isFalse,
      );
      expect(
        isValid(
          moveLandmark(buildHand(), HandLandmarkType.wrist, 0.5, double.infinity),
        ),
        isFalse,
      );
    });

    test('a hand collapsed to a point is rejected', () {
      final collapsed = HandEntity(
        landmarks: List.filled(21, const HandLandmarkEntity(x: 0.5, y: 0.5, z: 0)),
        handedness: Handedness.right,
        score: 1,
      );

      expect(isValid(collapsed), isFalse);
    });

    test('landmarks nowhere near the frame are rejected', () {
      expect(isValid(transform(buildHand(), dy: 1.4)), isFalse);
    });

    test('a fingertip flung across the frame is rejected', () {
      expect(
        isValid(moveLandmark(buildHand(index: true), HandLandmarkType.indexTip, 0.05, 0.05)),
        isFalse,
      );
    });

    test('knuckles out of order are rejected', () {
      // Middle and ring knuckles swapped: fingers bend, but the palm cannot
      // reorder itself.
      var hand = buildHand(index: true, middle: true, ring: true, pinky: true);
      hand = moveLandmark(hand, HandLandmarkType.middleMcp, 0.56, 0.60);
      hand = moveLandmark(hand, HandLandmarkType.ringMcp, 0.50, 0.60);

      expect(isValid(hand), isFalse);
    });

    test('a knuckle lifted off the line of the palm is rejected', () {
      expect(
        isValid(
          moveLandmark(
            buildHand(index: true, middle: true, ring: true, pinky: true),
            HandLandmarkType.ringMcp,
            0.56,
            0.40,
          ),
        ),
        isFalse,
      );
    });

    test('a nonsense aspect ratio is rejected rather than divided by', () {
      expect(isValid(buildHand(), aspect: 0), isFalse);
      expect(isValid(buildHand(), aspect: double.nan), isFalse);
    });
  });
}
