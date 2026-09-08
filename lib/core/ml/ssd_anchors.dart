import 'dart:math' as math;

/// One SSD anchor box, normalised to the model's input square.
class SsdAnchor {
  const SsdAnchor({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
  });

  final double centerX;
  final double centerY;
  final double width;
  final double height;
}

/// Configuration of MediaPipe's `SsdAnchorsCalculator`.
class SsdAnchorOptions {
  const SsdAnchorOptions({
    required this.inputWidth,
    required this.inputHeight,
    required this.strides,
    this.minScale = 0.1171875,
    this.maxScale = 0.75,
    this.anchorOffsetX = 0.5,
    this.anchorOffsetY = 0.5,
    this.aspectRatios = const [1.0],
    this.interpolatedScaleAspectRatio = 1.0,
    this.fixedAnchorSize = true,
  });

  /// Matches the bundled 256×256 palm detector, which scores 2944 anchors.
  const SsdAnchorOptions.palmDetection()
      : inputWidth = 256,
        inputHeight = 256,
        strides = const [8, 16, 32, 32, 32],
        minScale = 0.1171875,
        maxScale = 0.75,
        anchorOffsetX = 0.5,
        anchorOffsetY = 0.5,
        aspectRatios = const [1.0],
        interpolatedScaleAspectRatio = 1.0,
        fixedAnchorSize = true;

  final int inputWidth;
  final int inputHeight;
  final List<int> strides;
  final double minScale;
  final double maxScale;
  final double anchorOffsetX;
  final double anchorOffsetY;
  final List<double> aspectRatios;
  final double interpolatedScaleAspectRatio;
  final bool fixedAnchorSize;
}

/// Rebuilds the anchor grid the detector was trained against.
///
/// The model only emits offsets; without the identical anchor list the boxes
/// decode to nonsense. This is a direct port of MediaPipe's
/// `SsdAnchorsCalculator`, so the layer/stride bookkeeping is kept verbatim.
List<SsdAnchor> generateSsdAnchors(SsdAnchorOptions options) {
  final anchors = <SsdAnchor>[];
  final strides = options.strides;
  var layerId = 0;

  while (layerId < strides.length) {
    final anchorHeights = <double>[];
    final anchorWidths = <double>[];
    final aspectRatios = <double>[];
    final scales = <double>[];

    // Layers that share a stride contribute their anchors to the same grid.
    var lastSameStrideLayer = layerId;
    while (lastSameStrideLayer < strides.length &&
        strides[lastSameStrideLayer] == strides[layerId]) {
      final scale = _scaleAt(options, lastSameStrideLayer);

      for (final ratio in options.aspectRatios) {
        aspectRatios.add(ratio);
        scales.add(scale);
      }

      if (options.interpolatedScaleAspectRatio > 0) {
        final scaleNext = lastSameStrideLayer == strides.length - 1
            ? 1.0
            : _scaleAt(options, lastSameStrideLayer + 1);
        scales.add(math.sqrt(scale * scaleNext));
        aspectRatios.add(options.interpolatedScaleAspectRatio);
      }

      lastSameStrideLayer++;
    }

    for (var i = 0; i < aspectRatios.length; i++) {
      final ratioSqrt = math.sqrt(aspectRatios[i]);
      anchorHeights.add(scales[i] / ratioSqrt);
      anchorWidths.add(scales[i] * ratioSqrt);
    }

    final stride = strides[layerId];
    final featureMapHeight = (options.inputHeight / stride).ceil();
    final featureMapWidth = (options.inputWidth / stride).ceil();

    for (var y = 0; y < featureMapHeight; y++) {
      for (var x = 0; x < featureMapWidth; x++) {
        for (var anchorId = 0; anchorId < anchorHeights.length; anchorId++) {
          anchors.add(
            SsdAnchor(
              centerX: (x + options.anchorOffsetX) / featureMapWidth,
              centerY: (y + options.anchorOffsetY) / featureMapHeight,
              width: options.fixedAnchorSize ? 1.0 : anchorWidths[anchorId],
              height: options.fixedAnchorSize ? 1.0 : anchorHeights[anchorId],
            ),
          );
        }
      }
    }

    layerId = lastSameStrideLayer;
  }

  return anchors;
}

double _scaleAt(SsdAnchorOptions options, int layerIndex) {
  if (options.strides.length == 1) return (options.minScale + options.maxScale) / 2;
  return options.minScale +
      (options.maxScale - options.minScale) * layerIndex / (options.strides.length - 1);
}
