import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daynamic_flow/screens/clock/clock_screen.dart';
import 'package:daynamic_flow/state/app_scope.dart';
import 'package:daynamic_flow/state/app_state.dart';

void main() {
  Future<AppState> pumpClock(WidgetTester tester, {bool clockedIn = false}) async {
    final app = AppState();
    if (clockedIn) app.clockToggle();
    await tester.pumpWidget(
      AppScope(state: app, child: const MaterialApp(home: ClockScreen())),
    );
    return app;
  }

  testWidgets('ClockScreen opens without errors when clocked out', (
    WidgetTester tester,
  ) async {
    final app = await pumpClock(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('00:00:00'), findsOneWidget);
    expect(find.text(app.strings['clockIn'].toUpperCase()), findsOneWidget);
  });

  testWidgets('ClockScreen opens without errors when already clocked in', (
    WidgetTester tester,
  ) async {
    final app = await pumpClock(tester, clockedIn: true);

    expect(tester.takeException(), isNull);
    expect(find.text(app.strings['clockOut'].toUpperCase()), findsOneWidget);

    // Clock out so the periodic ticker is cancelled before the test ends.
    await tester.tap(find.text(app.strings['clockOut'].toUpperCase()));
    await tester.pump();
    expect(app.clockedIn, isFalse);
  });
}
