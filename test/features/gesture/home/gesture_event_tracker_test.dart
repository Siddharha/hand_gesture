import 'package:flutter_test/flutter_test.dart';

import 'package:hand_gesture/features/gesture/home/domain/entity/gesture_event_entity.dart';
import 'package:hand_gesture/features/gesture/home/domain/entity/hand_entity.dart';
import 'package:hand_gesture/features/gesture/home/domain/entity/hand_gesture_entity.dart';
import 'package:hand_gesture/features/gesture/home/domain/entity/hand_landmark_entity.dart';
import 'package:hand_gesture/features/gesture/home/presentation/viewmodel/gesture_event_tracker.dart';

HandEntity handWith(Handedness handedness) => HandEntity(
      landmarks: List.filled(21, const HandLandmarkEntity(x: 0, y: 0, z: 0)),
      handedness: handedness,
      score: 1,
    );

HandPoseEntity poseOf(HandGesture gesture, {Set<Finger> fingers = const {}}) =>
    HandPoseEntity(gesture: gesture, extendedFingers: fingers);

void main() {
  late GestureEventTracker tracker;

  setUp(() => tracker = GestureEventTracker());

  test('a new shape begins once, not once per frame', () {
    final hands = [handWith(Handedness.right)];
    final poses = [poseOf(HandGesture.openPalm)];

    final first = tracker.update(hands, poses);
    expect(first, hasLength(1));
    expect(first.single.type, GestureEventType.began);
    expect(first.single.gesture, HandGesture.openPalm);

    // Held for several more frames: nothing further is emitted.
    expect(tracker.update(hands, poses), isEmpty);
    expect(tracker.update(hands, poses), isEmpty);
  });

  test('changing shape ends the old one before beginning the new', () {
    final hands = [handWith(Handedness.right)];
    tracker.update(hands, [poseOf(HandGesture.fist)]);

    final events = tracker.update(hands, [poseOf(HandGesture.two)]);

    expect(events, hasLength(2));
    expect(events[0].type, GestureEventType.ended);
    expect(events[0].gesture, HandGesture.fist);
    expect(events[1].type, GestureEventType.began);
    expect(events[1].gesture, HandGesture.two);
  });

  test('a hand leaving the frame ends what it was holding', () {
    tracker.update([handWith(Handedness.left)], [poseOf(HandGesture.one)]);

    final events = tracker.update([], []);

    expect(events, hasLength(1));
    expect(events.single.type, GestureEventType.ended);
    expect(events.single.gesture, HandGesture.one);
    expect(events.single.handedness, Handedness.left);
  });

  test('an ended event reports how long the shape was held', () async {
    final hands = [handWith(Handedness.right)];
    tracker.update(hands, [poseOf(HandGesture.thumbsUp)]);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    final events = tracker.update(hands, [poseOf(HandGesture.fist)]);

    final ended = events.firstWhere((event) => event.isEnded);
    expect(ended.heldFor, greaterThanOrEqualTo(const Duration(milliseconds: 25)));
    expect(events.firstWhere((event) => event.isBegan).heldFor, Duration.zero);
  });

  test('two hands raise and drop gestures independently', () {
    final hands = [handWith(Handedness.left), handWith(Handedness.right)];

    final started = tracker.update(hands, [
      poseOf(HandGesture.fist),
      poseOf(HandGesture.openPalm),
    ]);
    expect(started.map((event) => event.handIndex), [0, 1]);

    // Only the second hand changes.
    final changed = tracker.update(hands, [
      poseOf(HandGesture.fist),
      poseOf(HandGesture.two),
    ]);

    expect(changed, hasLength(2));
    expect(changed.every((event) => event.handIndex == 1), isTrue);
    expect(changed[0].gesture, HandGesture.openPalm);
    expect(changed[1].gesture, HandGesture.two);
  });

  test('a changed finger count on an unnamed shape is still a change', () {
    final hands = [handWith(Handedness.right)];
    tracker.update(hands, [
      poseOf(HandGesture.unknown, fingers: {Finger.middle}),
    ]);

    final events = tracker.update(hands, [
      poseOf(HandGesture.unknown, fingers: {Finger.middle, Finger.ring}),
    ]);

    expect(events, hasLength(2));
    expect(events[0].pose.extendedCount, 1);
    expect(events[1].pose.extendedCount, 2);
    // Consumers filter these out with `isNamed` when they only want gestures.
    expect(events.every((event) => event.isNamed), isFalse);
  });

  test('reset ends everything in flight and then goes quiet', () {
    tracker.update(
      [handWith(Handedness.left), handWith(Handedness.right)],
      [poseOf(HandGesture.one), poseOf(HandGesture.two)],
    );

    final events = tracker.reset();

    expect(events, hasLength(2));
    expect(events.every((event) => event.isEnded), isTrue);
    expect(tracker.reset(), isEmpty);
  });

  test('after a reset the same shape begins again', () {
    final hands = [handWith(Handedness.right)];
    final poses = [poseOf(HandGesture.openPalm)];

    tracker.update(hands, poses);
    tracker.reset();

    final events = tracker.update(hands, poses);
    expect(events, hasLength(1));
    expect(events.single.type, GestureEventType.began);
  });
}
