import 'package:flutter/services.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../core/resources/app_assets.dart';
import '../../domain/datasource/hand_detection_datasource.dart';
import '../../domain/entity/camera_frame_entity.dart';
import '../../domain/entity/hand_detection_entity.dart';
import '../../domain/entity/hand_entity.dart';
import '../mapper/camera_frame_mapper.dart';
import '../mapper/hand_mapper.dart';
import 'hand_pipeline.dart';
import 'hand_pipeline_isolate.dart';

/// Feeds camera frames to the TFLite pipeline running on its own isolate.
class TfLiteHandDetectionDataSource implements HandDetectionDataSource {
  TfLiteHandDetectionDataSource({
    this.config = const HandPipelineConfig(),
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  final HandPipelineConfig config;
  final AssetBundle _bundle;

  HandPipelineIsolate? _pipeline;

  @override
  Future<void> initialize() async {
    if (_pipeline != null) return;

    try {
      // Loaded here rather than in the isolate: asset loading needs the root
      // bundle, which belongs to the main isolate.
      final detector = await _loadModel(AppAssets.handDetectorModel);
      final landmark = await _loadModel(AppAssets.handLandmarkDetectorModel);

      _pipeline = await HandPipelineIsolate.spawn(
        detectorModel: detector,
        landmarkModel: landmark,
        config: config,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw DeviceException('The hand models could not be loaded.', cause: e);
    }
  }

  @override
  Future<HandDetectionEntity?> detect(CameraFrameEntity frame) async {
    final pipeline = _pipeline;
    if (pipeline == null) {
      throw const DeviceException('Hand detection was used before initialize().');
    }

    final pending = pipeline.process(_toPipelineFrame(frame));
    if (pending == null) return null; // Busy — drop this frame.

    final result = await pending;
    return _toEntity(result, frame);
  }

  @override
  void resetTracking() => _pipeline?.resetTracking();

  @override
  Future<void> close() async {
    final pipeline = _pipeline;
    _pipeline = null;
    await pipeline?.close();
  }

  HandPipelineFrame _toPipelineFrame(CameraFrameEntity frame) {
    return HandPipelineFrame(
      planes: CameraFrameMapper.toSamplerPlanes(frame.planes),
      format: CameraFrameMapper.toSamplerFormat(frame.format),
      width: frame.width,
      height: frame.height,
      rotationDegrees: frame.rotationDegrees,
      mirrored: frame.mirrored,
    );
  }

  HandDetectionEntity _toEntity(HandPipelineResult result, CameraFrameEntity frame) {
    final hands = <HandEntity>[
      for (final detection in result.detections)
        HandMapper.toEntity(
          model: detection.model,
          roi: detection.roi,
          aspectRatio: frame.uprightAspectRatio,
          mirrored: frame.mirrored,
        ),
    ];

    return HandDetectionEntity(
      hands: hands,
      inferenceTime: result.inferenceTime,
      latency: DateTime.now().difference(frame.capturedAt),
      usedDetector: result.usedDetector,
    );
  }

  Future<Uint8List> _loadModel(String assetPath) async {
    final data = await _bundle.load(assetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
