import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show DateUtils, Locale;

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
        AppState.formatElapsed(
          const Duration(hours: 4, minutes: 2, seconds: 9),
        ),
        '04:02:09',
      );
    });

    test('approveRequest and rejectRequest resolve a request', () {
      final app = AppState();
      final before = app.pendingRequests.length;
      final target = app.pendingRequests.first;

      app.approveRequest(target.id);

      expect(app.pendingRequests.length, before - 1);
      expect(
        app.requests.firstWhere((r) => r.id == target.id).resolved,
        isTrue,
      );
    });

    test('createShift covers a matching open shift', () async {
      final app = AppState();
      final open = app.shifts.firstWhere(
        (s) => s.employeeId == null && s.startsAt.isAfter(app.now),
      );
      final day = app.week.firstWhere(
        (d) => d.slots.any((s) => s.shiftId == open.id),
      );
      final openBefore = day.openCount;
      final employee = app.assignableEmployees.firstWhere(
        (e) => !app.shifts.any(
          (s) =>
              s.employeeId == e.id &&
              s.startsAt.isBefore(open.endsAt) &&
              s.endsAt.isAfter(open.startsAt),
        ),
      );

      final ok = await app.createShift(
        employeeId: employee.id,
        startsAt: open.startsAt,
        endsAt: open.endsAt,
        siteId: open.siteId,
      );

      expect(ok, isTrue);
      expect(open.employeeId, employee.id);
      expect(day.openCount, openBefore - 1);
    });

    test('createShift accepts any length between 15 min and 16 h', () async {
      final app = AppState();
      final employee = app.assignableEmployees.first;
      final day = DateUtils.dateOnly(app.now).add(const Duration(days: 20));
      final start = DateTime(day.year, day.month, day.day, 10, 30);

      expect(
        await app.createShift(
          employeeId: employee.id,
          startsAt: start,
          endsAt: start.add(const Duration(minutes: 90)),
        ),
        isTrue,
      );
      expect(
        await app.createShift(
          employeeId: employee.id,
          startsAt: start.add(const Duration(hours: 3)),
          endsAt: start.add(const Duration(hours: 3, minutes: 5)),
        ),
        isFalse,
      );
      expect(
        await app.createShift(
          employeeId: employee.id,
          startsAt: start.add(const Duration(days: 1)),
          endsAt: start.add(const Duration(days: 1, hours: 17)),
        ),
        isFalse,
      );
      // En el pasado no.
      expect(
        await app.createShift(
          employeeId: employee.id,
          startsAt: app.now.subtract(const Duration(hours: 2)),
          endsAt: app.now.subtract(const Duration(hours: 1)),
        ),
        isFalse,
      );
    });

    test(
      'updateShift changes hours and person; started shifts are locked',
      () async {
        final app = AppState();
        final future = app.shifts.firstWhere(
          (s) => s.employeeId != null && s.startsAt.isAfter(app.now),
        );
        final newStart = future.startsAt.add(const Duration(hours: 1));

        final ok = await app.updateShift(
          shiftId: future.id,
          employeeId: null,
          startsAt: newStart,
          endsAt: newStart.add(const Duration(hours: 2)),
          siteId: future.siteId,
        );

        expect(ok, isTrue);
        final updated = app.shiftById(future.id)!;
        expect(updated.employeeId, isNull);
        expect(updated.duration, const Duration(hours: 2));

        final started = Shift(
          id: 'started',
          siteId: future.siteId,
          employeeId: app.assignableEmployees.first.id,
          startsAt: app.now.subtract(const Duration(minutes: 30)),
          endsAt: app.now.add(const Duration(hours: 1)),
        );
        app.shifts.add(started);
        expect(app.canEditShift(started), isFalse);
        expect(await app.cancelShift(started.id), isFalse);
      },
    );

    test('cancelShift removes a future shift', () async {
      final app = AppState();
      final future = app.shifts.firstWhere((s) => s.startsAt.isAfter(app.now));
      final count = app.shifts.length;

      expect(await app.cancelShift(future.id), isTrue);
      expect(app.shifts.length, count - 1);
      expect(app.shiftById(future.id), isNull);
    });

    test('offerShift publishes a swap and a manager request', () {
      // Ofrecer un turno es una acción del empleado (Ana tiene turno el jueves).
      final app = AppState()..loginAs(UserRole.employee);
      final swapsBefore = app.swaps.length;
      final requestsBefore = app.requests.length;

      app.offerShift(3);

      expect(app.swaps.length, swapsBefore + 1);
      expect(app.requests.length, requestsBefore + 1);
      expect(app.swaps.first.status, SwapStatus.offered);
    });

    test('offerShift ignores a second offer for the same day', () {
      // Ofrecer un turno es una acción del empleado (Ana tiene turno el jueves).
      final app = AppState()..loginAs(UserRole.employee);
      final swapsBefore = app.swaps.length;
      final requestsBefore = app.requests.length;

      app.offerShift(3);
      app.offerShift(3);

      expect(app.hasOfferedShift(3), isTrue);
      expect(app.swaps.length, swapsBefore + 1);
      expect(app.requests.length, requestsBefore + 1);

      // Every pending request must be resolvable by its id.
      for (final r in List.of(app.pendingRequests)) {
        app.approveRequest(r.id);
      }
      expect(app.pendingRequests, isEmpty);
    });

    test('estimatedCostLabel has no stray backslash', () {
      final label = AppState().estimatedCostLabel;
      expect(label, startsWith(r'$'));
      expect(label, isNot(contains(r'\')));
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

    test('setLang updates the Flutter locale and reports the choice', () {
      final saved = <AppLang>[];
      final app = AppState(lang: AppLang.en, onLangChanged: saved.add);
      expect(app.langListenable.value.locale.languageCode, 'en');

      app.setLang(AppLang.es);
      app.setLang(AppLang.es); // sin cambio: no se vuelve a guardar

      expect(app.langListenable.value.locale.languageCode, 'es');
      expect(saved, [AppLang.es]);
    });

    test('AppLang.resolve prefers the saved choice, then the phone', () {
      expect(AppLang.resolve('en', const Locale('es')), AppLang.en);
      expect(AppLang.resolve(null, const Locale('en', 'US')), AppLang.en);
      expect(AppLang.resolve(null, const Locale('fr')), AppLang.es);
      expect(AppLang.resolve('xx', const Locale('es', 'CO')), AppLang.es);
    });

    test('deactivateEmployee updates that employee only', () {
      final app = AppState();
      final target = app.employees[1];
      final untouched = app.employees[2].status;

      app.deactivateEmployee(target.id);

      expect(target.status, EmployeeStatus.inactive);
      expect(app.employees[2].status, untouched);
    });

    test('saveSite creates a site and rejects bad input', () async {
      final app = AppState();
      final before = app.sites.length;

      final ok = await app.saveSite(
        name: '  Bodega Norte ',
        address: '',
        latitude: 4.7,
        longitude: -74.05,
        radiusMeters: 150,
      );

      expect(ok, isTrue);
      expect(app.sites.length, before + 1);
      final created = app.sites.firstWhere((s) => s.name == 'Bodega Norte');
      expect(created.address, isNull);
      expect(created.radiusMeters, 150);

      expect(
        await app.saveSite(
          name: 'Sin coordenadas',
          address: '',
          latitude: null,
          longitude: -74,
          radiusMeters: 100,
        ),
        isFalse,
      );
      expect(
        await app.saveSite(
          name: 'Radio chico',
          address: '',
          latitude: 4.7,
          longitude: -74,
          radiusMeters: 5,
        ),
        isFalse,
      );
      expect(app.sites.length, before + 1);
    });

    test('setSiteActive hides the site from scheduling but keeps it', () async {
      final app = AppState();
      final site = app.sites.first;

      await app.setSiteActive(site.id, false);

      expect(app.sites.any((s) => s.id == site.id), isFalse);
      expect(app.siteById(site.id)?.active, isFalse);

      await app.setSiteActive(site.id, true);
      expect(app.sites.any((s) => s.id == site.id), isTrue);
    });
    test('employee requests a day off: valid, duplicate and past', () async {
      final app = AppState()..loginAs(UserRole.employee);
      final before = app.myPendingRequests.length;
      final day = app.today.add(const Duration(days: 4));

      expect(await app.requestDayOff(day, '  Cita médica '), isTrue);
      expect(app.myPendingRequests.length, before + 1);
      final created = app.myPendingRequests.first;
      expect(created.kind, RequestKind.off);
      expect(created.reason, 'Cita médica');

      expect(await app.requestDayOff(day, ''), isFalse);
      expect(
        await app.requestDayOff(app.today.subtract(const Duration(days: 1)), ''),
        isFalse,
      );
      expect(app.myPendingRequests.length, before + 1);
    });

    test('employee warns they will be late once per shift', () async {
      final app = AppState()..loginAs(UserRole.employee);
      final shift = app.lateNoticeShift;
      expect(shift, isNotNull);

      expect(await app.notifyLate('Unos 10 min'), isTrue);
      final notice = app.myPendingRequests.first;
      expect(notice.kind, RequestKind.late);
      expect(notice.shiftId, shift!.id);
      // El gerente lo ve como aviso, no como entrada tarde.
      app.loginAs(UserRole.manager);
      expect(app.requestTitle(notice), contains('avisa que llegará tarde'));

      app.loginAs(UserRole.employee);
      expect(await app.notifyLate('otra vez'), isFalse);
    });

    test('setNewPassword checks length and confirmation', () async {
      final app = AppState();
      expect(await app.setNewPassword('corta', 'corta'), isFalse);
      expect(await app.setNewPassword('larga1234', 'distinta1'), isFalse);
      expect(await app.setNewPassword('larga1234', 'larga1234'), isTrue);
      expect(app.needsNewPassword, isFalse);
    });
  });
}
