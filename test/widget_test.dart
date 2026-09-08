import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hand_gesture/app/app.dart';
import 'package:hand_gesture/features/gesture/home/presentation/view/home_screen.dart';
import 'package:hand_gesture/features/gesture/splash/presentation/view/splash_screen.dart';

void main() {
  testWidgets('app starts on the splash screen and moves on to home',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HandGestureApp()));

    expect(find.byType(SplashScreen), findsOneWidget);

    // Let the session bootstrap and the minimum splash delay elapse. Pumped by
    // hand rather than settled: the camera screen shows a progress indicator,
    // which never settles.
    await tester.pump(const Duration(seconds: 1));
    // Past the route transition, so the splash is really gone rather than
    // still animating out.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('camera screen reports failure instead of hanging when no camera '
      'is available', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeScreen())),
    );

    // There is no camera plugin under flutter_test, so starting must fail
    // through the Result path rather than throwing out of the view model.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
