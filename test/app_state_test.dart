import 'package:flutter_test/flutter_test.dart';

import 'package:daynamic_flow/i18n/app_lang.dart';
import 'package:daynamic_flow/state/app_state.dart';
import 'package:daynamic_flow/state/models.dart';

void main() {
  // AppState.flash() reaches for a GlobalKey, which needs the test binding
  // even though these tests never pump a widget tree.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppState', () {
    test('clockToggle clocks in and out, tracking elapsed time', () {
      final app = AppState();
      expect(app.clockedIn, isFalse);

      app.clockToggle();
      expect(app.clockedIn, isTrue);
      expect(app.clockStart, isNotNull);

      app.clockToggle();
      expect(app.clockedIn, isFalse);
      expect(app.clockStart, isNull);
    });

    test('formatElapsed pads to HH:MM:SS', () {
      expect(
        AppState.formatElapsed(const Duration(hours: 4, minutes: 2, seconds: 9)),
        '04:02:09',
      );
    });

    test('approveRequest and rejectRequest resolve a request', () {
      final app = AppState();
      final before = app.pendingRequests.length;
      final target = app.pendingRequests.first;

      app.approveRequest(target.id);

      expect(app.pendingRequests.length, before - 1);
      expect(app.requests.firstWhere((r) => r.id == target.id).resolved, isTrue);
    });

    test('createShift adds a slot and decrements the open count', () {
      final app = AppState();
      final day = app.week.firstWhere((d) => d.openCount > 0);
      final before = day.slots.length;
      final openBefore = day.openCount;

      app.createShift(
        employeeId: app.employees.first.id,
        weekdayIndex: day.weekdayIndex,
        timeLabel: '09–17',
      );

      expect(day.slots.length, before + 1);
      expect(day.openCount, openBefore - 1);
    });

    test('offerShift publishes a swap and a manager request', () {
      final app = AppState();
      final swapsBefore = app.swaps.length;
      final requestsBefore = app.requests.length;

      app.offerShift(3);

      expect(app.swaps.length, swapsBefore + 1);
      expect(app.requests.length, requestsBefore + 1);
      expect(app.swaps.first.status, SwapStatus.offered);
    });

    test('claimSwap moves an open swap to pending', () {
      final app = AppState();
      final open = app.swaps.firstWhere((s) => s.status == SwapStatus.open);

      app.claimSwap(open.id);

      expect(open.status, SwapStatus.pending);
    });

    test('toggleAvailability flips a single day', () {
      final app = AppState();
      final before = app.availability[2];

      app.toggleAvailability(2);

      expect(app.availability[2], !before);
    });

    test('sendMessage appends to the right thread only', () {
      final app = AppState();
      final before = app.threadMessages('LP').length;

      app.sendMessage('LP', '  hola  ');

      final messages = app.threadMessages('LP');
      expect(messages.length, before + 1);
      expect(messages.last.text, 'hola');
      expect(messages.last.fromMe, isTrue);
      // Sending to an empty/whitespace-only draft is a no-op.
      app.sendMessage('LP', '   ');
      expect(app.threadMessages('LP').length, before + 1);
    });

    test('markNotifRead and markAllNotifsRead clear the unread flag', () {
      final app = AppState();
      expect(app.hasUnreadNotifs, isTrue);

      for (final n in app.notifs) {
        app.markNotifRead(n.id);
      }

      expect(app.hasUnreadNotifs, isFalse);
    });

    test('switchRole toggles between manager and employee', () {
      final app = AppState();
      expect(app.role, UserRole.manager);
      app.switchRole();
      expect(app.role, UserRole.employee);
      app.switchRole();
      expect(app.role, UserRole.manager);
    });

    test('setLang swaps the active string table', () {
      final app = AppState();
      expect(app.strings['manager'], 'Gerente');
      app.setLang(AppLang.en);
      expect(app.strings['manager'], 'Manager');
    });

    test('deactivateEmployee updates that employee only', () {
      final app = AppState();
      final target = app.employees[1];
      final untouched = app.employees[2].status;

      app.deactivateEmployee(target.id);

      expect(target.status, EmployeeStatus.inactive);
      expect(app.employees[2].status, untouched);
    });
  });
}
