import 'package:flutter/material.dart';

import '../../domain/entity/hand_detection_entity.dart';
import '../../domain/entity/hand_entity.dart';

/// Live readout of what the pipeline is doing: how many hands, how fast, and
/// whether the expensive detector stage ran on the last frame.
class DetectionStatsBar extends StatelessWidget {
  const DetectionStatsBar({
    super.key,
    required this.detection,
    required this.analysisFps,
  });

  final HandDetectionEntity detection;
  final double analysisFps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inferenceMs = detection.inferenceTime.inMicroseconds / 1000;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: DefaultTextStyle(
          style: theme.textTheme.labelMedium!.copyWith(color: Colors.white),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Stat(
                label: 'Hands',
                value: detection.hands.isEmpty
                    ? '—'
                    : detection.hands.map(_shortHandedness).join(' · '),
              ),
              const _Divider(),
              _Stat(label: 'Analysis', value: '${analysisFps.toStringAsFixed(1)} fps'),
              const _Divider(),
              _Stat(label: 'Inference', value: '${inferenceMs.toStringAsFixed(0)} ms'),
              const _Divider(),
              _Stat(label: 'Lag', value: '${detection.latency.inMilliseconds} ms'),
              const _Divider(),
              _Stat(
                label: 'Stage',
                value: detection.usedDetector ? 'detect' : 'track',
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _shortHandedness(HandEntity hand) => switch (hand.handedness) {
        Handedness.left => 'L',
        Handedness.right => 'R',
        Handedness.unknown => '?',
      };
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 9, letterSpacing: 0.8, color: Colors.white70),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white24,
      );
}
