import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hand_gesture/core/ml/frame_sampler.dart';
import 'package:hand_gesture/core/ml/geometry.dart';
import 'package:hand_gesture/core/ml/ssd_anchors.dart';
import 'package:hand_gesture/core/resources/hand_model_resources.dart';

/// Builds a BGRA frame whose pixels encode their own coordinates:
/// red = x * 16, green = y * 16.
List<FramePlane> _coordinateFrame(int width, int height) {
  final bytes = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      bytes[i] = 0; // B
      bytes[i + 1] = y * 16; // G
      bytes[i + 2] = x * 16; // R
      bytes[i + 3] = 255;
    }
  }
  return [FramePlane(bytes: bytes, bytesPerRow: width * 4, bytesPerPixel: 4)];
}

({double r, double g, double b}) _pixel(Float32List t, int size, int x, int y) {
  final i = (y * size + x) * 3;
  return (r: t[i], g: t[i + 1], b: t[i + 2]);
}

void main() {
  group('ssd anchors', () {
    test('palm detector grid matches the model\'s 2944 anchors', () {
      final anchors = generateSsdAnchors(const SsdAnchorOptions.palmDetection());

      expect(anchors.length, HandModelResources.detectorAnchorCount);
      expect(anchors.length, 2944);
    });

    test('anchor centres stay inside the input square', () {
      final anchors = generateSsdAnchors(const SsdAnchorOptions.palmDetection());

      for (final anchor in anchors) {
        expect(anchor.centerX, inInclusiveRange(0.0, 1.0));
        expect(anchor.centerY, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('rotated rect', () {
    test('local space round-trips through image space', () {
      const rect = RotatedRect(
        centerX: 0.4,
        centerY: 0.6,
        width: 0.5,
        height: 0.25,
        rotation: 0.9,
      );

      // The centre of local space is the centre of the rect, whatever the
      // rotation.
      final (cx, cy) = rect.toImageSpace(0.5, 0.5, 1.0);
      expect(cx, closeTo(0.4, 1e-9));
      expect(cy, closeTo(0.6, 1e-9));
    });

    test('an unrotated shift moves along the plain axes', () {
      const rect = RotatedRect(centerX: 0.5, centerY: 0.5, width: 0.4, height: 0.2);
      final shifted = rect.shifted(0, -0.5, 3 / 4);

      expect(shifted.centerX, closeTo(0.5, 1e-9));
      expect(shifted.centerY, closeTo(0.5 - 0.2 * 0.5, 1e-9));
    });

    test('a rotated shift is corrected for the frame aspect', () {
      // Rotated a quarter turn, a pure y-shift becomes a pure x-shift - and the
      // distance has to be converted between the two axes' units, or the crop
      // drifts sideways on any non-square frame. Without the correction this
      // lands at 0.5 - 0.1 instead.
      const aspect = 3 / 4;
      const rect = RotatedRect(
        centerX: 0.5,
        centerY: 0.5,
        width: 0.4,
        height: 0.2,
        rotation: math.pi / 2,
      );

      final shifted = rect.shifted(0, -0.5, aspect);

      expect(shifted.centerX, closeTo(0.5 + (0.2 * 0.5) / aspect, 1e-9));
      expect(shifted.centerY, closeTo(0.5, 1e-9));
    });

    test('squaredLong produces a square in pixel space', () {
      const aspect = 3 / 4;
      const rect = RotatedRect(centerX: .5, centerY: .5, width: .8, height: .2);
      final square = rect.squaredLong(aspect);

      expect(square.width * aspect, closeTo(square.height, 1e-9));
      // It grows to the longer side, never shrinks.
      expect(square.height, greaterThanOrEqualTo(rect.height));
    });
  });

  group('frame sampler', () {
    test('unrotated full-frame sampling preserves orientation', () {
      const size = 8;
      final tensor = FrameSampler.sampleRoi(
        planes: _coordinateFrame(size, size),
        format: FramePixelFormat.bgra8888,
        frameWidth: size,
        frameHeight: size,
        rotationDegrees: 0,
        mirror: false,
        roi: FrameSampler.fullFrameRoi(
          frameWidth: size,
          frameHeight: size,
          rotationDegrees: 0,
        ),
        outputSize: size,
      );

      // Top-left stays dark, red grows to the right, green grows downward.
      expect(_pixel(tensor, size, 0, 0).r, closeTo(0.0, 1e-6));
      expect(_pixel(tensor, size, 7, 0).r, closeTo(7 * 16 / 255, 1e-6));
      expect(_pixel(tensor, size, 0, 7).g, closeTo(7 * 16 / 255, 1e-6));
      expect(_pixel(tensor, size, 0, 7).r, closeTo(0.0, 1e-6));
    });

    test('90 degree sensor rotation stands the frame upright', () {
      const size = 8;
      final planes = _coordinateFrame(size, size);
      final tensor = FrameSampler.sampleRoi(
        planes: planes,
        format: FramePixelFormat.bgra8888,
        frameWidth: size,
        frameHeight: size,
        rotationDegrees: 90,
        mirror: false,
        roi: FrameSampler.fullFrameRoi(
          frameWidth: size,
          frameHeight: size,
          rotationDegrees: 90,
        ),
        outputSize: size,
      );

      // Rotating clockwise sends the raw bottom-left corner (dark red, bright
      // green) to the upright top-left.
      final topLeft = _pixel(tensor, size, 0, 0);
      expect(topLeft.r, closeTo(0.0, 1e-6));
      expect(topLeft.g, closeTo(7 * 16 / 255, 1e-6));

      // ...and the raw top-left (all dark) to the upright top-right.
      final topRight = _pixel(tensor, size, 7, 0);
      expect(topRight.r, closeTo(0.0, 1e-6));
      expect(topRight.g, closeTo(0.0, 1e-6));
    });

    test('mirroring flips the horizontal axis only', () {
      const size = 8;
      final planes = _coordinateFrame(size, size);
      Float32List sample({required bool mirror}) => FrameSampler.sampleRoi(
            planes: planes,
            format: FramePixelFormat.bgra8888,
            frameWidth: size,
            frameHeight: size,
            rotationDegrees: 0,
            mirror: mirror,
            roi: FrameSampler.fullFrameRoi(
              frameWidth: size,
              frameHeight: size,
              rotationDegrees: 0,
            ),
            outputSize: size,
          );

      final plain = sample(mirror: false);
      final mirrored = sample(mirror: true);

      expect(_pixel(mirrored, size, 0, 3).r, closeTo(_pixel(plain, size, 7, 3).r, 1e-6));
      expect(_pixel(mirrored, size, 0, 3).g, closeTo(_pixel(plain, size, 7, 3).g, 1e-6));
    });

    test('sampling outside the frame is padded, not wrapped', () {
      const size = 8;
      final tensor = FrameSampler.sampleRoi(
        planes: _coordinateFrame(size, size),
        format: FramePixelFormat.bgra8888,
        frameWidth: size,
        frameHeight: size,
        rotationDegrees: 0,
        mirror: false,
        // A ROI twice the frame: the outer ring falls outside.
        roi: const RotatedRect(centerX: 0.5, centerY: 0.5, width: 2, height: 2),
        outputSize: size,
      );

      expect(_pixel(tensor, size, 0, 0).r, 0.0);
      expect(_pixel(tensor, size, 0, 0).g, 0.0);
    });
  });
}
