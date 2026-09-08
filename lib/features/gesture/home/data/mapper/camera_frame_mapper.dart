import 'package:camera/camera.dart';

import '../../../../../core/ml/frame_sampler.dart';
import '../../domain/entity/camera_frame_entity.dart';
import '../../domain/entity/camera_session_entity.dart';

/// Converts the plugin's types into the module's own vocabulary, so nothing
/// past the data layer imports `package:camera`.
abstract final class CameraFrameMapper {
  static CameraFrameEntity toEntity(
    CameraImage image, {
    required int rotationDegrees,
    required bool mirrored,
  }) {
    return CameraFrameEntity(
      planes: [
        for (final plane in image.planes)
          CameraPlaneEntity(
            bytes: plane.bytes,
            bytesPerRow: plane.bytesPerRow,
            bytesPerPixel: plane.bytesPerPixel ?? 1,
          ),
      ],
      format: _format(image.format.group),
      width: image.width,
      height: image.height,
      rotationDegrees: rotationDegrees,
      mirrored: mirrored,
      capturedAt: DateTime.now(),
    );
  }

  static CameraFrameFormat _format(ImageFormatGroup group) => switch (group) {
        ImageFormatGroup.bgra8888 => CameraFrameFormat.bgra8888,
        _ => CameraFrameFormat.yuv420,
      };

  /// The sampler's format enum, which mirrors the domain one.
  static FramePixelFormat toSamplerFormat(CameraFrameFormat format) =>
      switch (format) {
        CameraFrameFormat.bgra8888 => FramePixelFormat.bgra8888,
        CameraFrameFormat.yuv420 => FramePixelFormat.yuv420,
      };

  static List<FramePlane> toSamplerPlanes(List<CameraPlaneEntity> planes) => [
        for (final plane in planes)
          FramePlane(
            bytes: plane.bytes,
            bytesPerRow: plane.bytesPerRow,
            bytesPerPixel: plane.bytesPerPixel,
          ),
      ];

  static CameraLens toLens(CameraLensDirection direction) =>
      direction == CameraLensDirection.front ? CameraLens.front : CameraLens.back;

  static CameraLensDirection fromLens(CameraLens lens) =>
      lens == CameraLens.front
          ? CameraLensDirection.front
          : CameraLensDirection.back;
}
