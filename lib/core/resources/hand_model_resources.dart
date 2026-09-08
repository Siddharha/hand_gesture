import 'app_assets.dart';
import 'tflite_model_spec.dart';

/// Tensor contracts for the bundled MediaPipe hand models, transcribed from
/// `assets/models/metadata.json`. Keep both in sync when the models are
/// replaced.
abstract final class HandModelResources {
  /// Stage 1 — finds hand bounding boxes in a full frame.
  ///
  /// `box_coords` is `[1, 2944, 18]`: 2944 anchors × (4 box values + 7 keypoint
  /// pairs). `box_scores` is the matching confidence per anchor.
  static const detector = TfLiteModelSpec(
    assetPath: AppAssets.handDetectorModel,
    inputShape: [1, 256, 256, 3],
    inputRange: (0.0, 1.0),
    outputs: {
      'box_coords': [1, 2944, 18],
      'box_scores': [1, 2944, 1],
    },
  );

  /// Stage 2 — runs on a cropped hand and returns its landmarks.
  ///
  /// `scores` is the presence confidence, `lr` the handedness (0 = left,
  /// 1 = right), `landmarks` the 21 points as normalised `(x, y, z)`.
  static const landmarkDetector = TfLiteModelSpec(
    assetPath: AppAssets.handLandmarkDetectorModel,
    inputShape: [1, 256, 256, 3],
    inputRange: (0.0, 1.0),
    outputs: {
      'scores': [1],
      'lr': [1],
      'landmarks': [1, 21, 3],
    },
  );

  /// Landmarks the second stage returns, per hand.
  static const landmarkCount = 21;

  /// Anchor boxes the detector scores in a single pass.
  static const detectorAnchorCount = 2944;
}
