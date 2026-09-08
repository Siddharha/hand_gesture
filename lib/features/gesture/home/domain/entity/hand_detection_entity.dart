import 'hand_entity.dart';

/// The result of running the pipeline over one frame.
class HandDetectionEntity {
  const HandDetectionEntity({
    required this.hands,
    required this.inferenceTime,
    this.latency = Duration.zero,
    this.usedDetector = false,
  });

  const HandDetectionEntity.empty()
      : hands = const [],
        inferenceTime = Duration.zero,
        latency = Duration.zero,
        usedDetector = false;

  final List<HandEntity> hands;

  /// Wall-clock time the frame spent in the pipeline, for the on-screen stats.
  final Duration inferenceTime;

  /// Age of the frame by the time its result was ready - capture to overlay.
  /// Always at least [inferenceTime]; the difference is queueing and transport.
  final Duration latency;

  /// Whether this frame ran the palm detector, or tracked from the previous
  /// frame's landmarks. Detector frames are the expensive ones.
  final bool usedDetector;

  bool get hasHands => hands.isNotEmpty;
}
