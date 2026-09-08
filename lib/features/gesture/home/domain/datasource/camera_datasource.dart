import '../entity/camera_frame_entity.dart';
import '../entity/camera_session_entity.dart';

/// Contract for the camera. The implementation drives CameraX through the
/// `camera` plugin; nothing above this line knows that.
abstract interface class CameraDataSource {
  /// Opens the camera and begins streaming frames. Throws a
  /// `CameraAccessException` when the user denies permission.
  Future<CameraSessionEntity> start({CameraLens lens = CameraLens.back});

  /// Frames as they arrive. Backpressure is the consumer's problem: frames are
  /// dropped, never queued, so a slow consumer falls behind in latency but not
  /// in memory.
  Stream<CameraFrameEntity> get frames;

  /// Switches to the other camera, keeping the stream running.
  Future<CameraSessionEntity> switchLens();

  Future<void> stop();

  Future<void> dispose();
}
