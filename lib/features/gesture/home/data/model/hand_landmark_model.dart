import 'dart:typed_data';

import '../../../../../core/ml/detection_math.dart';

/// The landmark model's output for one crop.
///
/// Landmarks are normalised to the crop, not the frame — the mapper lifts them
/// back into frame space using the ROI they came from.
class HandLandmarkModel {
  const HandLandmarkModel({
    required this.score,
    required this.handednessScore,
    required this.landmarks,
  });

  /// Presence confidence in `[0, 1]`.
  final double score;

  /// `lr` head: values above 0.5 mean the right hand.
  final double handednessScore;

  /// 21 `(x, y, z)` triples in crop-local `[0, 1]` space.
  final List<(double, double, double)> landmarks;
}

/// Decodes `landmarks [1, 21, 3]`, `scores [1]` and `lr [1]`.
abstract final class HandLandmarkDecoder {
  static const landmarkCount = 21;

  /// The bundled model emits landmarks already normalised to the crop, in
  /// `[0, 1]` — unlike the original MediaPipe `hand_landmark` model, which
  /// emits input pixels. Measured on device, a hand in view spans roughly
  /// x`[0.20, 0.67]`, y`[0.28, 0.85]`.
  ///
  /// Dividing these by the input size again collapses every hand to a speck at
  /// the origin: the landmark stage then scores ~0.006 on its own crop and
  /// tracking can never hold, while the palm detector keeps re-firing. The
  /// assert below catches the opposite case if the models are ever swapped for
  /// pixel-emitting ones.
  static HandLandmarkModel decode({
    required Float32List landmarks,
    required double rawScore,
    required double rawHandedness,
  }) {
    final points = <(double, double, double)>[];
    for (var i = 0; i < landmarkCount; i++) {
      final offset = i * 3;
      points.add((
        landmarks[offset],
        landmarks[offset + 1],
        // z shares x's units.
        landmarks[offset + 2],
      ));
    }

    assert(
      points.every((point) => point.$1.abs() <= 4 && point.$2.abs() <= 4),
      'Landmarks look like input pixels, not normalised coordinates. '
      'Divide by the model input size before use.',
    );

    return HandLandmarkModel(
      score: asProbability(rawScore),
      handednessScore: asProbability(rawHandedness),
      landmarks: points,
    );
  }
}
