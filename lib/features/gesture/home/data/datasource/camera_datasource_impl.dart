import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../../../../../core/error/app_exception.dart';
import '../../domain/datasource/camera_datasource.dart';
import '../../domain/entity/camera_frame_entity.dart';
import '../../domain/entity/camera_session_entity.dart';
import '../mapper/camera_frame_mapper.dart';

/// Drives the device camera through the `camera` plugin, which on Android is
/// backed by CameraX (`camera_android_camerax`).
///
/// The preview is locked to portrait so a frame's rotation is fully described
/// by the sensor orientation; without that lock every frame would need the
/// device orientation folded in as well.
class CameraDataSourceImpl implements CameraDataSource {
  CameraDataSourceImpl({this.resolution = ResolutionPreset.medium});

  /// Higher presets cost quadratically more per frame in sampling. Medium
  /// (720p or below) is plenty for a 256×256 model input.
  final ResolutionPreset resolution;

  final StreamController<CameraFrameEntity> _frames =
      StreamController<CameraFrameEntity>.broadcast();

  List<CameraDescription>? _available;
  CameraController? _controller;
  CameraLens _lens = CameraLens.back;

  /// The live controller, for `CameraPreview` only.
  ///
  /// This is the one plugin type the presentation layer sees: the preview is a
  /// platform texture and there is no way to render it without the controller.
  /// Nothing else should touch it.
  CameraController? get previewController => _controller;

  @override
  Stream<CameraFrameEntity> get frames => _frames.stream;

  @override
  Future<CameraSessionEntity> start({CameraLens lens = CameraLens.back}) async {
    await _disposeController();
    _lens = lens;

    final description = await _describe(lens);
    final controller = CameraController(
      description,
      resolution,
      enableAudio: false,
      imageFormatGroup: _preferredFormat,
    );

    try {
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.startImageStream(
        (image) => _onFrame(image, description),
      );
    } on CameraException catch (e) {
      await controller.dispose();
      throw _toException(e);
    }

    _controller = controller;
    return _toSession(controller, description);
  }

  @override
  Future<CameraSessionEntity> switchLens() {
    return start(lens: _lens == CameraLens.back ? CameraLens.front : CameraLens.back);
  }

  @override
  Future<void> stop() => _disposeController();

  @override
  Future<void> dispose() async {
    await _disposeController();
    await _frames.close();
  }

  void _onFrame(CameraImage image, CameraDescription description) {
    if (_frames.isClosed || !_frames.hasListener) return;

    _frames.add(
      CameraFrameMapper.toEntity(
        image,
        // Portrait-locked, so the sensor orientation is the whole story.
        rotationDegrees: description.sensorOrientation,
        mirrored: description.lensDirection == CameraLensDirection.front,
      ),
    );
  }

  Future<CameraDescription> _describe(CameraLens lens) async {
    final cameras = _available ??= await _listCameras();
    if (cameras.isEmpty) {
      throw const DeviceException('This device has no usable camera.');
    }

    final wanted = CameraFrameMapper.fromLens(lens);
    return cameras.firstWhere(
      (camera) => camera.lensDirection == wanted,
      orElse: () => cameras.first,
    );
  }

  Future<List<CameraDescription>> _listCameras() async {
    try {
      return await availableCameras();
    } on CameraException catch (e) {
      throw _toException(e);
    }
  }

  CameraSessionEntity _toSession(
    CameraController controller,
    CameraDescription description,
  ) {
    final preview = controller.value.previewSize ?? const Size(0, 0);
    // previewSize is reported in sensor orientation; a quarter turn swaps it.
    final swapsAxes = ((description.sensorOrientation ~/ 90) % 4).isOdd;

    return CameraSessionEntity(
      lens: CameraFrameMapper.toLens(description.lensDirection),
      previewWidth: swapsAxes ? preview.height : preview.width,
      previewHeight: swapsAxes ? preview.width : preview.height,
      sensorOrientation: description.sensorOrientation,
      isMirrored: description.lensDirection == CameraLensDirection.front,
    );
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } on CameraException {
      // Already torn down by the platform; disposing is still the right move.
    }
    await controller.dispose();
  }

  /// Android streams YUV420 planes, iOS streams BGRA. The sampler reads both.
  ImageFormatGroup get _preferredFormat =>
      Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420;

  AppException _toException(CameraException e) {
    const deniedCodes = {
      'CameraAccessDenied',
      'CameraAccessDeniedWithoutPrompt',
      'CameraAccessRestricted',
      'AudioAccessDenied',
    };

    if (deniedCodes.contains(e.code)) {
      return PermissionException(
        'Camera permission is required to track hands.',
        permission: 'camera',
        cause: e,
      );
    }

    return DeviceException(
      e.description ?? 'The camera could not be started.',
      cause: e,
    );
  }
}
