import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hand_gesture/core/ml/ssd_anchors.dart';
import 'package:hand_gesture/features/gesture/home/data/model/hand_landmark_model.dart';
import 'package:hand_gesture/features/gesture/home/data/model/palm_detection_model.dart';

void main() {
  group('hand landmark decoder', () {
    test('keeps the model\'s normalised coordinates as they are', () {
      // The bundled model emits crop-normalised landmarks. Scaling them by the
      // input size again collapsed every hand to a speck at the origin, which
      // let the palm detector fire while tracking could never hold.
      final raw = Float32List(HandLandmarkDecoder.landmarkCount * 3);
      raw[0] = 0.25; // wrist x
      raw[1] = 0.80; // wrist y
      raw[2] = 0.01; // wrist z
      raw[36] = 0.55; // landmark 12 (middle fingertip) x
      raw[37] = 0.20; // ...y

      final model = HandLandmarkDecoder.decode(
        landmarks: raw,
        rawScore: 0.97,
        rawHandedness: 0.9,
      );

      // Tolerances are float32-sized: the tensor stores single precision.
      expect(model.landmarks, hasLength(21));
      expect(model.landmarks[0].$1, closeTo(0.25, 1e-6));
      expect(model.landmarks[0].$2, closeTo(0.80, 1e-6));
      expect(model.landmarks[12].$1, closeTo(0.55, 1e-6));
      expect(model.landmarks[12].$2, closeTo(0.20, 1e-6));

      // Held fingers-up, the wrist sits below the fingertip.
      expect(model.landmarks[0].$2, greaterThan(model.landmarks[12].$2));
    });

    test('passes through a probability and activates a logit', () {
      final raw = Float32List(HandLandmarkDecoder.landmarkCount * 3);

      final probability = HandLandmarkDecoder.decode(
        landmarks: raw,
        rawScore: 0.87,
        rawHandedness: 0.2,
      );
      expect(probability.score, closeTo(0.87, 1e-6));

      final logit = HandLandmarkDecoder.decode(
        landmarks: raw,
        rawScore: 4.0,
        rawHandedness: -4.0,
      );
      expect(logit.score, greaterThan(0.98));
      expect(logit.handednessScore, lessThan(0.02));
    });
  });

  group('palm detection decoder', () {
    /// Writes one box into the raw anchor tensor, in the model's layout:
    /// `[x_center, y_center, w, h, then 7 keypoint pairs]`, in input pixels.
    Float32List boxesWith({
      required int anchorIndex,
      required int anchorCount,
      required double x,
      required double y,
      required double size,
    }) {
      final boxes = Float32List(anchorCount * PalmDetectionDecoder.valuesPerBox);
      final offset = anchorIndex * PalmDetectionDecoder.valuesPerBox;
      boxes[offset] = x;
      boxes[offset + 1] = y;
      boxes[offset + 2] = size;
      boxes[offset + 3] = size;
      for (var k = 0; k < PalmDetectionDecoder.keypointCount; k++) {
        boxes[offset + 4 + k * 2] = x;
        boxes[offset + 5 + k * 2] = y;
      }
      return boxes;
    }

    test('decodes a box relative to its anchor', () {
      final anchors = generateSsdAnchors(const SsdAnchorOptions.palmDetection());
      const index = 1500;
      final anchor = anchors[index];

      // 25.6px at a 256px input is a tenth of the frame; the offset is relative
      // to the anchor centre, not the image origin.
      final boxes = boxesWith(
        anchorIndex: index,
        anchorCount: anchors.length,
        x: 25.6,
        y: -12.8,
        size: 51.2,
      );
      final scores = Float32List(anchors.length)..fillRange(0, anchors.length, -20);
      scores[index] = 20; // sigmoid(20) is effectively 1

      final palms = PalmDetectionDecoder.decode(
        boxCoords: boxes,
        boxScores: scores,
        anchors: anchors,
        inputSize: 256,
      );

      expect(palms, hasLength(1));
      final palm = palms.single;
      expect(palm.score, closeTo(1.0, 1e-6));
      expect(palm.box.centerX, closeTo(anchor.centerX + 0.1, 1e-6));
      expect(palm.box.centerY, closeTo(anchor.centerY - 0.05, 1e-6));
      expect(palm.box.width, closeTo(0.2, 1e-6));
      expect(palm.keypoints, hasLength(PalmDetectionDecoder.keypointCount));
    });

    test('drops boxes below the score threshold', () {
      final anchors = generateSsdAnchors(const SsdAnchorOptions.palmDetection());
      final boxes = boxesWith(
        anchorIndex: 10,
        anchorCount: anchors.length,
        x: 0,
        y: 0,
        size: 25.6,
      );
      // sigmoid(0) is 0.5, just under the default 0.5 threshold's strict test.
      final scores = Float32List(anchors.length)..fillRange(0, anchors.length, -20);
      scores[10] = -1; // ~0.27

      expect(
        PalmDetectionDecoder.decode(
          boxCoords: boxes,
          boxScores: scores,
          anchors: anchors,
          inputSize: 256,
        ),
        isEmpty,
      );
    });
  });
}
