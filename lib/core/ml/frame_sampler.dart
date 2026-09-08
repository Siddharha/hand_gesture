import 'dart:math' as math;
import 'dart:typed_data';

import 'geometry.dart';

/// Pixel layouts the sampler understands. Android streams YUV420, iOS BGRA.
enum FramePixelFormat { yuv420, bgra8888 }

/// One plane of a camera frame, with the strides needed to index it.
class FramePlane {
  const FramePlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel = 1,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;
}

/// Turns a camera frame into the square, normalised RGB tensor a TFLite model
/// expects.
///
/// Everything happens in one pass: for each output pixel it walks back through
/// the ROI rotation and the sensor rotation to a source pixel and converts it
/// there. The ROI transform is differentiated so the inner loop only adds, the
/// colour conversion is fixed-point, and the caller's buffer is written in
/// place. There is no intermediate RGB bitmap and no resize step, which is what
/// keeps this affordable per frame — it runs on every analysed frame, twice on
/// a frame that also runs the detector.
///
/// Coordinates are expressed in *upright* space — the frame as the user sees
/// it, after sensor rotation and mirroring — so landmarks come back in the same
/// space the preview is drawn in.
abstract final class FrameSampler {
  // BT.601 full-range YUV -> RGB, in 16-bit fixed point. Integer maths here is
  // worth real time at ~197k pixels per sample.
  static const _vToR = 91881; // 1.402
  static const _uToG = 22554; // 0.344136
  static const _vToG = 46802; // 0.714136
  static const _uToB = 116130; // 1.772

  /// Samples [roi] into a `[1, size, size, 3]` RGB tensor, flattened.
  ///
  /// Values are scaled into [valueRange]. Samples outside the frame come back
  /// black, which is what letterboxing a non-square frame amounts to.
  static Float32List sampleRoi({
    required List<FramePlane> planes,
    required FramePixelFormat format,
    required int frameWidth,
    required int frameHeight,
    required int rotationDegrees,
    required bool mirror,
    required RotatedRect roi,
    required int outputSize,
    (double, double) valueRange = (0.0, 1.0),
    Float32List? into,
  }) {
    final quarterTurns = (rotationDegrees ~/ 90) % 4;
    final swapsAxes = quarterTurns.isOdd;
    final uprightWidth = swapsAxes ? frameHeight : frameWidth;
    final uprightHeight = swapsAxes ? frameWidth : frameHeight;
    final aspectRatio = uprightWidth / uprightHeight;

    final output = into ?? Float32List(outputSize * outputSize * 3);
    final (rangeMin, rangeMax) = valueRange;
    final scale = (rangeMax - rangeMin) / 255.0;

    // Step 1: the ROI-local -> upright-pixel affine. See
    // RotatedRect.toImageSpace for the closed form this differentiates.
    final cos = math.cos(roi.rotation);
    final sin = math.sin(roi.rotation);
    final spanX = roi.width * aspectRatio / outputSize;
    final spanY = roi.height / outputSize;

    var perCol = spanX * cos / aspectRatio * uprightWidth;
    var perRow = -spanY * sin / aspectRatio * uprightWidth;
    final colY = spanX * sin * uprightHeight;
    final rowY = spanY * cos * uprightHeight;

    final halfOffset = (0.5 / outputSize) - 0.5;
    var startX = (roi.centerX +
            (roi.width * aspectRatio * halfOffset * cos -
                    roi.height * halfOffset * sin) /
                aspectRatio) *
        uprightWidth;
    var startY = (roi.centerY +
            (roi.width * aspectRatio * halfOffset * sin +
                roi.height * halfOffset * cos)) *
        uprightHeight;

    final isYuv = format == FramePixelFormat.yuv420;
    final yBytes = planes[0].bytes;
    final yRowStride = planes[0].bytesPerRow;
    final uBytes = isYuv ? planes[1].bytes : yBytes;
    final vBytes = isYuv ? planes[2].bytes : yBytes;
    final uvRowStride = isYuv ? planes[1].bytesPerRow : 0;
    final uvPixelStride = isYuv ? planes[1].bytesPerPixel : 0;

    final minValue = rangeMin;
    var writeIndex = 0;

    for (var row = 0; row < outputSize; row++) {
      var ux = startX + perRow * row;
      var uy = startY + rowY * row;

      for (var col = 0; col < outputSize; col++, ux += perCol, uy += colY) {
        var px = ux.toInt();
        final py = uy.toInt();

        // Reflect and rotate on the pixel index, never on the continuous
        // coordinate: mirroring `ux` before truncating shifts every sample by
        // up to a pixel, which the sampler tests catch.
        if (mirror) px = (uprightWidth - 1) - px;

        final int rawX;
        final int rawY;
        switch (quarterTurns) {
          case 1:
            rawX = py;
            rawY = (frameHeight - 1) - px;
          case 2:
            rawX = (frameWidth - 1) - px;
            rawY = (frameHeight - 1) - py;
          case 3:
            rawX = (frameWidth - 1) - py;
            rawY = px;
          default:
            rawX = px;
            rawY = py;
        }

        if (px < 0 || py < 0 || px >= uprightWidth || py >= uprightHeight) {
          output[writeIndex++] = minValue;
          output[writeIndex++] = minValue;
          output[writeIndex++] = minValue;
          continue;
        }

        int r;
        int g;
        int b;

        if (isYuv) {
          final y = yBytes[rawY * yRowStride + rawX];
          final uvIndex =
              (rawY >> 1) * uvRowStride + (rawX >> 1) * uvPixelStride;
          final u = uBytes[uvIndex] - 128;
          final v = vBytes[uvIndex] - 128;

          r = y + ((_vToR * v) >> 16);
          g = y - ((_uToG * u + _vToG * v) >> 16);
          b = y + ((_uToB * u) >> 16);

          if (r < 0) {
            r = 0;
          } else if (r > 255) {
            r = 255;
          }
          if (g < 0) {
            g = 0;
          } else if (g > 255) {
            g = 255;
          }
          if (b < 0) {
            b = 0;
          } else if (b > 255) {
            b = 255;
          }
        } else {
          final index = rawY * yRowStride + rawX * 4;
          b = yBytes[index];
          g = yBytes[index + 1];
          r = yBytes[index + 2];
        }

        output[writeIndex++] = minValue + r * scale;
        output[writeIndex++] = minValue + g * scale;
        output[writeIndex++] = minValue + b * scale;
      }
    }

    return output;
  }

  /// The ROI covering the whole frame as a centred square — the detector sees
  /// the full scene, letterboxed rather than stretched.
  static RotatedRect fullFrameRoi({
    required int frameWidth,
    required int frameHeight,
    required int rotationDegrees,
  }) {
    final swapsAxes = ((rotationDegrees ~/ 90) % 4).isOdd;
    final uprightWidth = swapsAxes ? frameHeight : frameWidth;
    final uprightHeight = swapsAxes ? frameWidth : frameHeight;
    final aspectRatio = uprightWidth / uprightHeight;

    return const RotatedRect(
      centerX: 0.5,
      centerY: 0.5,
      width: 1.0,
      height: 1.0,
    ).squaredLong(aspectRatio);
  }
}
