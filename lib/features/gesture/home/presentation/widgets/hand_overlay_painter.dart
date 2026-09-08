import 'package:flutter/material.dart';

import '../../domain/entity/hand_entity.dart';
import '../../domain/entity/hand_landmark_entity.dart';

/// Draws the hand skeleton over the preview.
///
/// Landmarks arrive normalised to the frame as displayed, so painting is a
/// straight multiply by the canvas size — as long as this paints over exactly
/// the same box the preview fills.
class HandOverlayPainter extends CustomPainter {
  HandOverlayPainter({
    required this.hands,
    required this.leftHandColor,
    required this.rightHandColor,
    required this.jointColor,
  });

  final List<HandEntity> hands;
  final Color leftHandColor;
  final Color rightHandColor;
  final Color jointColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final hand in hands) {
      final color = switch (hand.handedness) {
        Handedness.left => leftHandColor,
        Handedness.right => rightHandColor,
        Handedness.unknown => jointColor,
      };

      _paintBones(canvas, size, hand, color);
      _paintJoints(canvas, size, hand);
    }
  }

  void _paintBones(Canvas canvas, Size size, HandEntity hand, Color color) {
    final bonePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // A dark pass underneath keeps the skeleton readable over a bright scene.
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (final (from, to) in handSkeletonConnections) {
      final start = _toOffset(hand.landmark(from), size);
      final end = _toOffset(hand.landmark(to), size);
      path
        ..moveTo(start.dx, start.dy)
        ..lineTo(end.dx, end.dy);
    }

    canvas
      ..drawPath(path, shadowPaint)
      ..drawPath(path, bonePaint);
  }

  void _paintJoints(Canvas canvas, Size size, HandEntity hand) {
    final jointPaint = Paint()..color = jointColor;
    final tipPaint = Paint()..color = jointColor;

    for (var i = 0; i < hand.landmarks.length; i++) {
      final isTip = HandLandmarkType.tips.contains(HandLandmarkType.values[i]);
      canvas.drawCircle(
        _toOffset(hand.landmarks[i], size),
        isTip ? 6 : 3.5,
        isTip ? tipPaint : jointPaint,
      );
    }
  }

  Offset _toOffset(HandLandmarkEntity landmark, Size size) =>
      Offset(landmark.x * size.width, landmark.y * size.height);

  @override
  bool shouldRepaint(HandOverlayPainter oldDelegate) =>
      !identical(oldDelegate.hands, hands) ||
      oldDelegate.leftHandColor != leftHandColor ||
      oldDelegate.rightHandColor != rightHandColor;
}
