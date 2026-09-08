import 'dart:typed_data';

import '../../../../../core/ml/detection_math.dart';
import '../../../../../core/ml/geometry.dart';
import '../../../../../core/ml/ssd_anchors.dart';

/// One palm the detector proposed, decoded out of the raw anchor tensors.
///
/// Coordinates are normalised to the detector's square input, not to the frame.
class PalmDetectionModel {
  const PalmDetectionModel({
    required this.score,
    required this.box,
    required this.keypoints,
  });

  final double score;
  final NormalizedRect box;

  /// Seven palm keypoints as `(x, y)`; the ROI builder uses 0 and 2.
  final List<(double, double)> keypoints;
}

/// Decodes `box_coords [1, 2944, 18]` + `box_scores [1, 2944, 1]`.
///
/// The model emits offsets against a fixed anchor grid, so decoding is
/// anchor-relative. Layout per box, with MediaPipe's `reverse_output_order`
/// set: `[x_center, y_center, w, h, kp0x, kp0y, ... kp6x, kp6y]`.
abstract final class PalmDetectionDecoder {
  static const keypointCount = 7;
  static const valuesPerBox = 4 + keypointCount * 2;

  static List<PalmDetectionModel> decode({
    required Float32List boxCoords,
    required Float32List boxScores,
    required List<SsdAnchor> anchors,
    required int inputSize,
    double scoreThreshold = 0.5,
    double iouThreshold = 0.3,
    int maxResults = 4,
  }) {
    final candidates = <ScoredBox>[];
    final decoded = <int, PalmDetectionModel>{};

    for (var i = 0; i < anchors.length; i++) {
      final score = sigmoid(boxScores[i]);
      if (score < scoreThreshold) continue;

      final anchor = anchors[i];
      final offset = i * valuesPerBox;

      // Offsets are in input-pixel units; divide by the input size to get back
      // to normalised space.
      final centerX = boxCoords[offset] / inputSize * anchor.width + anchor.centerX;
      final centerY = boxCoords[offset + 1] / inputSize * anchor.height + anchor.centerY;
      final width = boxCoords[offset + 2] / inputSize * anchor.width;
      final height = boxCoords[offset + 3] / inputSize * anchor.height;

      final keypoints = <(double, double)>[];
      for (var k = 0; k < keypointCount; k++) {
        final kpOffset = offset + 4 + k * 2;
        keypoints.add((
          boxCoords[kpOffset] / inputSize * anchor.width + anchor.centerX,
          boxCoords[kpOffset + 1] / inputSize * anchor.height + anchor.centerY,
        ));
      }

      final rect = NormalizedRect(
        left: centerX - width / 2,
        top: centerY - height / 2,
        width: width,
        height: height,
      );

      decoded[i] = PalmDetectionModel(score: score, box: rect, keypoints: keypoints);
      candidates.add(ScoredBox(index: i, score: score, rect: rect));
    }

    final kept = nonMaxSuppression(
      candidates,
      iouThreshold: iouThreshold,
      maxResults: maxResults,
    );

    return [for (final box in kept) decoded[box.index]!];
  }
}
