import 'package:flutter/material.dart';

import '../i18n/app_lang.dart';
import '../i18n/app_strings.dart';
import 'app_scaffold_messenger.dart';
import 'models.dart';

/// Central app state — mock/in-memory, ported 1:1 from the `Component`
/// logic class in the original `Turnos.dc.html` prototype.
///
/// This holds every piece of data the screens read and every mutation the
/// screens trigger (approve a request, clock in, send a chat message…).
/// None of it talks to a network: every method that a real backend would
/// need is called out with a `// CONEXIÓN:` comment pointing at the
/// matching interface under `lib/services/`. Swapping the mock data below
/// for a real repository should not require changing the screens.
class AppState extends ChangeNotifier {
  AppState() {
    _seed();
  }

  // ---------------------------------------------------------------------
  // Session / locale
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

  UserRole _role = UserRole.manager;
  UserRole get role => _role;

  String _email = 'carlos@elroble.co';
  String get email => _email;

  /// CONEXIÓN: reemplazar por AuthService.signIn (ver services/auth_service.dart).
  void loginAs(UserRole role, {String? email}) {
    _role = role;
    if (email != null) _email = email;
    notifyListeners();
  }

  /// CONEXIÓN: reemplazar por AuthService.acceptInvite.
  void acceptInvite() {
    _role = UserRole.employee;
    notifyListeners();
  }

  void switchRole() {
    _role = _role == UserRole.manager ? UserRole.employee : UserRole.manager;
    notifyListeners();
  }

  /// CONEXIÓN: reemplazar por AuthService.signOut.
  void logout() {
    // El estado mock no necesita limpiarse para la demo; una integración
    // real sí debería borrar sesión/token aquí.
  }

  // ---------------------------------------------------------------------
  // Team
  // ---------------------------------------------------------------------

  final List<Employee> employees = [
    Employee(
      id: 0,
      initials: 'AT',
      name: 'Ana Torres',
      roleEs: 'Mesera',
      roleEn: 'Server',
      rate: '\$6.500',
      hoursWorked: 62.5,
      hoursLabel: '62h 30m',
      status: EmployeeStatus.active,
      avatarIndex: 0,
    ),
    Employee(
      id: 1,
      initials: 'LP',
      name: 'Luis Pérez',
      roleEs: 'Cocinero',
      roleEn: 'Cook',
      rate: '\$7.200',
      hoursWorked: 58,
      hoursLabel: '58h 00m',
      status: EmployeeStatus.active,
      avatarIndex: 1,
    ),
    Employee(
      id: 2,
      initials: 'MR',
      name: 'Marta Ruiz',
      roleEs: 'Cajera',
      roleEn: 'Cashier',
      rate: '\$6.100',
      hoursWorked: 40,
      hoursLabel: '40h 00m',
      status: EmployeeStatus.invited,
      avatarIndex: 2,
    ),
    Employee(
      id: 3,
      initials: 'DS',
      name: 'Diego Sáenz',
      roleEs: 'Barista',
      roleEn: 'Barista',
      rate: '\$6.400',
      hoursWorked: 71.25,
      hoursLabel: '71h 15m',
      status: EmployeeStatus.active,
      avatarIndex: 3,
    ),
    Employee(
      id: 4,
      initials: 'SL',
      name: 'Sofía Lara',
      roleEs: 'Mesera',
      roleEn: 'Server',
      rate: '\$6.500',
      hoursWorked: 34,
      hoursLabel: '34h 00m',
      status: EmployeeStatus.inactive,
      avatarIndex: 4,
    ),
  ];

  Employee employeeById(int id) => employees.firstWhere((e) => e.id == id);

  List<Employee> searchEmployees(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return employees;
    return employees.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  /// CONEXIÓN: reemplazar por TeamRepository.inviteEmployee.
  void inviteEmployee() {
    flash(strings['inviteOk']);
  }

  void saveEmployeeChanges(int employeeId) {
    flash(strings['saveOk']);
  }

  /// CONEXIÓN: reemplazar por TeamRepository.setEmployeeStatus.
  void deactivateEmployee(int employeeId) {
    final e = employeeById(employeeId);
    e.status = EmployeeStatus.inactive;
    flash(strings['saveOk']);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Requests (time-off / swap / late clock-in) — manager inbox
  // ---------------------------------------------------------------------

  final List<ShiftRequest> requests = [
    ShiftRequest(
      id: 1,
      kind: RequestKind.off,
      employeeId: 0,
      dateLabel: '10/09',
    ),
    ShiftRequest(
      id: 2,
      kind: RequestKind.swap,
      employeeId: 1,
      dateLabel: 'Mar 05/09',
      timeLabel: '14:00–22:00',
    ),
    ShiftRequest(
      id: 3,
      kind: RequestKind.late,
      employeeId: 3,
      // requestSubtitle() renders its own "today"/"hoy" for RequestKind.late
      // and ignores dateLabel — kept as a placeholder for symmetry with the
      // other kinds.
      dateLabel: '—',
      timeLabel: '08:24',
    ),
  ];

  List<ShiftRequest> get pendingRequests =>
      requests.where((r) => !r.resolved).toList();

  String requestTitle(ShiftRequest r) {
    final who = employeeById(r.employeeId).name.split(' ').first;
    return switch (r.kind) {
      RequestKind.off => isEnglish
          ? '$who asks for ${r.dateLabel} off'
          : '$who pide libre el ${r.dateLabel}',
      RequestKind.swap => isEnglish
          ? '$who wants to swap a shift'
          : '$who quiere cambiar un turno',
      RequestKind.late => isEnglish
          ? '$who clocked in late'
          : '$who marcó entrada tarde',
    };
  }

  String requestSubtitle(ShiftRequest r) {
    return switch (r.kind) {
      RequestKind.off =>
        isEnglish ? 'Reason: medical appointment' : 'Motivo: cita médica',
      RequestKind.swap => '${r.dateLabel} · ${r.timeLabel}',
      RequestKind.late =>
        '${isEnglish ? "In at " : "Entrada "}${r.timeLabel} · '
            '${isEnglish ? "today" : "hoy"}',
    };
  }

  /// CONEXIÓN: reemplazar por ShiftsRepository.resolveRequest.
  void approveRequest(int requestId) {
    requests.firstWhere((r) => r.id == requestId).resolved = true;
    flash(strings['approvedMsg']);
    notifyListeners();
  }

  void rejectRequest(int requestId) {
    requests.firstWhere((r) => r.id == requestId).resolved = true;
    flash(strings['declinedMsg']);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Weekly schedule (manager view + slots used by the employee view)
  // ---------------------------------------------------------------------

  late List<WeekDay> week;

  int get uncoveredCount => week.fold(0, (a, d) => a + d.openCount);

  /// Días (índices lun=0..vie=4) en los que Ana (empleado demo, id 0)
  /// tiene turno esta semana — usado por la vista "Tu semana" del empleado.
  static const List<int> employeeShiftDays = [0, 1, 3, 4];

  /// CONEXIÓN: reemplazar por ShiftsRepository.createShift.
  void createShift({
    required int employeeId,
    required int weekdayIndex,
    required String timeLabel,
  }) {
    final day = week.firstWhere((d) => d.weekdayIndex == weekdayIndex);
    day.slots = [...day.slots, ShiftSlot(employeeId: employeeId, timeLabel: timeLabel)];
    day.openCount = (day.openCount - 1).clamp(0, 999);
    final empName = employeeById(employeeId).name.split(' ').first;
    flash('${strings['shiftOk']} · $empName ${dayLabels[weekdayIndex]} $timeLabel');
    notifyListeners();
  }

  /// CONEXIÓN: reemplazar por ShiftsRepository.duplicatePreviousWeek.
  void duplicateWeek() {
    flash(strings['dupOk']);
  }

  // ---------------------------------------------------------------------
  // Employee: availability
  // ---------------------------------------------------------------------

  final List<bool> availability = [true, true, false, true, true, true, false];

  void toggleAvailability(int weekdayIndex) {
    availability[weekdayIndex] = !availability[weekdayIndex];
    notifyListeners();
  }

  /// CONEXIÓN: reemplazar por un repositorio de disponibilidad (no hay
  /// interfaz dedicada todavía — es parte natural de ShiftsRepository).
  void saveAvailability() {
    flash(strings['savedOk']);
  }

  // ---------------------------------------------------------------------
  // Employee: shift swaps
  // ---------------------------------------------------------------------

  final List<SwapOffer> swaps = [
    SwapOffer(
      id: 11,
      employeeId: 2,
      dayLabel: 'Mié 9',
      timeLabel: '17:00–01:00',
      status: SwapStatus.open,
    ),
    SwapOffer(
      id: 12,
      employeeId: 3,
      dayLabel: 'Sáb 12',
      timeLabel: '07:00–15:00',
      status: SwapStatus.pending,
    ),
  ];

  /// CONEXIÓN: reemplazar por ShiftsRepository.offerShift.
  void offerShift(int weekdayIndex) {
    const meId = 0; // usuario empleado demo (Ana Torres)
    final dayLabel = '${dayLabels[weekdayIndex]} ${weekdayIndex + 1}';
    swaps.insert(
      0,
      SwapOffer(
        id: 90 + weekdayIndex,
        employeeId: meId,
        dayLabel: dayLabel,
        timeLabel: '09:00–17:00',
        status: SwapStatus.offered,
      ),
    );
    requests.insert(
      0,
      ShiftRequest(
        id: 80 + weekdayIndex,
        kind: RequestKind.swap,
        employeeId: meId,
        dateLabel: dayLabel,
        timeLabel: '09:00–17:00',
      ),
    );
    flash(strings['shiftOfferedMsg']);
    notifyListeners();
  }

  /// CONEXIÓN: reemplazar por ShiftsRepository.claimSwap.
  void claimSwap(int swapId) {
    swaps.firstWhere((s) => s.id == swapId).status = SwapStatus.pending;
    flash(strings['swapRequestedMsg']);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Time clock
  // ---------------------------------------------------------------------

  bool clockedIn = false;
  DateTime? clockStart;

  /// CONEXIÓN: reemplazar por una lectura real de ubicación (geolocator)
  /// + verificación del radio permitido en el servidor
  /// (ver services/time_clock_service.dart). Fijo en `true` para la demo.
  bool get insideAllowedRadius => true;

  Duration get elapsed =>
      clockedIn && clockStart != null ? DateTime.now().difference(clockStart!) : Duration.zero;

  static String formatElapsed(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  /// CONEXIÓN: reemplazar por TimeClockService.clockIn / clockOut.
  void clockToggle() {
    if (!insideAllowedRadius) {
      flash(strings['moveCloser']);
      return;
    }
    if (clockedIn) {
      clockedIn = false;
      clockStart = null;
      flash(strings['clockedOutMsg']);
    } else {
      clockedIn = true;
      clockStart = DateTime.now();
      flash(strings['clockedInMsg']);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------

  final Map<String, List<ChatMessage>> messagesByThread = {
    'general': [
      ChatMessage(
        from: 'Ana',
        text: '¿Alguien puede cubrir mi turno de mañana? Tengo cita médica.',
        fromMe: false,
      ),
      ChatMessage(
        from: 'Luis',
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
        text: '¿Puedes cubrir mi turno del sábado?',
        fromMe: false,
      ),
    ],
    'MR': [
      ChatMessage(from: 'Marta', text: '¡Gracias por el cambio!', fromMe: false),
    ],
    'DS': [
      ChatMessage(
        from: 'Diego',
        text: 'Ya quedó lista la caja del turno.',
        fromMe: false,
      ),
    ],
  };

  static const List<({String key, String initials, String name})>
  chatThreadMeta = [
    (key: 'general', initials: '#', name: 'General'),
    (key: 'LP', initials: 'LP', name: 'Luis Pérez'),
    (key: 'MR', initials: 'MR', name: 'Marta Ruiz'),
    (key: 'DS', initials: 'DS', name: 'Diego Sáenz'),
  ];

  List<ChatMessage> threadMessages(String threadId) =>
      messagesByThread[threadId] ?? const [];

  /// CONEXIÓN: reemplazar por ChatService.sendMessage.
  void sendMessage(String threadId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final list = messagesByThread.putIfAbsent(threadId, () => []);
    list.add(ChatMessage(from: 'me', text: trimmed, fromMe: true));
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------

  final List<AppNotificationItem> notifs = [
    AppNotificationItem(
      id: 1,
      textEs: 'Tu turno empieza en 30 min',
      textEn: 'Your shift starts in 30 min',
      timeLabel: '09:00 · Mesera',
    ),
    AppNotificationItem(
      id: 2,
      textEs: 'Luis quiere cambiar el turno del sábado',
      textEn: 'Luis wants to swap Saturday',
      timeLabel: 'Hace 12 min',
    ),
    AppNotificationItem(
      id: 3,
      textEs: 'Se aprobó tu día libre del 10/09',
      textEn: 'Your day off on 09/10 was approved',
      timeLabel: 'Hace 1 hora',
      read: true,
    ),
    AppNotificationItem(
      id: 4,
      textEs: 'Olvidaste marcar salida el viernes',
      textEn: 'You forgot to clock out on Friday',
      timeLabel: 'Ayer',
      read: true,
    ),
  ];

  bool get hasUnreadNotifs => notifs.any((n) => !n.read);

  void markNotifRead(int id) {
    notifs.firstWhere((n) => n.id == id).read = true;
    notifyListeners();
  }

  void markAllNotifsRead() {
    for (final n in notifs) {
      n.read = true;
    }
    notifyListeners();
  }

  /// Recordatorio de turno / mensajes nuevos / olvidé marcar salida.
  final List<bool> notifPrefs = [true, true, false];

  /// CONEXIÓN: reemplazar por PushNotificationsService.setPreference.
  void toggleNotifPref(int index) {
    notifPrefs[index] = !notifPrefs[index];
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Reports
  // ---------------------------------------------------------------------

  double get totalHours => employees.fold(0, (a, e) => a + e.hoursWorked);
  static const String estimatedCostLabel = r'\$2.03M';
  static const String totalHoursLabel = '312h';
  static const double overtimeThresholdHours = 65;

  /// CONEXIÓN: reemplazar por ReportsService.exportCsv.
  void exportCsv() => flash(strings['exportOk']);

  /// CONEXIÓN: reemplazar por ReportsService.exportPdf.
  void exportPdf() => flash(strings['exportOk']);

  // ---------------------------------------------------------------------
  // "Who's working today" (manager)
  // ---------------------------------------------------------------------

  static const List<
    ({int employeeId, String subEs, String subEn, String hours, bool onShift})
  >
  liveBoard = [
    (
      employeeId: 0,
      subEs: 'Entrada 09:00',
      subEn: 'In at 9:00',
      hours: '4h 12m',
      onShift: true,
    ),
    (
      employeeId: 3,
      subEs: 'Entrada 07:02',
      subEn: 'In at 7:02',
      hours: '6h 10m',
      onShift: true,
    ),
    (
      employeeId: 1,
      subEs: 'Empieza 14:00',
      subEn: 'Starts 2:00 PM',
      hours: '—',
      onShift: false,
    ),
    (
      employeeId: 2,
      subEs: 'Sin marcar hoy',
      subEn: 'Not clocked in',
      hours: '—',
      onShift: false,
    ),
    (
      employeeId: 4,
      subEs: 'Libre',
      subEn: 'Off',
      hours: '—',
      onShift: false,
    ),
  ];

  int get workingNowCount => liveBoard.where((l) => l.onShift).length;
  static const int teamSize = 10; // tamaño de equipo de referencia del diseño

  void fixClockEntry(int employeeId) => flash(strings['saveOk']);

  // ---------------------------------------------------------------------
  // Toast
  // ---------------------------------------------------------------------

  void flash(String message) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------
  // Seed data that depends on translated day labels.
  // ---------------------------------------------------------------------

  void _seed() {
    week = [
      WeekDay(
        weekdayIndex: 0,
        dayNumber: 1,
        slots: const [
          ShiftSlot(employeeId: 0, timeLabel: '09–17'),
          ShiftSlot(employeeId: 1, timeLabel: '14–22'),
        ],
        openCount: 0,
      ),
      WeekDay(
        weekdayIndex: 1,
        dayNumber: 2,
        slots: const [
          ShiftSlot(employeeId: 0, timeLabel: '09–17'),
          ShiftSlot(employeeId: 3, timeLabel: '07–15'),
        ],
        openCount: 1,
      ),
      WeekDay(
        weekdayIndex: 2,
        dayNumber: 3,
        slots: const [ShiftSlot(employeeId: 1, timeLabel: '14–22')],
        openCount: 2,
      ),
      WeekDay(
        weekdayIndex: 3,
        dayNumber: 4,
        slots: const [
          ShiftSlot(employeeId: 0, timeLabel: '09–17'),
          ShiftSlot(employeeId: 2, timeLabel: '17–01'),
        ],
        openCount: 0,
      ),
      WeekDay(
        weekdayIndex: 4,
        dayNumber: 5,
        slots: const [
          ShiftSlot(employeeId: 0, timeLabel: '09–17'),
          ShiftSlot(employeeId: 1, timeLabel: '14–22'),
          ShiftSlot(employeeId: 3, timeLabel: '07–15'),
        ],
        openCount: 0,
      ),
      WeekDay(
        weekdayIndex: 5,
        dayNumber: 6,
        slots: const [ShiftSlot(employeeId: 4, timeLabel: '11–19')],
        openCount: 1,
      ),
      WeekDay(weekdayIndex: 6, dayNumber: 7, slots: const [], openCount: 0),
    ];
  }
}
