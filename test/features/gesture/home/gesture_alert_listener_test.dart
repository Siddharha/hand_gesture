import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hand_gesture/features/gesture/home/data/di/home_di.dart';
import 'package:hand_gesture/features/gesture/home/domain/entity/gesture_event_entity.dart';
import 'package:hand_gesture/features/gesture/home/domain/entity/hand_entity.dart';
import 'package:hand_gesture/features/gesture/home/domain/entity/hand_gesture_entity.dart';
import 'package:hand_gesture/features/gesture/home/presentation/widgets/gesture_alert_listener.dart';

GestureEventEntity event(HandGesture gesture, {bool began = true}) =>
    GestureEventEntity(
      type: began ? GestureEventType.began : GestureEventType.ended,
      pose: HandPoseEntity(gesture: gesture, extendedFingers: const {}),
      handedness: Handedness.right,
      handIndex: 0,
      at: DateTime.now(),
    );

void main() {
  late StreamController<GestureEventEntity> events;

  setUp(() => events = StreamController<GestureEventEntity>.broadcast());
  tearDown(() => events.close());

  Future<void> pumpListener(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gestureEventsProvider.overrideWith((ref) => events.stream),
        ],
        child: const MaterialApp(
          home: GestureAlertListener(child: Scaffold(body: Text('camera'))),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('an open palm raises the alert', (tester) async {
    await pumpListener(tester);
    expect(find.byType(AlertDialog), findsNothing);

    events.add(event(HandGesture.openPalm));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Open palm detected'), findsOneWidget);
  });

  testWidgets('a fist dismisses it again', (tester) async {
    await pumpListener(tester);

    events.add(event(HandGesture.openPalm));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    events.add(event(HandGesture.fist));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('holding the palm does not stack alerts', (tester) async {
    await pumpListener(tester);

    // The tracker only emits on change, but a second hand or a re-entry can
    // produce another `began` while one is already open.
    events.add(event(HandGesture.openPalm));
    await tester.pumpAndSettle();
    events.add(event(HandGesture.openPalm));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);

    // One fist closes it: there is only ever one to close.
    events.add(event(HandGesture.fist));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a fist with no alert showing does nothing', (tester) async {
    await pumpListener(tester);

    events.add(event(HandGesture.fist));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('camera'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('other gestures are ignored', (tester) async {
    await pumpListener(tester);

    for (final gesture in [HandGesture.two, HandGesture.ok, HandGesture.four]) {
      events.add(event(gesture));
      await tester.pumpAndSettle();
    }

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the end of an open palm does not raise it', (tester) async {
    await pumpListener(tester);

    // `ended` fires as the hand moves on; acting on it would open the alert
    // exactly when the shape stopped.
    events.add(event(HandGesture.openPalm, began: false));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('after dismissing, a new open palm raises it again', (tester) async {
    await pumpListener(tester);

    events.add(event(HandGesture.openPalm));
    await tester.pumpAndSettle();
    events.add(event(HandGesture.fist));
    await tester.pumpAndSettle();

    events.add(event(HandGesture.openPalm));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('dismissing by hand leaves it able to reopen', (tester) async {
    await pumpListener(tester);

    events.add(event(HandGesture.openPalm));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    // The internal "is open" flag has to be cleared by the manual close too,
    // or the gesture would never open it again.
    events.add(event(HandGesture.openPalm));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
