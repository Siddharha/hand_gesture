import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../../../core/ml/frame_sampler.dart';
import '../../../../../core/ml/geometry.dart';
import '../../../../../core/ml/hand_roi.dart';
import '../../../../../core/ml/ssd_anchors.dart';
import '../../../../../core/resources/hand_model_resources.dart';
import '../../../../../core/resources/tflite_model_spec.dart';
import '../model/hand_landmark_model.dart';
import '../model/palm_detection_model.dart';

/// A frame handed to the pipeline. Plain data so it can cross an isolate port.
class HandPipelineFrame {
  const HandPipelineFrame({
    required this.planes,
    required this.format,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.mirrored,
  });

  final List<FramePlane> planes;
  final FramePixelFormat format;
  final int width;
  final int height;
  final int rotationDegrees;
  final bool mirrored;

  bool get swapsAxes => ((rotationDegrees ~/ 90) % 4).isOdd;

  int get uprightWidth => swapsAxes ? height : width;

  int get uprightHeight => swapsAxes ? width : height;

  double get uprightAspectRatio => uprightWidth / uprightHeight;
}

/// One hand the pipeline found, with the crop it was measured in.
class HandPipelineDetection {
  const HandPipelineDetection({required this.model, required this.roi});

  final HandLandmarkModel model;
  final RotatedRect roi;
}

class HandPipelineResult {
  const HandPipelineResult({
    required this.detections,
    required this.inferenceTime,
    required this.samplingTime,
    required this.usedDetector,
  });

  const HandPipelineResult.empty()
      : detections = const [],
        inferenceTime = Duration.zero,
        samplingTime = Duration.zero,
        usedDetector = false;

  final List<HandPipelineDetection> detections;
  final Duration inferenceTime;

  /// The share of [inferenceTime] spent turning frames into tensors rather than
  /// running the models - which of the two to optimise is not obvious up front.
  final Duration samplingTime;
  final bool usedDetector;
}

class HandPipelineConfig {
  const HandPipelineConfig({
    this.maxHands = 2,
    this.palmScoreThreshold = 0.5,
    this.landmarkScoreThreshold = 0.5,
    this.redetectInterval = 90,
    this.threads = 4,
    this.useGpu = true,
  });

  final int maxHands;
  final double palmScoreThreshold;

  /// Below this the hand is considered lost and tracking restarts.
  final double landmarkScoreThreshold;

  /// How many tracked frames may pass before the palm detector runs again to
  /// look for hands that have entered the scene.
  ///
  /// A detector pass costs several times a tracked frame, so this is a visible
  /// hitch, not a background cost: at 30 frames it fires about once a second
  /// while a single hand is tracked, which reads as stutter. Spacing it out
  /// trades how quickly a second hand is noticed for a steady frame time.
  final int redetectInterval;

  final int threads;

  /// Try the GPU delegate first. Falls back to CPU when the device cannot
  /// provide it; set false to force CPU.
  final bool useGpu;
}

/// The two-stage MediaPipe hand pipeline.
///
/// Stage 1 (palm detector) is expensive and only runs when tracking is lost, or
/// periodically to pick up hands that have entered the scene. Stage 2
/// (landmarks) runs on a crop derived from the previous frame's landmarks,
/// which is what makes per-frame tracking affordable.
///
/// Pure Dart on purpose: no Flutter imports, so it runs inside an isolate and
/// can be driven directly from tests.
class HandPipeline {
  HandPipeline._(this._detector, this._landmark, this.config)
      : _anchors = generateSsdAnchors(const SsdAnchorOptions.palmDetection()) {
    _detectorOutputs = _resolveOutputs(_detector, _detectorRoles);
    _landmarkOutputs = _resolveOutputs(_landmark, _landmarkRoles);
    _detectorInput = Float32List(_tensorLength(HandModelResources.detector.inputShape));
    _landmarkInput =
        Float32List(_tensorLength(HandModelResources.landmarkDetector.inputShape));

    // Role matching is the one part of the setup that fails silently: swap
    // "scores" and "lr" and every hand is simply rejected. Report it in debug
    // builds so the mapping can be eyeballed against metadata.json.
    assert(() {
      _logOutputBinding('detector', _detector, _detectorOutputs);
      _logOutputBinding('landmark', _landmark, _landmarkOutputs);
      return true;
    }());
  }

  static void _logOutputBinding(
    String label,
    Interpreter interpreter,
    Map<String, int> roles,
  ) {
    final tensors = interpreter.getOutputTensors();
    final described = roles.entries.map(
      (role) => '${role.key} -> [${role.value}] '
          '${tensors[role.value].name} ${tensors[role.value].shape}',
    );
    // print rather than developer.log: this has to be readable over adb
    // logcat while debugging on a device, and it is compiled out of release
    // builds along with the assert that calls it.
    // ignore: avoid_print
    print('HandPipeline $label outputs: ${described.join(', ')}');
  }

  /// Builds a pipeline from model bytes — the form that survives an isolate
  /// hop, unlike an asset key or a file path.
  factory HandPipeline.fromBuffers({
    required Uint8List detectorModel,
    required Uint8List landmarkModel,
    HandPipelineConfig config = const HandPipelineConfig(),
  }) {
    return HandPipeline._(
      _interpreter(detectorModel, config),
      _interpreter(landmarkModel, config),
      config,
    );
  }

  /// Builds an interpreter, preferring the GPU.
  ///
  /// These are float models at 256×256; on the CPU each pass costs well over
  /// 100 ms, which caps the pipeline at a few frames a second. GPU support
  /// varies by device and driver and fails at delegate-creation or first
  /// invocation, so a CPU interpreter is built instead rather than letting the
  /// whole feature die.
  static Interpreter _interpreter(Uint8List model, HandPipelineConfig config) {
    if (config.useGpu) {
      try {
        return Interpreter.fromBuffer(
          model,
          options: InterpreterOptions()
            ..threads = config.threads
            ..addDelegate(
              GpuDelegateV2(
                options: GpuDelegateOptionsV2(
                  // The delegate defaults to full fp32 at MAX_PRECISION, which
                  // is the wrong trade for a live camera: these are detection
                  // models feeding an overlay, not a numerical workload, and
                  // fp16 roughly halves the GPU pass.
                  isPrecisionLossAllowed: true,
                  inferencePreference: _gpuPreferenceSustainedSpeed,
                  inferencePriority1: _gpuPriorityMinLatency,
                  // The detector splits into two partitions because one
                  // TRANSPOSE_CONV version is unsupported; the default cap of 1
                  // leaves the second partition running on the CPU.
                  maxDelegatePartitions: 4,
                ),
              ),
            ),
        );
      } catch (error, stackTrace) {
        developer.log(
          'GPU delegate unavailable, falling back to CPU.',
          name: 'HandPipeline',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return Interpreter.fromBuffer(
      model,
      options: InterpreterOptions()..threads = config.threads,
    );
  }

  final Interpreter _detector;
  final Interpreter _landmark;
  final List<SsdAnchor> _anchors;
  final HandPipelineConfig config;

  late final Map<String, int> _detectorOutputs;
  late final Map<String, int> _landmarkOutputs;
  late final Float32List _detectorInput;
  late final Float32List _landmarkInput;

  /// Where each hand was last seen. Empty means "run the detector".
  List<RotatedRect> _trackedRois = const [];
  int _framesSinceDetection = 0;

  /// Debug-only instrumentation; compiled out of release builds.
  ///
  /// `stage` tells detector frames from tracked ones, and `scores` lists every
  /// landmark confidence including the rejected ones - the first thing to look
  /// at when hands are found but immediately dropped.
  /// Values from the TFLite GPU delegate C API (`delegates/gpu/delegate.h`).
  /// tflite_flutter takes them as plain ints and does not export its generated
  /// enums, so they are pinned here rather than reached for through its `src/`.
  static const _gpuPreferenceSustainedSpeed = 1;
  static const _gpuPriorityMinLatency = 2;

  final Stopwatch _samplingTime = Stopwatch();

  static const _debugEveryNFrames = 30;
  int _debugFrame = 0;
  final List<double> _debugScores = [];

  /// Role to expected last dimension; -1 marks a scalar head whose shape says
  /// nothing useful.
  static const _detectorRoles = {'box_coords': 18, 'box_scores': 1};
  static const _landmarkRoles = {'landmarks': 3, 'scores': -1, 'lr': -1};

  void resetTracking() {
    _trackedRois = const [];
    _framesSinceDetection = 0;
  }

  HandPipelineResult process(HandPipelineFrame frame) {
    final stopwatch = Stopwatch()..start();
    _samplingTime.reset();
    final aspectRatio = frame.uprightAspectRatio;

    var rois = _trackedRois;
    var usedDetector = false;

    final shouldRedetect = rois.isEmpty ||
        (rois.length < config.maxHands &&
            _framesSinceDetection >= config.redetectInterval);

    if (shouldRedetect) {
      rois = _detectPalms(frame, aspectRatio);
      usedDetector = true;
      _framesSinceDetection = 0;
    } else {
      _framesSinceDetection++;
    }

    final detections = <HandPipelineDetection>[];
    final nextRois = <RotatedRect>[];

    assert(() {
      _debugScores.clear();
      return true;
    }());

    for (final roi in rois.take(config.maxHands)) {
      final model = _runLandmarks(frame, roi);
      assert(() {
        _debugScores.add(model.score);
        return true;
      }());
      if (model.score < config.landmarkScoreThreshold) continue;

      detections.add(HandPipelineDetection(model: model, roi: roi));

      // Next frame looks where this hand ended up, skipping the detector.
      final framePoints = [
        for (final (x, y, _) in model.landmarks) roi.toImageSpace(x, y, aspectRatio),
      ];
      nextRois.add(
        HandRoi.fromLandmarks(landmarks: framePoints, aspectRatio: aspectRatio),
      );
    }

    _trackedRois = nextRois;
    if (nextRois.isEmpty) _framesSinceDetection = 0;

    assert(() {
      _debugFrame++;
      if (_debugFrame % _debugEveryNFrames == 0) {
        final roi = detections.isEmpty
            ? ''
            : ' rot=${detections.first.roi.rotation.toStringAsFixed(2)}'
                ' roi=${detections.first.roi.width.toStringAsFixed(2)}';
        // ignore: avoid_print
        print('HandPipeline frame $_debugFrame '
            'stage=${usedDetector ? "detect" : "track"} '
            'rois=${rois.length} kept=${detections.length} '
            'scores=${_debugScores.map((s) => s.toStringAsFixed(3)).toList()}'
            ' total=${stopwatch.elapsedMilliseconds}ms'
            ' sample=${_samplingTime.elapsedMilliseconds}ms'
            '$roi');
      }
      return true;
    }());

    return HandPipelineResult(
      detections: detections,
      inferenceTime: stopwatch.elapsed,
      samplingTime: _samplingTime.elapsed,
      usedDetector: usedDetector,
    );
  }

  /// Stage 1: full frame in, hand crops out.
  List<RotatedRect> _detectPalms(HandPipelineFrame frame, double aspectRatio) {
    final spec = HandModelResources.detector;
    final frameRoi = FrameSampler.fullFrameRoi(
      frameWidth: frame.width,
      frameHeight: frame.height,
      rotationDegrees: frame.rotationDegrees,
    );

    _sampleInto(_detectorInput, frame, frameRoi, spec);

    final boxCoords = Float32List(_tensorLength(spec.outputs['box_coords']!));
    final boxScores = Float32List(_tensorLength(spec.outputs['box_scores']!));

    _detector.runForMultipleInputs([
      _detectorInput.buffer.asUint8List(),
    ], {
      _detectorOutputs['box_coords']!: boxCoords.buffer.asUint8List(),
      _detectorOutputs['box_scores']!: boxScores.buffer.asUint8List(),
    });

    final palms = PalmDetectionDecoder.decode(
      boxCoords: boxCoords,
      boxScores: boxScores,
      anchors: _anchors,
      inputSize: spec.inputWidth,
      scoreThreshold: config.palmScoreThreshold,
      maxResults: config.maxHands,
    );

    // Detector coordinates are relative to its square, letterboxed input; lift
    // them into frame space before building crops.
    return [
      for (final palm in palms)
        HandRoi.fromPalmDetection(
          box: _toFrameSpace(palm.box, frameRoi),
          keypoints: [
            for (final (x, y) in palm.keypoints)
              frameRoi.toImageSpace(x, y, aspectRatio),
          ],
          aspectRatio: aspectRatio,
        ),
    ];
  }

  /// Stage 2: one hand crop in, 21 landmarks out.
  HandLandmarkModel _runLandmarks(HandPipelineFrame frame, RotatedRect roi) {
    final spec = HandModelResources.landmarkDetector;
    _sampleInto(_landmarkInput, frame, roi, spec);

    final landmarks = Float32List(_tensorLength(spec.outputs['landmarks']!));
    final scores = Float32List(_tensorLength(spec.outputs['scores']!));
    final handedness = Float32List(_tensorLength(spec.outputs['lr']!));

    _landmark.runForMultipleInputs([
      _landmarkInput.buffer.asUint8List(),
    ], {
      _landmarkOutputs['landmarks']!: landmarks.buffer.asUint8List(),
      _landmarkOutputs['scores']!: scores.buffer.asUint8List(),
      _landmarkOutputs['lr']!: handedness.buffer.asUint8List(),
    });

    return HandLandmarkDecoder.decode(
      landmarks: landmarks,
      rawScore: scores.first,
      rawHandedness: handedness.first,
    );
  }

  void _sampleInto(
    Float32List target,
    HandPipelineFrame frame,
    RotatedRect roi,
    TfLiteModelSpec spec,
  ) {
    _samplingTime.start();
    FrameSampler.sampleRoi(
      planes: frame.planes,
      format: frame.format,
      frameWidth: frame.width,
      frameHeight: frame.height,
      rotationDegrees: frame.rotationDegrees,
      mirror: frame.mirrored,
      roi: roi,
      outputSize: spec.inputWidth,
      valueRange: spec.inputRange,
      // Reuse the interpreter's input buffer: a fresh 590KB tensor per frame,
      // then copied, is pure waste at this rate.
      into: target,
    );
    _samplingTime.stop();
  }

  /// Maps a rect from a ROI's local space into frame space. Only valid for an
  /// unrotated ROI, which is all the detector's letterbox is.
  static NormalizedRect _toFrameSpace(NormalizedRect rect, RotatedRect roi) {
    final originX = roi.centerX - roi.width / 2;
    final originY = roi.centerY - roi.height / 2;

    return NormalizedRect(
      left: originX + rect.left * roi.width,
      top: originY + rect.top * roi.height,
      width: rect.width * roi.width,
      height: rect.height * roi.height,
    );
  }

  /// Matches this model's output tensors to the roles the pipeline needs.
  ///
  /// Tensor order is not guaranteed across conversions, so roles are resolved
  /// by shape where that is unambiguous, then by tensor name, then by
  /// declaration order as a last resort.
  static Map<String, int> _resolveOutputs(
    Interpreter interpreter,
    Map<String, int> roles,
  ) {
    final tensors = interpreter.getOutputTensors();
    final resolved = <String, int>{};
    final taken = <int>{};

    // Unambiguous shapes first.
    for (final entry in roles.entries.where((role) => role.value > 0)) {
      for (var i = 0; i < tensors.length; i++) {
        if (taken.contains(i)) continue;
        if (tensors[i].shape.last == entry.value) {
          resolved[entry.key] = i;
          taken.add(i);
          break;
        }
      }
    }

    // Then names, for heads that share a shape.
    final remaining = roles.keys.where((role) => !resolved.containsKey(role)).toList();
    for (final role in [...remaining]) {
      for (var i = 0; i < tensors.length; i++) {
        if (taken.contains(i)) continue;
        if (tensors[i].name.toLowerCase().contains(role)) {
          resolved[role] = i;
          taken.add(i);
          remaining.remove(role);
          break;
        }
      }
    }

    // Whatever is left keeps the order the model declares it in.
    final free = [
      for (var i = 0; i < tensors.length; i++)
        if (!taken.contains(i)) i,
    ];
    for (var i = 0; i < remaining.length && i < free.length; i++) {
      resolved[remaining[i]] = free[i];
    }

    for (final role in roles.keys) {
      if (!resolved.containsKey(role)) {
        throw StateError('Model is missing the "$role" output tensor.');
      }
    }

    return resolved;
  }

  static int _tensorLength(List<int> shape) =>
      shape.fold<int>(1, (product, dimension) => product * dimension);

  void close() {
    _detector.close();
    _landmark.close();
  }
}
