import 'dart:async';

import '../../../../../core/error/app_exception.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/logger/app_logger.dart';
import '../../../../../core/result/result.dart';
import '../../domain/datasource/camera_datasource.dart';
import '../../domain/datasource/hand_detection_datasource.dart';
import '../../domain/entity/camera_frame_entity.dart';
import '../../domain/entity/camera_session_entity.dart';
import '../../domain/entity/hand_detection_entity.dart';
import '../../domain/repository/hand_tracking_repository.dart';

/// Joins the camera to the detector: frames in one side, hands out the other.
///
/// Also the layer where exceptions stop. Everything above this sees a [Result].
class HandTrackingRepositoryImpl implements HandTrackingRepository {
  HandTrackingRepositoryImpl({
    required this.cameraDataSource,
    required this.detectionDataSource,
    required this.logger,
  });

  final CameraDataSource cameraDataSource;
  final HandDetectionDataSource detectionDataSource;
  final AppLogger logger;

  @override
  Future<Result<CameraSessionEntity>> startTracking({
    CameraLens lens = CameraLens.back,
  }) async {
    try {
      // Models first: the camera should not be held open if this fails.
      await detectionDataSource.initialize();
      final session = await cameraDataSource.start(lens: lens);
      return Result.success(session);
    } catch (e, stackTrace) {
      return Result.error(_toFailure(e, stackTrace));
    }
  }

  @override
  Future<Result<CameraSessionEntity>> switchCamera() async {
    try {
      // The new lens sees a different scene, and mirroring may flip.
      detectionDataSource.resetTracking();
      return Result.success(await cameraDataSource.switchLens());
    } catch (e, stackTrace) {
      return Result.error(_toFailure(e, stackTrace));
    }
  }

  @override
  Stream<Result<HandDetectionEntity>> observeDetections() {
    // Conflating consumer: only ever the newest frame is analysed, and frames
    // that arrive while the pipeline is busy are discarded.
    //
    // Not `asyncMap`: it serialises by pausing its subscription, and a
    // broadcast controller *buffers* for a paused subscriber. The camera
    // produces ~30fps and the pipeline consumes ~10fps, so frames pile up in
    // that buffer and every analysed frame is older than the last - the overlay
    // falls progressively further behind the preview instead of just running at
    // a lower frame rate.
    late final StreamController<Result<HandDetectionEntity>> controller;
    StreamSubscription<CameraFrameEntity>? subscription;
    CameraFrameEntity? newestFrame;
    var isDraining = false;

    Future<void> drain() async {
      if (isDraining) return;
      isDraining = true;

      while (newestFrame != null && !controller.isClosed) {
        final frame = newestFrame!;
        newestFrame = null; // Anything arriving from here on supersedes it.

        try {
          final detection = await detectionDataSource.detect(frame);
          if (detection != null && !controller.isClosed) {
            controller.add(Result.success(detection));
          }
        } catch (e, stackTrace) {
          if (!controller.isClosed) {
            controller.add(Result.error(_toFailure(e, stackTrace)));
          }
        }
      }

      isDraining = false;
    }

    controller = StreamController<Result<HandDetectionEntity>>(
      onListen: () {
        subscription = cameraDataSource.frames.listen((frame) {
          newestFrame = frame;
          drain();
        });
      },
      onCancel: () async {
        await subscription?.cancel();
        subscription = null;
        newestFrame = null;
      },
    );

    return controller.stream;
  }

  @override
  Future<Result<void>> stopTracking() async {
    try {
      await cameraDataSource.stop();
      await detectionDataSource.close();
      return const Result.success(null);
    } catch (e, stackTrace) {
      return Result.error(_toFailure(e, stackTrace));
    }
  }

  Failure _toFailure(Object error, StackTrace stackTrace) {
    logger.error('Hand tracking failed', error: error, stackTrace: stackTrace);

    return switch (error) {
      PermissionException(:final message, :final permission) =>
        PermissionFailure(message, permission: permission, cause: error),
      DeviceException(:final message) => DeviceFailure(message, cause: error),
      RemoteException(:final message, :final statusCode) =>
        NetworkFailure(message, statusCode: statusCode, cause: error),
      CacheException(:final message) => CacheFailure(message, cause: error),
      ParsingException(:final message) => UnexpectedFailure(message, cause: error),
      _ => UnexpectedFailure('Hand tracking stopped unexpectedly.', cause: error),
    };
  }
}
