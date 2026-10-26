import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../i18n/app_lang.dart';
import '../i18n/app_strings.dart';
import '../i18n/formatters.dart';
import '../services/backend.dart';
import '../services/device_services.dart';
import 'app_scaffold_messenger.dart';
import 'models.dart';

/// Una fila de "Quién trabaja hoy".
typedef LiveRow = ({String employeeId, String sub, String hours, bool onShift});

/// Estado central de la app.
///
/// Con un [Backend] (Supabase) carga y escribe datos reales y escucha los
/// cambios en tiempo real. Sin backend funciona en modo demo con datos en
/// memoria. Las pantallas leen los mismos getters en los dos modos.
///
/// Las mutaciones son optimistas: se actualiza el estado local al instante
/// y luego se confirma con el servidor; si el servidor rechaza, se revierte
/// y se muestra el error. El servidor siempre tiene la última palabra (RLS
/// y funciones en `supabase/migrations`), así que las validaciones de aquí
/// son para dar buena respuesta en la UI, no para seguridad.
class AppState extends ChangeNotifier {
  AppState({Backend? backend, this._camera, DateTime Function()? now})
    : _backend = backend {
    _now = now ?? (backend == null ? _demoClock() : DateTime.now);
    if (backend == null) {
      _seedDemo();
    } else {
      _restoring = true;
    }
  }

  final Backend? _backend;
  final PhotoCaptureService? _camera;
  late final DateTime Function() _now;

  bool get isDemo => _backend == null;
  DateTime get now => _now();

  StreamSubscription<String>? _changesSub;
  Timer? _changesDebounce;
  final Set<String> _dirtyTables = {};

  @override
  void dispose() {
    _changesSub?.cancel();
    _changesDebounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Idioma
  // ---------------------------------------------------------------------

  AppLang _lang = AppLang.es;
  AppLang get lang => _lang;
  bool get isEnglish => _lang == AppLang.en;
  AppStrings get strings => AppStrings.of(_lang);
  List<String> get dayLabels => strings.days(_lang);

  void setLang(AppLang lang) {
    if (_lang == lang) return;
    _lang = lang;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Sesión
  // ---------------------------------------------------------------------

  SessionUser? _session;
  UserRole _demoRole = UserRole.manager;

  bool _restoring = false;

  /// true mientras se busca una sesión guardada al abrir la app.
  bool get restoring => _restoring;

  bool _busy = false;

  /// true mientras hay un login / aceptación de invitación en curso.
  bool get busy => _busy;

  bool get isSignedIn => isDemo || _session != null;

  /// El usuario llegó por el enlace de invitación y aún no puso contraseña.
  bool get needsInviteAcceptance =>
      _session?.profile.status == EmployeeStatus.invited;

  UserRole get role => _session?.profile.role ?? _demoRole;

  Employee get me {
    final session = _session;
    if (session != null) return session.profile;
    if (_demoRole == UserRole.manager) return _demoManager;
    return employees.firstWhere((e) => e.id == _demoEmployeeId);
  }

  String get email => me.email;

  String get orgName => _session?.orgName ?? strings['restaurantName'];

  String get greeting => strings.fmt('hello', {'name': me.firstName});

  /// Busca una sesión guardada. Devuelve true si hay usuario.
  Future<bool> restoreSession() async {
    final backend = _backend;
    if (backend == null) return true;
    _restoring = true;
    notifyListeners();
    try {
      final user = await backend.auth.restoreSession();
      if (user != null) await _startSession(user);
      return user != null;
    } on AppException catch (e) {
      _flashError(e);
      return false;
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  /// Modo demo: entra con el rol elegido, sin contraseña.
  void loginAs(UserRole role) {
    assert(isDemo, 'loginAs solo existe en modo demo');
    _demoRole = role;
    notifyListeners();
  }

  /// Login real. El rol lo decide el perfil en la base de datos.
  Future<bool> signIn(String email, String password) async {
    final backend = _backend;
    if (backend == null) return false;
    if (!_emailRe.hasMatch(email.trim())) {
      flash(strings.error('invalid_email'));
      return false;
    }
    if (password.isEmpty) {
      flash(strings.error('invalid_credentials'));
      return false;
    }
    _busy = true;
    notifyListeners();
    try {
      final user = await backend.auth.signIn(email: email, password: password);
      await _startSession(user);
      return true;
    } on AppException catch (e) {
      _flashError(e);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Acepta la invitación: define contraseña y activa el perfil.
  Future<bool> acceptInvite({
    required String password,
    required bool locationConsent,
  }) async {
    if (!locationConsent) {
      flash(strings['gpsConsentRequired']);
      return false;
    }
    if (password.length < 8) {
      flash(strings['passwordTooShort']);
      return false;
    }
    final backend = _backend;
    if (backend == null) {
      _demoRole = UserRole.employee;
      notifyListeners();
      return true;
    }
    _busy = true;
    notifyListeners();
    try {
      final user = await backend.auth.acceptInvite(password: password);
      await _startSession(user);
      return true;
    } on AppException catch (e) {
      _flashError(e);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Solo en modo demo. Con backend el rol viene de la base de datos y
  /// cambiarlo desde la app sería una escalada de privilegios.
  void switchRole() {
    if (!isDemo) return;
    _demoRole = _demoRole == UserRole.manager
        ? UserRole.employee
        : UserRole.manager;
    _clearDemoClock();
    notifyListeners();
  }

  Future<void> logout() async {
    await _changesSub?.cancel();
    _changesSub = null;
    _changesDebounce?.cancel();
    _dirtyTables.clear();
    final backend = _backend;
    if (backend != null) {
      try {
        await backend.auth.signOut();
      } on AppException {
        // Aunque el servidor falle, la sesión local se descarta igual.
      }
    }
    _session = null;
    _clearData();
    if (isDemo) _seedDemo();
    notifyListeners();
  }

  Future<void> _startSession(SessionUser user) async {
    _session = user;
    notifyListeners();
    if (user.profile.status == EmployeeStatus.invited) return;
    await _loadAll();
    await _changesSub?.cancel();
    _changesSub = _backend!.changes().listen(_onTableChanged);
  }

  void _clearData() {
    employees = [];
    sites = [];
    shifts = [];
    week.clear();
    requests = [];
    swaps = [];
    currentEntry = null;
    todayEntries = [];
    workPhotos = [];
    threads = [];
    messagesByThread.clear();
    notifs = [];
    availability = List.filled(7, true);
    notifPrefs = [true, true, false];
    locationStatus = isDemo ? LocationStatus.inside : LocationStatus.unknown;
  }

  // ---------------------------------------------------------------------
  // Carga desde el backend y tiempo real
  // ---------------------------------------------------------------------

  Future<void> _loadAll() async {
    await Future.wait([
      _safe(_loadTeam),
      _safe(_loadWeek),
      _safe(_loadRequests),
      _safe(_loadSwaps),
      _safe(_loadClock),
      _safe(_loadChat),
      _safe(_loadNotifs),
      _safe(_loadMine),
    ]);
    // Las horas se asignan a los empleados ya cargados.
    await _safe(_loadReports);
  }

  void _onTableChanged(String table) {
    _dirtyTables.add(table);
    _changesDebounce?.cancel();
    _changesDebounce = Timer(const Duration(milliseconds: 300), () async {
      final tables = {..._dirtyTables};
      _dirtyTables.clear();
      await Future.wait([
        if (tables.contains('profiles')) _safe(_loadTeam),
        if (tables.contains('shifts') || tables.contains('swap_offers'))
          _safe(_loadWeek),
        if (tables.contains('shift_requests')) _safe(_loadRequests),
        if (tables.contains('swap_offers')) _safe(_loadSwaps),
        if (tables.contains('time_entries')) _safe(_loadClock),
        if (tables.contains('chat_messages')) _safe(_loadChat),
        if (tables.contains('notifications')) _safe(_loadNotifs),
      ]);
      if (tables.contains('time_entries') || tables.contains('profiles')) {
        await _safe(_loadReports);
      }
    });
  }

  Future<void> _safe(Future<void> Function() load) async {
    try {
      await load();
    } on AppException catch (e) {
      _flashError(e);
    }
    notifyListeners();
  }

  Future<void> _loadTeam() async {
    final b = _backend!;
    final results = await Future.wait([b.team.fetchTeam(), b.team.fetchSites()]);
    final previousHours = {for (final e in employees) e.id: e.hoursWorked};
    employees = results[0] as List<Employee>;
    for (final e in employees) {
      e.hoursWorked = previousHours[e.id] ?? 0;
    }
    sites = results[1] as List<Site>;
  }

  Future<void> _loadWeek() async {
    // Dos semanas: los cambios de turno pueden ser de la próxima.
    shifts = await _backend!.shifts.fetchShifts(
      weekStart,
      _addDays(weekStart, 14),
    );
    _rebuildWeek();
  }

  Future<void> _loadRequests() async {
    requests = await _backend!.shifts.fetchPendingRequests();
  }

  Future<void> _loadSwaps() async {
    swaps = await _backend!.shifts.fetchActiveSwaps();
  }

  Future<void> _loadClock() async {
    final clock = _backend!.clock;
    final today = this.today;
    final results = await Future.wait([
      clock.currentEntry(),
      clock.fetchEntries(today, _addDays(today, 1)),
    ]);
    final entry = results[0] as TimeEntry?;
    todayEntries = results[1] as List<TimeEntry>;
    if (entry?.id != currentEntry?.id) workPhotos = [];
    currentEntry = entry;
    if (entry != null) workPhotos = await clock.fetchWorkPhotos(entry.id);
  }

  Future<void> _loadChat() async {
    final chat = _backend!.chat;
    threads = await chat.fetchThreads();
    final open = _openThreadId;
    if (open != null) {
      messagesByThread[open] = await chat.fetchMessages(open);
      await chat.markThreadRead(open);
      threadById(open)?.unread = 0;
    }
  }

  Future<void> _loadNotifs() async {
    notifs = await _backend!.notifications.fetchNotifications();
  }

  Future<void> _loadMine() async {
    final b = _backend!;
    final results = await Future.wait([
      b.shifts.fetchAvailability(me.id),
      b.notifications.fetchPrefs(),
    ]);
    availability = results[0];
    notifPrefs = results[1];
  }

  Future<void> _loadReports() async {
    final hours = await _backend!.reports.fetchHours(
      periodStart,
      periodEndExclusive,
    );
    for (final e in employees) {
      e.hoursWorked = hours[e.id] ?? 0;
    }
  }

  // ---------------------------------------------------------------------
  // Fechas
  // ---------------------------------------------------------------------

  DateTime get today => DateUtils.dateOnly(_now());
  int get todayIndex => today.weekday - 1;

  DateTime get weekStart => _addDays(today, -todayIndex);

  String get todayLabel => Fmt.longDate(today, _lang);

  String get weekRangeLabel =>
      Fmt.dayRange(weekStart, _addDays(weekStart, 6), _lang);

  /// "Mié 9"
  String shortDayLabel(DateTime d) => '${dayLabels[d.weekday - 1]} ${d.day}';

  String _dayMonth(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return isEnglish ? '${two(d.month)}/${two(d.day)}' : '${two(d.day)}/${two(d.month)}';
  }

  /// Sumar días por calendario (no por 24 h) para no romperse con el
  /// cambio de horario.
  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days, d.hour, d.minute);

  bool _inCurrentWeek(DateTime d) =>
      !d.isBefore(weekStart) && d.isBefore(_addDays(weekStart, 7));

  // ---------------------------------------------------------------------
  // Equipo y sitios
  // ---------------------------------------------------------------------

  List<Employee> employees = [];
  List<Site> sites = [];

  Employee employeeById(String id) {
    for (final e in employees) {
      if (e.id == id) return e;
    }
    if (id == me.id) return me;
    // Alguien que ya no está en el equipo (p. ej. borrado): no reventar.
    return Employee(
      id: id,
      name: '—',
      email: '',
      role: UserRole.employee,
      roleEs: '',
      roleEn: '',
      hourlyRate: 0,
      status: EmployeeStatus.inactive,
      avatarIndex: 0,
    );
  }

  Site? siteById(String? id) {
    for (final s in sites) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<Employee> get activeEmployees =>
      employees.where((e) => e.status == EmployeeStatus.active).toList();

  /// Empleados a los que se les puede asignar un turno.
  List<Employee> get assignableEmployees => activeEmployees
      .where((e) => e.role == UserRole.employee)
      .toList();

  int get teamSize => assignableEmployees.length;

  List<Employee> searchEmployees(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return employees;
    return employees.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  String rateLabel(Employee e) => Fmt.money(e.hourlyRate, _lang);

  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  Future<bool> inviteEmployee({
    required String name,
    required String email,
    required String position,
    required double hourlyRate,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanName.isEmpty || cleanName.length > 120) {
      flash(strings.error('invalid_name'));
      return false;
    }
    if (!_emailRe.hasMatch(cleanEmail) || cleanEmail.length > 254) {
      flash(strings.error('invalid_email'));
      return false;
    }
    if (position.trim().length > 60) {
      flash(strings.error('invalid_position'));
      return false;
    }
    if (hourlyRate.isNaN || hourlyRate < 0) {
      flash(strings.error('invalid_rate'));
      return false;
    }
    if (employees.any((e) => e.email.toLowerCase() == cleanEmail)) {
      flash(strings.error('already_registered'));
      return false;
    }

    final backend = _backend;
    if (backend == null) {
      employees.add(
        Employee(
          id: _localId(),
          name: cleanName,
          email: cleanEmail,
          role: UserRole.employee,
          roleEs: position.trim(),
          roleEn: position.trim(),
          hourlyRate: hourlyRate,
          status: EmployeeStatus.invited,
          avatarIndex: employees.length,
        ),
      );
      flash(strings['inviteOk']);
      notifyListeners();
      return true;
    }
    try {
      await backend.team.inviteEmployee(
        name: cleanName,
        email: cleanEmail,
        positionEs: position.trim(),
        positionEn: position.trim(),
        hourlyRate: hourlyRate,
      );
      flash(strings['inviteOk']);
      await _safe(_loadTeam);
      return true;
    } on AppException catch (e) {
      _flashError(e);
      return false;
    }
  }

  void deactivateEmployee(String employeeId) =>
      setEmployeeStatus(employeeId, EmployeeStatus.inactive);

  Future<void> setEmployeeStatus(
    String employeeId,
    EmployeeStatus status,
  ) async {
    if (employeeId == me.id) {
      flash(strings.error('cannot_change_own_role'));
      return;
    }
    final e = employeeById(employeeId);
    final previous = e.status;
    if (previous == status) return;
    e.status = status;
    flash(strings['saveOk']);
    notifyListeners();
    final backend = _backend;
    if (backend == null) return;
    try {
      await backend.team.setEmployeeStatus(employeeId, status);
    } on AppException catch (err) {
      e.status = previous;
      _flashError(err);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Semana (gerente) y turnos
  // ---------------------------------------------------------------------

  List<Shift> shifts = [];

  /// Los siete días de la semana actual. Los objetos se reutilizan al
  /// recalcular para que las vistas que los tienen no queden desfasadas.
  final List<WeekDay> week = [];

  void _rebuildWeek() {
    final start = weekStart;
    if (week.isEmpty || week.first.date != start) {
      week
        ..clear()
        ..addAll([
          for (var i = 0; i < 7; i++)
            WeekDay(date: _addDays(start, i), slots: const [], openCount: 0),
        ]);
    }
    for (final day in week) {
      final dayShifts =
          shifts.where((s) => DateUtils.isSameDay(s.startsAt, day.date)).toList()
            ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      day.slots = [
        for (final s in dayShifts)
          if (s.employeeId != null)
            ShiftSlot(
              shiftId: s.id,
              employeeId: s.employeeId!,
              timeLabel: Fmt.hourRange(s.startsAt, s.endsAt),
            ),
      ];
      day.openCount = dayShifts.where((s) => s.employeeId == null).length;
    }
  }

  int get uncoveredCount => week.fold(0, (a, d) => a + d.openCount);

  Shift? shiftById(String id) {
    for (final s in shifts) {
      if (s.id == id) return s;
    }
    return null;
  }

  bool _overlaps(String employeeId, DateTime start, DateTime end) =>
      shifts.any(
        (s) =>
            s.employeeId == employeeId &&
            s.startsAt.isBefore(end) &&
            s.endsAt.isAfter(start),
      );

  /// '09–17' / '17–01' sobre el día [weekdayIndex] de esta semana. Si la
  /// hora de fin es menor que la de inicio, el turno termina al día siguiente.
  (DateTime, DateTime) _parseTimeLabel(int weekdayIndex, String timeLabel) {
    final parts = timeLabel.split(RegExp('[–-]'));
    final startHour = int.parse(parts[0].trim().split(':').first);
    final endHour = int.parse(parts[1].trim().split(':').first);
    final day = _addDays(weekStart, weekdayIndex);
    final start = DateTime(day.year, day.month, day.day, startHour);
    var end = DateTime(day.year, day.month, day.day, endHour);
    if (!end.isAfter(start)) end = _addDays(end, 1);
    return (start, end);
  }

  /// Asigna un turno. Si ese día hay un turno sin cubrir con el mismo
  /// horario, se cubre ese; si no, se crea uno nuevo.
  Future<void> createShift({
    required String employeeId,
    required int weekdayIndex,
    required String timeLabel,
    String? siteId,
  }) async {
    final emp = employeeById(employeeId);
    if (emp.status != EmployeeStatus.active) {
      flash(strings.error('employee_not_active'));
      return;
    }
    final (start, end) = _parseTimeLabel(weekdayIndex, timeLabel);
    if (_overlaps(employeeId, start, end)) {
      flash(strings.error('overlapping_shift'));
      return;
    }

    Shift? open;
    for (final s in shifts) {
      if (s.employeeId == null &&
          s.startsAt == start &&
          s.endsAt == end &&
          (siteId == null || s.siteId == siteId)) {
        open = s;
        break;
      }
    }
    final targetSite = open?.siteId ?? siteId ?? (sites.isEmpty ? null : sites.first.id);
    if (targetSite == null) {
      flash(strings['noSites']);
      return;
    }

    final Shift local;
    if (open != null) {
      open.employeeId = employeeId;
      local = open;
    } else {
      local = Shift(
        id: _localId(),
        siteId: targetSite,
        employeeId: employeeId,
        startsAt: start,
        endsAt: end,
      );
      shifts.add(local);
    }
    _rebuildWeek();
    flash(
      '${strings['shiftOk']} · ${emp.firstName} '
      '${dayLabels[weekdayIndex]} $timeLabel',
    );
    notifyListeners();

    final backend = _backend;
    if (backend == null) return;
    try {
      if (open != null) {
        await backend.shifts.assignShift(open.id, employeeId);
      } else {
        await backend.shifts.createShift(
          siteId: targetSite,
          startsAt: start,
          endsAt: end,
          employeeId: employeeId,
        );
      }
    } on AppException catch (e) {
      _flashError(e);
    }
    await _safe(_loadWeek);
  }

  Future<void> duplicateWeek() async {
    final backend = _backend;
    if (backend == null) {
      flash(strings['dupOk']);
      return;
    }
    try {
      final n = await backend.shifts.duplicatePreviousWeek(weekStart);
      flash(strings.fmt('dupOkN', {'n': n}));
      await _safe(_loadWeek);
    } on AppException catch (e) {
      _flashError(e);
    }
  }

  int shiftsThisWeekOf(String employeeId) => shifts
      .where((s) => s.employeeId == employeeId && _inCurrentWeek(s.startsAt))
      .length;

  // ---------------------------------------------------------------------
  // Solicitudes (bandeja del gerente)
  // ---------------------------------------------------------------------

  List<ShiftRequest> requests = [];

  List<ShiftRequest> get pendingRequests =>
      requests.where((r) => !r.resolved).toList();

  String requestTitle(ShiftRequest r) {
    final who = employeeById(r.employeeId).firstName;
    return switch (r.kind) {
      RequestKind.off => isEnglish
          ? '$who asks for ${_dayMonth(r.date)} off'
          : '$who pide libre el ${_dayMonth(r.date)}',
      RequestKind.swap => isEnglish
          ? '$who wants to swap a shift'
          : '$who quiere cambiar un turno',
      RequestKind.late => isEnglish
          ? '$who clocked in late'
          : '$who marcó entrada tarde',
    };
  }

  String requestSubtitle(ShiftRequest r) {
    final shift = r.shiftId == null ? null : shiftById(r.shiftId!);
    switch (r.kind) {
      case RequestKind.off:
        final reason = r.reason;
        return reason == null || reason.isEmpty
            ? _dayMonth(r.date)
            : strings.fmt('reasonLabel', {'reason': reason});
      case RequestKind.swap:
        if (shift == null) return _dayMonth(r.date);
        final swap = _swapForRequest(r.id);
        final claimer = swap?.claimedBy;
        final base =
            '${shortDayLabel(shift.startsAt)} · ${Fmt.timeRange(shift.startsAt, shift.endsAt)}';
        return claimer == null
            ? base
            : '$base → ${employeeById(claimer).firstName}';
      case RequestKind.late:
        TimeEntry? entry;
        for (final e in todayEntries) {
          if (e.employeeId == r.employeeId && e.shiftId == r.shiftId) entry = e;
        }
        final inAt = entry == null ? '' : '${Fmt.time(entry.clockInAt)} · ';
        final when = DateUtils.isSameDay(r.date, today)
            ? (isEnglish ? 'today' : 'hoy')
            : _dayMonth(r.date);
        return '${isEnglish ? "In at " : "Entrada "}$inAt$when';
    }
  }

  SwapOffer? _swapForRequest(String requestId) {
    for (final s in swaps) {
      if (s.requestId == requestId) return s;
    }
    return null;
  }

  void approveRequest(String requestId) => _resolveRequest(requestId, true);

  void rejectRequest(String requestId) => _resolveRequest(requestId, false);

  Future<void> _resolveRequest(String requestId, bool approve) async {
    ShiftRequest? r;
    for (final x in requests) {
      if (x.id == requestId) r = x;
    }
    if (r == null || r.resolved) return;
    r.resolved = true;
    flash(strings[approve ? 'approvedMsg' : 'declinedMsg']);

    final backend = _backend;
    if (backend == null) {
      _applyResolutionLocally(r, approve);
      notifyListeners();
      return;
    }
    notifyListeners();
    try {
      await backend.shifts.resolveRequest(requestId, approve: approve);
    } on AppException catch (e) {
      r.resolved = false;
      _flashError(e);
    }
    await Future.wait([
      _safe(_loadRequests),
      _safe(_loadSwaps),
      _safe(_loadWeek),
    ]);
  }

  /// Lo mismo que hace `resolve_request` en el servidor, para el modo demo.
  void _applyResolutionLocally(ShiftRequest r, bool approve) {
    if (r.kind == RequestKind.swap) {
      final swap = _swapForRequest(r.id);
      if (swap != null) {
        if (approve) shiftById(swap.shiftId)?.employeeId = swap.claimedBy;
        swaps.remove(swap);
      }
    } else if (r.kind == RequestKind.off && approve) {
      for (final s in shifts) {
        if (s.employeeId == r.employeeId &&
            DateUtils.isSameDay(s.startsAt, r.date)) {
          s.employeeId = null;
        }
      }
    }
    _rebuildWeek();
  }

  // ---------------------------------------------------------------------
  // Empleado: sus turnos y disponibilidad
  // ---------------------------------------------------------------------

  List<Shift> get myShiftsThisWeek =>
      shifts
          .where((s) => s.employeeId == me.id && _inCurrentWeek(s.startsAt))
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  Shift? myShiftOn(int weekdayIndex) {
    for (final s in myShiftsThisWeek) {
      if (s.startsAt.weekday - 1 == weekdayIndex) return s;
    }
    return null;
  }

  Set<int> get myShiftWeekdays => {
    for (final s in myShiftsThisWeek) s.startsAt.weekday - 1,
  };

  /// El turno en curso o el siguiente (en cualquier día).
  Shift? get nextShift {
    final now = _now();
    final mine =
        shifts
            .where((s) => s.employeeId == me.id && s.endsAt.isAfter(now))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return mine.isEmpty ? null : mine.first;
  }

  String nextShiftCountdown(Shift s) {
    final now = _now();
    if (!s.startsAt.isAfter(now)) return strings['inProgress'];
    final diff = s.startsAt.difference(now);
    if (diff.inMinutes < 60) {
      return strings.fmt('startsInMin', {'n': math.max(1, diff.inMinutes)});
    }
    if (DateUtils.isSameDay(s.startsAt, now)) {
      return strings.fmt('startsInHours', {
        'h': diff.inHours,
        'm': diff.inMinutes % 60,
      });
    }
    return strings.fmt('startsOnDay', {
      'day': Fmt.longDate(s.startsAt, _lang),
    });
  }

  String get myWeekHoursLabel {
    final total = myShiftsThisWeek.fold(Duration.zero, (a, s) => a + s.duration);
    return '${total.inMinutes ~/ 60}h';
  }

  String get myWeekShiftsLabel =>
      strings.fmt('shiftsAssignedN', {'n': myShiftsThisWeek.length});

  List<bool> availability = List.filled(7, true);

  void toggleAvailability(int weekdayIndex) {
    availability[weekdayIndex] = !availability[weekdayIndex];
    notifyListeners();
  }

  Future<void> saveAvailability() async {
    final backend = _backend;
    if (backend == null) {
      flash(strings['savedOk']);
      return;
    }
    try {
      await backend.shifts.saveAvailability(List.of(availability));
      flash(strings['savedOk']);
    } on AppException catch (e) {
      _flashError(e);
    }
  }

  final Map<String, List<bool>> _demoAvailability = {};

  /// Disponibilidad de otra persona (vista del gerente).
  Future<List<bool>> availabilityOf(String employeeId) async {
    if (employeeId == me.id) return availability;
    final backend = _backend;
    if (backend == null) {
      return _demoAvailability[employeeId] ?? List.filled(7, true);
    }
    try {
      return await backend.shifts.fetchAvailability(employeeId);
    } on AppException {
      return List.filled(7, true);
    }
  }

  // ---------------------------------------------------------------------
  // Empleado: cambios de turno
  // ---------------------------------------------------------------------

  List<SwapOffer> swaps = [];

  bool hasOfferedShift(int weekdayIndex) {
    final shift = myShiftOn(weekdayIndex);
    if (shift == null) return false;
    return swaps.any((s) => s.shiftId == shift.id && s.employeeId == me.id);
  }

  /// Se puede ofrecer un turno propio que todavía no empezó y que no está
  /// ya ofrecido.
  bool canOfferShift(int weekdayIndex) {
    final shift = myShiftOn(weekdayIndex);
    return shift != null &&
        shift.startsAt.isAfter(_now()) &&
        !hasOfferedShift(weekdayIndex);
  }

  Future<void> offerShift(int weekdayIndex) async {
    if (!canOfferShift(weekdayIndex)) return;
    final shift = myShiftOn(weekdayIndex)!;
    final requestId = _localId();
    swaps.insert(
      0,
      SwapOffer(
        id: _localId(),
        employeeId: me.id,
        shiftId: shift.id,
        status: SwapStatus.offered,
        requestId: requestId,
      ),
    );
    requests.insert(
      0,
      ShiftRequest(
        id: requestId,
        kind: RequestKind.swap,
        employeeId: me.id,
        shiftId: shift.id,
        date: DateUtils.dateOnly(shift.startsAt),
      ),
    );
    flash(strings['shiftOfferedMsg']);
    notifyListeners();

    final backend = _backend;
    if (backend == null) return;
    try {
      await backend.shifts.offerShift(shift.id);
    } on AppException catch (e) {
      _flashError(e);
    }
    await Future.wait([_safe(_loadSwaps), _safe(_loadRequests)]);
  }

  List<SwapOffer> get claimableSwaps => swaps
      .where((s) => s.status == SwapStatus.open && s.employeeId != me.id)
      .toList();

  String swapTitle(SwapOffer s) {
    final shift = shiftById(s.shiftId);
    return strings.fmt('released', {
      'name': employeeById(s.employeeId).firstName,
      'day': shift == null ? '—' : shortDayLabel(shift.startsAt),
    });
  }

  String swapTimeLabel(SwapOffer s) {
    final shift = shiftById(s.shiftId);
    return shift == null ? '' : Fmt.timeRange(shift.startsAt, shift.endsAt);
  }

  Future<void> claimSwap(String swapId) async {
    SwapOffer? swap;
    for (final s in swaps) {
      if (s.id == swapId) swap = s;
    }
    if (swap == null || swap.status != SwapStatus.open) {
      flash(strings.error('swap_not_available'));
      return;
    }
    if (swap.employeeId == me.id) {
      flash(strings.error('own_swap'));
      return;
    }
    final shift = shiftById(swap.shiftId);
    if (shift != null && _overlaps(me.id, shift.startsAt, shift.endsAt)) {
      flash(strings.error('overlapping_shift'));
      return;
    }
    swap.status = SwapStatus.pending;
    swap.claimedBy = me.id;
    flash(strings['swapRequestedMsg']);
    notifyListeners();

    final backend = _backend;
    if (backend == null) return;
    try {
      await backend.shifts.claimSwap(swapId);
    } on AppException catch (e) {
      _flashError(e);
    }
    await _safe(_loadSwaps);
  }

  // ---------------------------------------------------------------------
  // Fichaje con validación de ubicación
  // ---------------------------------------------------------------------

  TimeEntry? currentEntry;

  /// Fichajes de hoy de todo el equipo (gerente) o solo los propios.
  List<TimeEntry> todayEntries = [];

  bool get clockedIn => currentEntry != null;
  DateTime? get clockStart => currentEntry?.clockInAt;

  bool _clockBusy = false;
  bool get clockBusy => _clockBusy;

  Duration get elapsed => clockedIn
      ? _now().difference(clockStart!)
      : Duration.zero;

  static String formatElapsed(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  /// Precisión mínima (m) — la misma que exige `clock_in` en el servidor.
  static const double maxGpsAccuracyMeters = 100;

  late LocationStatus locationStatus = isDemo
      ? LocationStatus.inside
      : LocationStatus.unknown;
  double? distanceToSiteMeters;
  double? lastAccuracyMeters;

  bool get insideAllowedRadius =>
      isDemo || locationStatus == LocationStatus.inside;

  /// Mi turno de hoy que está en curso o por empezar.
  Shift? get todayShift {
    final now = _now();
    for (final s in myShiftsThisWeek) {
      if (DateUtils.isSameDay(s.startsAt, now) && s.endsAt.isAfter(now)) {
        return s;
      }
    }
    return null;
  }

  /// El sitio contra el que se valida el fichaje.
  Site? get clockSite {
    final entry = currentEntry;
    if (entry != null) return siteById(entry.siteId);
    return siteById(todayShift?.siteId) ?? (isDemo && sites.isNotEmpty ? sites.first : null);
  }

  String get clockCardSubtitle {
    if (clockedIn) return formatElapsed(elapsed);
    final s = todayShift;
    if (s == null) return strings['noShiftToday'];
    return strings.fmt('shiftRange', {
      'range': Fmt.timeRange(s.startsAt, s.endsAt),
    });
  }

  String get clockSinceLabel {
    final start = clockStart;
    if (start == null) return strings['beforeIn'];
    return strings.fmt('inAtSite', {
      'time': Fmt.time(start),
      'site': clockSite?.name ?? orgName,
    });
  }

  String get locationLabel {
    final site = clockSite?.name ?? '';
    return switch (locationStatus) {
      LocationStatus.inside => strings.fmt('insideSite', {'site': site}),
      LocationStatus.outside => strings.fmt('outsideSite', {
        'm': distanceToSiteMeters?.round() ?? '?',
        'site': site,
      }),
      LocationStatus.checking || LocationStatus.unknown =>
        strings['checkingLocation'],
      LocationStatus.lowAccuracy => strings.fmt('lowAccuracy', {
        'm': lastAccuracyMeters?.round() ?? '?',
      }),
      LocationStatus.denied => strings['locationDenied'],
      LocationStatus.servicesOff => strings['locationOff'],
      LocationStatus.mocked => strings['locationMocked'],
      LocationStatus.noShift => strings['noShiftToday'],
    };
  }

  /// Lee el GPS y compara con el sitio del turno (solo informativo: el
  /// servidor vuelve a validar al fichar).
  Future<void> checkLocation() async {
    final backend = _backend;
    if (backend == null) return;
    final site = clockSite;
    if (site == null) {
      locationStatus = LocationStatus.noShift;
      notifyListeners();
      return;
    }
    locationStatus = LocationStatus.checking;
    notifyListeners();
    try {
      _applyFix(await backend.location.currentFix(), site);
    } on AppException catch (e) {
      locationStatus = switch (e.code) {
        'location_off' => LocationStatus.servicesOff,
        'location_denied' => LocationStatus.denied,
        _ => LocationStatus.unknown,
      };
    }
    notifyListeners();
  }

  void _applyFix(LocationFix fix, Site site) {
    lastAccuracyMeters = fix.accuracyMeters;
    distanceToSiteMeters = distanceMeters(
      fix.latitude,
      fix.longitude,
      site.latitude,
      site.longitude,
    );
    locationStatus = fix.isMocked
        ? LocationStatus.mocked
        : fix.accuracyMeters > maxGpsAccuracyMeters
        ? LocationStatus.lowAccuracy
        : distanceToSiteMeters! <= site.radiusMeters
        ? LocationStatus.inside
        : LocationStatus.outside;
  }

  /// Haversine — misma fórmula que `distance_m` en el servidor.
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * 6371000 * math.asin(math.sqrt(a));
  }

  Future<void> clockToggle() async {
    final backend = _backend;
    if (backend == null) {
      _demoClockToggle();
      return;
    }
    if (_clockBusy) return;
    _clockBusy = true;
    notifyListeners();
    try {
      final fix = await backend.location.currentFix();
      final site = clockSite;
      if (site != null) _applyFix(fix, site);

      if (clockedIn) {
        await backend.clock.clockOut(fix);
        currentEntry = null;
        workPhotos = [];
        flash(strings['clockedOutMsg']);
      } else {
        // Chequeo rápido para no hacer viajar una petición que el servidor
        // va a rechazar; el servidor valida lo mismo de todos modos.
        if (site == null) throw const AppException('no_active_shift');
        switch (locationStatus) {
          case LocationStatus.mocked:
            throw const AppException('mock_location');
          case LocationStatus.lowAccuracy:
            throw const AppException('low_accuracy');
          case LocationStatus.outside:
            throw AppException(
              'outside_site',
              detail: '${distanceToSiteMeters?.round()}',
            );
          default:
            break;
        }
        currentEntry = await backend.clock.clockIn(fix);
        flash(strings['clockedInMsg']);
      }
    } on AppException catch (e) {
      _flashError(e);
    } finally {
      _clockBusy = false;
      notifyListeners();
    }
    await _safe(_loadClock);
  }

  void _demoClockToggle() {
    if (!insideAllowedRadius) {
      flash(strings['moveCloser']);
      return;
    }
    if (clockedIn) {
      final entry = currentEntry!..clockOutAt = _now();
      todayEntries = [
        for (final e in todayEntries) e.id == entry.id ? entry : e,
      ];
      currentEntry = null;
      workPhotos = [];
      flash(strings['clockedOutMsg']);
    } else {
      final shift = todayShift;
      final entry = TimeEntry(
        id: _localId(),
        employeeId: me.id,
        siteId: shift?.siteId ?? (sites.isEmpty ? '' : sites.first.id),
        shiftId: shift?.id,
        clockInAt: _now(),
      );
      currentEntry = entry;
      todayEntries = [...todayEntries, entry];
      flash(strings['clockedInMsg']);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Evidencia fotográfica
  // ---------------------------------------------------------------------

  List<WorkPhoto> workPhotos = [];
  bool uploadingPhoto = false;

  static const int maxPhotoBytes = 5 * 1024 * 1024;

  Future<void> addWorkPhoto() async {
    final entry = currentEntry;
    if (entry == null) {
      flash(strings.error('not_clocked_in'));
      return;
    }
    final camera = _camera;
    if (camera == null) {
      flash(strings.error('camera_unavailable'));
      return;
    }
    final Uint8List? bytes;
    try {
      bytes = await camera.takePhoto();
    } catch (_) {
      flash(strings.error('camera_unavailable'));
      return;
    }
    if (bytes == null) return; // canceló
    if (bytes.length > maxPhotoBytes) {
      flash(strings.error('upload_failed'));
      return;
    }

    final backend = _backend;
    if (backend == null) {
      workPhotos = [
        ...workPhotos,
        WorkPhoto(
          id: _localId(),
          timeEntryId: entry.id,
          takenAt: _now(),
          bytes: bytes,
        ),
      ];
      flash(strings['evidenceOk']);
      notifyListeners();
      return;
    }

    uploadingPhoto = true;
    notifyListeners();
    try {
      LocationFix? fix;
      try {
        fix = await backend.location.currentFix();
      } on AppException {
        // La foto vale aunque no haya GPS en ese momento.
      }
      final photo = await backend.clock.uploadWorkPhoto(
        timeEntryId: entry.id,
        jpegBytes: bytes,
        fix: fix,
      );
      workPhotos = [...workPhotos, photo];
      flash(strings['evidenceOk']);
    } on AppException catch (e) {
      _flashError(e);
    } finally {
      uploadingPhoto = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // "Quién trabaja hoy" (gerente)
  // ---------------------------------------------------------------------

  List<LiveRow> get liveBoard {
    final now = _now();
    final rows = <LiveRow>[];
    for (final e in assignableEmployees) {
      TimeEntry? entry;
      for (final t in todayEntries) {
        if (t.employeeId == e.id && (entry == null || t.isOpen)) entry = t;
      }
      Shift? shift;
      for (final s in shifts) {
        if (s.employeeId == e.id && DateUtils.isSameDay(s.startsAt, now)) {
          shift = s;
          break;
        }
      }
      if (entry != null && entry.isOpen) {
        rows.add((
          employeeId: e.id,
          sub: strings.fmt('inAt', {'time': Fmt.time(entry.clockInAt)}),
          hours: Fmt.duration(now.difference(entry.clockInAt)),
          onShift: true,
        ));
      } else if (entry != null) {
        rows.add((
          employeeId: e.id,
          sub: strings.fmt('outAt', {'time': Fmt.time(entry.clockOutAt!)}),
          hours: Fmt.duration(entry.clockOutAt!.difference(entry.clockInAt)),
          onShift: false,
        ));
      } else if (shift != null && shift.startsAt.isAfter(now)) {
        rows.add((
          employeeId: e.id,
          sub: strings.fmt('startsAt', {'time': Fmt.time(shift.startsAt)}),
          hours: '—',
          onShift: false,
        ));
      } else if (shift != null) {
        rows.add((
          employeeId: e.id,
          sub: strings['notClockedIn'],
          hours: '—',
          onShift: false,
        ));
      } else {
        rows.add((
          employeeId: e.id,
          sub: strings['free'],
          hours: '—',
          onShift: false,
        ));
      }
    }
    rows.sort((a, b) => (b.onShift ? 1 : 0) - (a.onShift ? 1 : 0));
    return rows;
  }

  int get workingNowCount => liveBoard.where((l) => l.onShift).length;

  /// PENDIENTE: no hay pantalla para editar un fichaje todavía. En el
  /// servidor haría falta una función `correct_time_entry` solo para
  /// gerentes, que deje registro de quién corrigió.
  void fixClockEntry(String employeeId) =>
      flash(isDemo ? strings['saveOk'] : strings['comingSoon']);

  // ---------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------

  List<ChatThread> threads = [];
  final Map<String, List<ChatMessage>> messagesByThread = {};
  String? _openThreadId;

  static const int maxMessageLength = 2000;

  ChatThread? threadById(String id) {
    for (final t in threads) {
      if (t.id == id) return t;
    }
    return null;
  }

  String threadTitle(ChatThread t) {
    if (t.isGeneral) return 'General';
    final other = t.otherEmployeeId;
    if (other != null) return employeeById(other).name;
    return t.name;
  }

  String threadInitials(ChatThread t) {
    if (t.isGeneral) return '#';
    final other = t.otherEmployeeId;
    return other == null ? '?' : employeeById(other).initials;
  }

  int threadAvatarIndex(ChatThread t) {
    final other = t.otherEmployeeId;
    return other == null ? 0 : employeeById(other).avatarIndex;
  }

  List<ChatMessage> threadMessages(String threadId) =>
      messagesByThread[threadId] ?? const [];

  String senderName(ChatMessage m) {
    final id = m.senderId;
    return id == null ? m.from : employeeById(id).firstName;
  }

  Future<void> openThread(String threadId) async {
    _openThreadId = threadId;
    threadById(threadId)?.unread = 0;
    notifyListeners();
    final backend = _backend;
    if (backend == null) return;
    await _safe(() async {
      messagesByThread[threadId] = await backend.chat.fetchMessages(threadId);
      await backend.chat.markThreadRead(threadId);
    });
  }

  void closeThread(String threadId) {
    if (_openThreadId == threadId) _openThreadId = null;
  }

  Future<void> sendMessage(String threadId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.length > maxMessageLength) {
      flash(strings.error('generic'));
      return;
    }
    final message = ChatMessage(
      from: 'me',
      senderId: isDemo ? null : me.id,
      text: trimmed,
      fromMe: true,
      sentAt: _now(),
    );
    final list = messagesByThread.putIfAbsent(threadId, () => []);
    list.add(message);
    threadById(threadId)?.lastMessage = trimmed;
    notifyListeners();

    final backend = _backend;
    if (backend == null) return;
    try {
      await backend.chat.sendMessage(threadId: threadId, text: trimmed);
    } on AppException catch (e) {
      list.remove(message);
      _flashError(e);
      notifyListeners();
    }
  }

  /// Devuelve el id del chat directo con [employeeId] (lo crea si no existe).
  Future<String?> openDirectThreadWith(String employeeId) async {
    for (final t in threads) {
      if (!t.isGeneral && t.otherEmployeeId == employeeId) return t.id;
    }
    final backend = _backend;
    if (backend == null) {
      final thread = ChatThread(
        id: _localId(),
        name: employeeById(employeeId).name,
        isGeneral: false,
        otherEmployeeId: employeeId,
      );
      threads.add(thread);
      notifyListeners();
      return thread.id;
    }
    try {
      final id = await backend.chat.openDirectThread(employeeId);
      await _safe(_loadChat);
      return id;
    } on AppException catch (e) {
      _flashError(e);
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // Notificaciones
  // ---------------------------------------------------------------------

  List<AppNotificationItem> notifs = [];

  bool get hasUnreadNotifs => notifs.any((n) => !n.read);

  String notifTimeLabel(AppNotificationItem n) {
    final diff = _now().difference(n.createdAt);
    if (diff.inMinutes < 1) return strings['justNow'];
    if (diff.inMinutes < 60) {
      return strings.fmt('minutesAgo', {'n': diff.inMinutes});
    }
    if (DateUtils.isSameDay(n.createdAt, _now())) {
      return strings.fmt('hoursAgo', {'n': diff.inHours});
    }
    if (DateUtils.isSameDay(n.createdAt, _addDays(today, -1))) {
      return strings['yesterday'];
    }
    return strings.fmt('daysAgo', {'n': math.max(2, diff.inDays)});
  }

  Future<void> markNotifRead(String id) async {
    AppNotificationItem? n;
    for (final x in notifs) {
      if (x.id == id) n = x;
    }
    if (n == null || n.read) return;
    n.read = true;
    notifyListeners();
    final backend = _backend;
    if (backend == null) return;
    try {
      await backend.notifications.markRead(id);
    } on AppException catch (e) {
      n.read = false;
      _flashError(e);
      notifyListeners();
    }
  }

  Future<void> markAllNotifsRead() async {
    final unread = notifs.where((n) => !n.read).toList();
    for (final n in unread) {
      n.read = true;
    }
    notifyListeners();
    final backend = _backend;
    if (backend == null || unread.isEmpty) return;
    try {
      await backend.notifications.markAllRead();
    } on AppException catch (e) {
      for (final n in unread) {
        n.read = false;
      }
      _flashError(e);
      notifyListeners();
    }
  }

  /// Recordatorio de turno / mensajes nuevos / olvidé marcar salida.
  List<bool> notifPrefs = [true, true, false];

  Future<void> toggleNotifPref(int index) async {
    notifPrefs[index] = !notifPrefs[index];
    notifyListeners();
    final backend = _backend;
    if (backend == null) return;
    try {
      await backend.notifications.savePrefs(List.of(notifPrefs));
    } on AppException catch (e) {
      notifPrefs[index] = !notifPrefs[index];
      _flashError(e);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Reportes (quincena actual)
  // ---------------------------------------------------------------------

  static const double overtimeThresholdHours = 65;

  DateTime get periodStart =>
      DateTime(today.year, today.month, today.day <= 15 ? 1 : 16);

  DateTime get periodEndExclusive => today.day <= 15
      ? DateTime(today.year, today.month, 16)
      : DateTime(today.year, today.month + 1, 1);

  String get periodLabel => Fmt.periodRange(
    periodStart,
    _addDays(periodEndExclusive, -1),
    _lang,
  );

  double get totalHours => employees.fold(0, (a, e) => a + e.hoursWorked);

  String get totalHoursLabel => '${totalHours.round()}h';

  double get estimatedCost =>
      employees.fold(0, (a, e) => a + e.hoursWorked * e.hourlyRate);

  String get estimatedCostLabel => Fmt.moneyCompact(estimatedCost);

  /// PENDIENTE: exportar requiere una Edge Function que genere el archivo
  /// y lo envíe por correo (ver services/reports_service.dart).
  void exportCsv() => flash(isDemo ? strings['exportOk'] : strings['comingSoon']);

  void exportPdf() => flash(isDemo ? strings['exportOk'] : strings['comingSoon']);

  // ---------------------------------------------------------------------
  // Toast y errores
  // ---------------------------------------------------------------------

  void flash(String message) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _flashError(AppException e) {
    if (e.code == 'not_authenticated' && !isDemo) {
      // Sesión vencida o revocada: volver al login.
      _session = null;
      notifyListeners();
    }
    flash(strings.error(e.code, detail: e.detail));
  }

  int _localSeq = 0;
  String _localId() => 'local-${++_localSeq}';

  // ---------------------------------------------------------------------
  // Modo demo
  // ---------------------------------------------------------------------

  /// El demo arranca el lunes 7 de septiembre de 2026 a las 08:18 (como el
  /// diseño original) y desde ahí avanza en tiempo real, así el reloj de
  /// fichaje corre pero los datos de ejemplo siempre cuadran.
  static DateTime Function() _demoClock() {
    final base = DateTime(2026, 9, 7, 8, 18);
    final started = DateTime.now();
    return () => base.add(DateTime.now().difference(started));
  }

  void _clearDemoClock() {
    // Al cambiar de rol en el demo no queda un fichaje "de otra persona".
    currentEntry = null;
    workPhotos = [];
  }

  static const _demoEmployeeId = 'e0';

  static final _demoManager = Employee(
    id: 'm0',
    name: 'Carlos Vega',
    email: 'carlos@elroble.co',
    role: UserRole.manager,
    roleEs: 'Gerente',
    roleEn: 'Manager',
    hourlyRate: 0,
    status: EmployeeStatus.active,
    avatarIndex: 0,
  );

  void _seedDemo() {
    _clearData();
    _demoRole = UserRole.manager;

    Employee emp(
      String id,
      String name,
      String es,
      String en,
      double rate,
      double hours,
      EmployeeStatus status,
      int avatar,
    ) => Employee(
      id: id,
      name: name,
      email: '${name.toLowerCase().replaceAll(' ', '.')}@elroble.co',
      role: UserRole.employee,
      roleEs: es,
      roleEn: en,
      hourlyRate: rate,
      status: status,
      avatarIndex: avatar,
      hoursWorked: hours,
    );

    employees = [
      emp('e0', 'Ana Torres', 'Mesera', 'Server', 6500, 62.5, EmployeeStatus.active, 0),
      emp('e1', 'Luis Pérez', 'Cocinero', 'Cook', 7200, 58, EmployeeStatus.active, 1),
      emp('e2', 'Marta Ruiz', 'Cajera', 'Cashier', 6100, 40, EmployeeStatus.active, 2),
      emp('e3', 'Diego Sáenz', 'Barista', 'Barista', 6400, 71.25, EmployeeStatus.active, 3),
      emp('e4', 'Sofía Lara', 'Mesera', 'Server', 6500, 34, EmployeeStatus.inactive, 4),
    ];

    sites = const [
      Site(
        id: 's0',
        name: 'El Roble',
        address: 'Cra. 7 #45-12',
        latitude: 4.6351,
        longitude: -74.0656,
        radiusMeters: 100,
      ),
    ];

    final ws = weekStart;
    var n = 0;
    Shift shift(int day, int from, int to, String? who) {
      final d = _addDays(ws, day);
      final start = DateTime(d.year, d.month, d.day, from);
      var end = DateTime(d.year, d.month, d.day, to);
      if (!end.isAfter(start)) end = _addDays(end, 1);
      return Shift(
        id: 'sh${n++}',
        siteId: 's0',
        employeeId: who,
        startsAt: start,
        endsAt: end,
      );
    }

    shifts = [
      shift(0, 9, 17, 'e0'), shift(0, 14, 22, 'e1'), shift(0, 7, 15, 'e3'),
      shift(1, 9, 17, 'e0'), shift(1, 7, 15, 'e3'),
      shift(2, 14, 22, 'e1'), shift(2, 9, 17, null), shift(2, 17, 1, null),
      shift(3, 9, 17, 'e0'), shift(3, 17, 1, 'e2'),
      shift(4, 9, 17, 'e0'), shift(4, 14, 22, 'e1'), shift(4, 7, 15, 'e3'),
      shift(5, 7, 15, 'e3'), shift(5, 11, 19, null),
    ];
    _rebuildWeek();
    final martaThu = shifts.firstWhere((s) => s.employeeId == 'e2');
    final diegoSat = shifts.firstWhere(
      (s) => s.employeeId == 'e3' && s.startsAt.weekday == DateTime.saturday,
    );
    final diegoToday = shifts.firstWhere(
      (s) => s.employeeId == 'e3' && DateUtils.isSameDay(s.startsAt, ws),
    );

    requests = [
      ShiftRequest(
        id: 'r1',
        kind: RequestKind.off,
        employeeId: 'e0',
        date: _addDays(ws, 3),
        reason: isEnglish ? 'Medical appointment' : 'Cita médica',
      ),
      ShiftRequest(
        id: 'r2',
        kind: RequestKind.swap,
        employeeId: 'e3',
        shiftId: diegoSat.id,
        date: DateUtils.dateOnly(diegoSat.startsAt),
      ),
      ShiftRequest(
        id: 'r3',
        kind: RequestKind.late,
        employeeId: 'e3',
        shiftId: diegoToday.id,
        date: ws,
      ),
      ShiftRequest(
        id: 'r4',
        kind: RequestKind.swap,
        employeeId: 'e2',
        shiftId: martaThu.id,
        date: DateUtils.dateOnly(martaThu.startsAt),
      ),
    ];

    swaps = [
      SwapOffer(
        id: 'w1',
        employeeId: 'e2',
        shiftId: martaThu.id,
        status: SwapStatus.open,
        requestId: 'r4',
      ),
      SwapOffer(
        id: 'w2',
        employeeId: 'e3',
        shiftId: diegoSat.id,
        status: SwapStatus.pending,
        claimedBy: 'e1',
        requestId: 'r2',
      ),
    ];

    todayEntries = [
      TimeEntry(
        id: 't1',
        employeeId: 'e3',
        siteId: 's0',
        shiftId: diegoToday.id,
        clockInAt: DateTime(ws.year, ws.month, ws.day, 7, 12),
      ),
    ];

    availability = [true, true, false, true, true, true, false];
    _demoAvailability
      ..clear()
      ..addAll({
        'e0': availability,
        'e1': [true, true, true, true, true, false, false],
        'e2': [false, true, true, true, true, true, false],
        'e3': [true, true, true, true, true, true, true],
      });

    final now = _now();
    threads = [
      ChatThread(id: 'general', name: 'General', isGeneral: true, unread: 3),
      ChatThread(id: 'LP', name: 'Luis Pérez', isGeneral: false, otherEmployeeId: 'e1', unread: 1),
      ChatThread(id: 'MR', name: 'Marta Ruiz', isGeneral: false, otherEmployeeId: 'e2'),
      ChatThread(id: 'DS', name: 'Diego Sáenz', isGeneral: false, otherEmployeeId: 'e3'),
    ];
    messagesByThread
      ..clear()
      ..addAll({
        'general': [
          ChatMessage(
            from: 'Ana',
            senderId: 'e0',
            text: '¿Alguien puede cubrir mi turno de mañana? Tengo cita médica.',
            fromMe: false,
          ),
          ChatMessage(
            from: 'Luis',
            senderId: 'e1',
            text: 'Yo puedo si nadie más se ofrece.',
            fromMe: false,
          ),
          ChatMessage(
            from: 'me',
            text: 'Confirmado, Luis toma el turno. Gracias equipo.',
            fromMe: true,
          ),
        ],
        'LP': [
          ChatMessage(
            from: 'Luis',
            senderId: 'e1',
            text: '¿Puedes cubrir mi turno del sábado?',
            fromMe: false,
          ),
        ],
        'MR': [
          ChatMessage(
            from: 'Marta',
            senderId: 'e2',
            text: '¡Gracias por el cambio!',
            fromMe: false,
          ),
        ],
        'DS': [
          ChatMessage(
            from: 'Diego',
            senderId: 'e3',
            text: 'Ya quedó lista la caja del turno.',
            fromMe: false,
          ),
        ],
      });
    for (final t in threads) {
      final msgs = messagesByThread[t.id];
      if (msgs != null && msgs.isNotEmpty) t.lastMessage = msgs.last.text;
    }

    notifs = [
      AppNotificationItem(
        id: 'n1',
        textEs: 'Tu turno empieza en 30 min',
        textEn: 'Your shift starts in 30 min',
        createdAt: now.subtract(const Duration(minutes: 3)),
      ),
      AppNotificationItem(
        id: 'n2',
        textEs: 'Luis quiere cambiar el turno del sábado',
        textEn: 'Luis wants to swap Saturday',
        createdAt: now.subtract(const Duration(minutes: 12)),
      ),
      AppNotificationItem(
        id: 'n3',
        textEs: 'Se aprobó tu día libre',
        textEn: 'Your day off was approved',
        createdAt: now.subtract(const Duration(hours: 1)),
        read: true,
      ),
      AppNotificationItem(
        id: 'n4',
        textEs: 'Olvidaste marcar salida el viernes',
        textEn: 'You forgot to clock out on Friday',
        createdAt: now.subtract(const Duration(days: 1)),
        read: true,
      ),
    ];
  }
}
