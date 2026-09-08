import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/di/core_providers.dart';
import '../../domain/datasource/camera_datasource.dart';
import '../../domain/datasource/hand_detection_datasource.dart';
import '../../domain/repository/hand_tracking_repository.dart';
import '../../domain/usecase/observe_hand_detections_usecase.dart';
import '../../domain/usecase/recognize_hand_gesture_usecase.dart';
import '../../domain/usecase/start_hand_tracking_usecase.dart';
import '../../domain/usecase/stop_hand_tracking_usecase.dart';
import '../../domain/usecase/switch_camera_usecase.dart';
import '../datasource/camera_datasource_impl.dart';
import '../datasource/hand_pipeline.dart';
import '../datasource/tflite_hand_detection_datasource.dart';
import '../repository/hand_tracking_repository_impl.dart';

/// Wiring for the home module. Providers are typed as their abstractions, so a
/// test can swap in a fake camera or a fake detector and change nothing else.

/// Tuning for the pipeline. Override this provider to trade accuracy for speed
/// on slower devices — `maxHands: 1` roughly halves the per-frame cost.
final handPipelineConfigProvider = Provider<HandPipelineConfig>(
  (ref) => const HandPipelineConfig(),
);

/// The concrete camera, exposed only so `CameraPreview` can reach its
/// controller. Everything else depends on [cameraDataSourceProvider].
final cameraDataSourceImplProvider = Provider<CameraDataSourceImpl>((ref) {
  final dataSource = CameraDataSourceImpl();
  ref.onDispose(dataSource.dispose);
  return dataSource;
});

final cameraDataSourceProvider = Provider<CameraDataSource>(
  (ref) => ref.watch(cameraDataSourceImplProvider),
);

final handDetectionDataSourceProvider = Provider<HandDetectionDataSource>((ref) {
  final dataSource = TfLiteHandDetectionDataSource(
    config: ref.watch(handPipelineConfigProvider),
  );
  ref.onDispose(dataSource.close);
  return dataSource;
});

final handTrackingRepositoryProvider = Provider<HandTrackingRepository>(
  (ref) => HandTrackingRepositoryImpl(
    cameraDataSource: ref.watch(cameraDataSourceProvider),
    detectionDataSource: ref.watch(handDetectionDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

/// Pure logic over landmarks the caller already has, so it needs nothing
/// injected and never fails.
final recognizeHandGestureUseCaseProvider = Provider<RecognizeHandGestureUseCase>(
  (ref) => const RecognizeHandGestureUseCase(),
);

final startHandTrackingUseCaseProvider = Provider<StartHandTrackingUseCase>(
  (ref) => StartHandTrackingUseCase(ref.watch(handTrackingRepositoryProvider)),
);

final stopHandTrackingUseCaseProvider = Provider<StopHandTrackingUseCase>(
  (ref) => StopHandTrackingUseCase(ref.watch(handTrackingRepositoryProvider)),
);

final switchCameraUseCaseProvider = Provider<SwitchCameraUseCase>(
  (ref) => SwitchCameraUseCase(ref.watch(handTrackingRepositoryProvider)),
);

final observeHandDetectionsUseCaseProvider = Provider<ObserveHandDetectionsUseCase>(
  (ref) => ObserveHandDetectionsUseCase(ref.watch(handTrackingRepositoryProvider)),
);
