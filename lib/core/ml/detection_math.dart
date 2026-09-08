import 'dart:math' as math;

import 'geometry.dart';

/// Logistic activation, clipped first so `exp` cannot overflow.
double sigmoid(double x, {double clipThreshold = 100.0}) {
  final clipped = x.clamp(-clipThreshold, clipThreshold);
  return 1.0 / (1.0 + math.exp(-clipped));
}

/// A model output that is sometimes already activated.
///
/// The bundled models are vendor conversions and their `scores`/`lr` heads may
/// or may not include the final sigmoid. A value already inside `[0, 1]` is
/// taken as a probability; anything else is treated as a logit.
double asProbability(double raw) => raw >= 0.0 && raw <= 1.0 ? raw : sigmoid(raw);

/// A scored candidate box awaiting suppression.
class ScoredBox {
  const ScoredBox({required this.index, required this.score, required this.rect});

  final int index;
  final double score;
  final NormalizedRect rect;
}

/// Classic greedy non-max suppression: keep the best box, drop everything that
/// overlaps it beyond [iouThreshold], repeat.
List<ScoredBox> nonMaxSuppression(
  List<ScoredBox> boxes, {
  double iouThreshold = 0.3,
  int maxResults = 4,
}) {
  if (boxes.isEmpty) return const [];

  final sorted = [...boxes]..sort((a, b) => b.score.compareTo(a.score));
  final kept = <ScoredBox>[];

  for (final candidate in sorted) {
    if (kept.length >= maxResults) break;

    final overlaps = kept.any(
      (keeper) => keeper.rect.iou(candidate.rect) > iouThreshold,
    );
    if (!overlaps) kept.add(candidate);
  }

  return kept;
}
