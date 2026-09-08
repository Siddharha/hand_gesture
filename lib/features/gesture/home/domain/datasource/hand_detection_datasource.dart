import '../entity/camera_frame_entity.dart';
import '../entity/hand_detection_entity.dart';

/// Contract for the two-stage hand pipeline.
abstract interface class HandDetectionDataSource {
  /// Loads the models. Must complete before [detect] is called.
  Future<void> initialize();

  /// Runs one frame through the pipeline.
  ///
  /// Returns null when the pipeline was still busy with an earlier frame: this
  /// one was dropped. Dropping keeps latency low, and the caller should hold
  /// the previous result rather than blanking the overlay.
  Future<HandDetectionEntity?> detect(CameraFrameEntity frame);

  /// Forgets the tracked region so the next frame re-runs the palm detector.
  void resetTracking();

  Future<void> close();
}
