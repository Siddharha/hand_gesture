/// The five digits, in landmark order.
///
/// `indexFinger` rather than `index`: every Dart enum already has an `index`
/// member, and redeclaring it is a compile error.
enum Finger { thumb, indexFinger, middle, ring, pinky }

/// Hand shapes the recogniser can name.
///
/// Anything that does not match a known finger pattern comes back as
/// [HandGesture.unknown] — the finger count in [HandPoseEntity] is still valid,
/// so the UI can fall back to "3 fingers" rather than showing nothing.
enum HandGesture {
  fist('Fist'),
  thumbsUp('Thumbs up'),
  thumbsDown('Thumbs down'),
  one('One'),
  two('Two'),
  three('Three'),
  four('Four'),
  openPalm('Open palm'),
  rockOn('Rock on'),
  shaka('Shaka'),
  gun('Finger gun'),
  ok('OK'),
  unknown('Unknown');

  const HandGesture(this.label);

  /// Human-readable name, for display.
  final String label;
}

/// What one hand is doing: which fingers are out, and the shape that makes.
class HandPoseEntity {
  const HandPoseEntity({
    required this.gesture,
    required this.extendedFingers,
  });

  const HandPoseEntity.unknown()
      : gesture = HandGesture.unknown,
        extendedFingers = const <Finger>{};

  final HandGesture gesture;

  /// Which fingers are extended. A thumb folded across the palm is not.
  final Set<Finger> extendedFingers;

  int get extendedCount => extendedFingers.length;

  bool isExtended(Finger finger) => extendedFingers.contains(finger);

  /// What to show the user: the gesture's name, or a plain finger count when
  /// the shape is not one we name.
  String get label => gesture == HandGesture.unknown
      ? '$extendedCount ${extendedCount == 1 ? 'finger' : 'fingers'}'
      : gesture.label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HandPoseEntity &&
          other.gesture == gesture &&
          other.extendedFingers.length == extendedFingers.length &&
          other.extendedFingers.containsAll(extendedFingers);

  @override
  int get hashCode => Object.hash(gesture, Object.hashAllUnordered(extendedFingers));
}
