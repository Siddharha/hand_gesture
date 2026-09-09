import 'package:flutter/material.dart';

import '../../domain/entity/hand_entity.dart';
import '../../domain/entity/hand_gesture_entity.dart';

/// Names each hand's shape and the confidence it was trusted on, pinned just
/// above the hand it describes.
///
/// Anchored per hand rather than shown in one corner: with two hands on screen
/// a single label cannot say which is which, and the answer is only useful next
/// to the thing it is about.
class GestureLabels extends StatelessWidget {
  const GestureLabels({
    super.key,
    required this.hands,
    required this.poses,
    required this.confidences,
  });

  final List<HandEntity> hands;

  /// Index-aligned with [hands]; a `null` entry leaves that hand unlabelled —
  /// it is on screen but its structure has not held together for long enough
  /// to name a shape from.
  final List<HandPoseEntity?> poses;

  /// Index-aligned with [hands]: how confident the model was on the frame that
  /// admitted each hand. Not the live per-frame score — a number that changes
  /// every frame cannot be read, and this one is what the decision rested on.
  final List<double?> confidences;

  /// Roughly the label's height in normalised units, used to lift it clear of
  /// the fingertips.
  static const _verticalOffset = 0.06;

  @override
  Widget build(BuildContext context) {
    if (hands.isEmpty || poses.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final children = <Widget>[];

        for (var i = 0; i < hands.length && i < poses.length; i++) {
          final pose = poses[i];
          if (pose == null) continue;

          final bounds = hands[i].bounds;

          // Above the hand, unless that would run off the top of the frame.
          final top = bounds.top - _verticalOffset;
          final anchorY = (top < 0 ? bounds.bottom + _verticalOffset / 2 : top)
              .clamp(0.0, 0.92);
          final centerX = ((bounds.left + bounds.right) / 2).clamp(0.0, 1.0);

          children.add(
            Positioned(
              left: centerX * constraints.maxWidth,
              top: anchorY * constraints.maxHeight,
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0),
                child: _Chip(
                  pose: pose,
                  handedness: hands[i].handedness,
                  confidence: i < confidences.length ? confidences[i] : null,
                ),
              ),
            ),
          );
        }

        return Stack(children: children);
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.pose,
    required this.handedness,
    required this.confidence,
  });

  final HandPoseEntity pose;
  final Handedness handedness;

  /// The score from the frame this hand was admitted on, in `[0, 1]`.
  final double? confidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = <String>[
      switch (handedness) {
        Handedness.left => 'Left',
        Handedness.right => 'Right',
        Handedness.unknown => '',
      },
      '${pose.extendedCount}',
      if (confidence != null) '${(confidence! * 100).toStringAsFixed(0)}%',
    ]..removeWhere((part) => part.isEmpty);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pose.label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            Text(
              details.join(' · '),
              style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
