/// Every bundled asset path in one place, so no string literal for an asset
/// appears anywhere else in the app.
///
/// Paths must match the `assets:` entries in `pubspec.yaml`.
abstract final class AppAssets {
  static const _models = 'assets/models';

  /// MediaPipe palm/hand detector (float, 256×256).
  static const handDetectorModel = '$_models/hand_detector.tflite';

  /// MediaPipe hand landmark detector (float, 256×256, 21 landmarks).
  static const handLandmarkDetectorModel = '$_models/hand_landmark_detector.tflite';

  /// Vendor metadata shipped with the models (input/output specs).
  static const handModelMetadata = '$_models/metadata.json';
}
