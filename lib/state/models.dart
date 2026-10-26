import 'dart:typed_data';

enum UserRole { manager, employee }

enum EmployeeStatus { active, invited, inactive }

class Employee {
  Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.roleEs,
    required this.roleEn,
    required this.hourlyRate,
    required this.status,
    required this.avatarIndex,
    this.hoursWorked = 0,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;

  /// Cargo (mesera, cocinero, limpieza…) en cada idioma.
  final String roleEs;
  final String roleEn;
  final double hourlyRate;
  EmployeeStatus status;
  final int avatarIndex;

  /// Horas en el periodo de pago actual — se usa para marcar horas extra.
  double hoursWorked;

  String get firstName => name.split(' ').first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  String get hoursLabel {
    final totalMinutes = (hoursWorked * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String roleFor(bool english) => english ? roleEn : roleEs;
}

/// Oficina, local o sitio donde se trabaja o se limpia. El fichaje solo se
/// acepta dentro de [radiusMeters] alrededor de estas coordenadas.
class Site {
  const Site({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.address,
  });

  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final int radiusMeters;
}

/// Turno real con fecha. `employeeId == null` es un turno sin cubrir.
class Shift {
  Shift({
    required this.id,
    required this.siteId,
    required this.startsAt,
    required this.endsAt,
    this.employeeId,
  });

  final String id;
  final String siteId;
  String? employeeId;
  final DateTime startsAt;
  final DateTime endsAt;

  Duration get duration => endsAt.difference(startsAt);
}

enum RequestKind { off, swap, late }

class ShiftRequest {
  ShiftRequest({
    required this.id,
    required this.kind,
    required this.employeeId,
    required this.date,
    this.shiftId,
    this.reason,
    this.resolved = false,
  });

  final String id;
  final RequestKind kind;
  final String employeeId;
  final String? shiftId;
  final DateTime date;
  final String? reason;
  bool resolved;
}

enum SwapStatus { open, offered, pending }

class SwapOffer {
  SwapOffer({
    required this.id,
    required this.employeeId,
    required this.shiftId,
    required this.status,
    this.claimedBy,
    this.requestId,
  });

  final String id;

  /// Quien ofreció el turno.
  final String employeeId;
  final String shiftId;
  SwapStatus status;
  String? claimedBy;

  /// Solicitud que el gerente aprueba para cerrar el cambio.
  final String? requestId;
}

/// Vista de un día para el calendario del gerente (derivada de [Shift]).
class ShiftSlot {
  const ShiftSlot({
    required this.shiftId,
    required this.employeeId,
    required this.timeLabel,
  });

  final String shiftId;
  final String employeeId;
  final String timeLabel;
}

class WeekDay {
  WeekDay({
    required this.date,
    required List<ShiftSlot> slots,
    required this.openCount,
  }) : slots = List.of(slots);

  final DateTime date;
  List<ShiftSlot> slots;
  int openCount;

  int get weekdayIndex => date.weekday - 1; // 0 = Mon .. 6 = Sun
  int get dayNumber => date.day;
}

class TimeEntry {
  TimeEntry({
    required this.id,
    required this.employeeId,
    required this.siteId,
    required this.clockInAt,
    this.shiftId,
    this.clockOutAt,
    this.clockOutOutside = false,
  });

  final String id;
  final String employeeId;
  final String siteId;
  final String? shiftId;
  final DateTime clockInAt;
  DateTime? clockOutAt;
  bool clockOutOutside;

  bool get isOpen => clockOutAt == null;
}

/// Foto de evidencia del trabajo, ligada a un fichaje.
class WorkPhoto {
  WorkPhoto({
    required this.id,
    required this.timeEntryId,
    required this.takenAt,
    this.url,
    this.bytes,
  });

  final String id;
  final String timeEntryId;
  final DateTime takenAt;

  /// URL firmada y temporal (Supabase Storage es privado).
  final String? url;

  /// Solo en modo demo: la foto se queda en memoria.
  final Uint8List? bytes;
}

class ChatThread {
  ChatThread({
    required this.id,
    required this.name,
    required this.isGeneral,
    this.otherEmployeeId,
    this.lastMessage = '',
    this.unread = 0,
  });

  final String id;
  final String name;
  final bool isGeneral;
  final String? otherEmployeeId;
  String lastMessage;
  int unread;
}

class ChatMessage {
  ChatMessage({
    required this.from,
    required this.text,
    required this.fromMe,
    this.senderId,
    DateTime? sentAt,
  }) : sentAt = sentAt ?? DateTime.now();

  final String from;
  final String? senderId;
  final String text;
  final bool fromMe;
  final DateTime sentAt;
}

class AppNotificationItem {
  AppNotificationItem({
    required this.id,
    required this.textEs,
    required this.textEn,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String textEs;
  final String textEn;
  final DateTime createdAt;
  bool read;

  String textFor(bool english) => english ? textEn : textEs;
}

/// Lectura del GPS del dispositivo en el momento de fichar.
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.isMocked,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;

  /// Android marca las ubicaciones de apps de "ubicación falsa".
  final bool isMocked;
}

/// Resultado de comprobar si la persona está en el sitio de su turno.
enum LocationStatus {
  unknown,
  checking,
  inside,
  outside,
  lowAccuracy,
  denied,
  servicesOff,
  mocked,
  noShift,
}

/// Un usuario autenticado con su perfil y su organización.
class SessionUser {
  const SessionUser({required this.profile, required this.orgName});

  final Employee profile;
  final String orgName;
}

/// Error de negocio con un código que la UI traduce (ver `errorMessage`).
class AppException implements Exception {
  const AppException(this.code, {this.detail});

  final String code;
  final String? detail;

  @override
  String toString() => 'AppException($code${detail == null ? '' : ', $detail'})';
}
