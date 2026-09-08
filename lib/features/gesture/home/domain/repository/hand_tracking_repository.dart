import '../../../../../core/result/result.dart';
import '../entity/camera_session_entity.dart';
import '../entity/hand_detection_entity.dart';

/// The home module's one door to the outside world: start a camera session,
/// observe hands, stop.
abstract interface class HandTrackingRepository {
  Future<Result<CameraSessionEntity>> startTracking({CameraLens lens});

  Future<Result<CameraSessionEntity>> switchCamera();

  /// Detections for each analysed frame. Frames are dropped while the pipeline
  /// is busy, so this emits at whatever rate the device can sustain.
  Stream<Result<HandDetectionEntity>> observeDetections();

  Future<Result<void>> stopTracking();
}
