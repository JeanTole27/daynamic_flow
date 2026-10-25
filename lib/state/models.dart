enum UserRole { manager, employee }

enum EmployeeStatus { active, invited, inactive }

class Employee {
  Employee({
    required this.id,
    required this.initials,
    required this.name,
    required this.roleEs,
    required this.roleEn,
    required this.rate,
    required this.hoursWorked,
    required this.hoursLabel,
    required this.status,
    required this.avatarIndex,
  });

  final int id;
  final String initials;
  final String name;
  final String roleEs;
  final String roleEn;
  final String rate;

  /// Raw hours in the current pay period — used to flag overtime (> 65h).
  final double hoursWorked;
  final String hoursLabel;
  EmployeeStatus status;
  final int avatarIndex;

  String roleFor(bool english) => english ? roleEn : roleEs;
}

enum RequestKind { off, swap, late }

class ShiftRequest {
  ShiftRequest({
    required this.id,
    required this.kind,
    required this.employeeId,
    required this.dateLabel,
    this.timeLabel,
    this.resolved = false,
  });

  final int id;
  final RequestKind kind;
  final int employeeId;
  final String dateLabel;
  final String? timeLabel;
  bool resolved;
}

enum SwapStatus { open, offered, pending }

class SwapOffer {
  SwapOffer({
    required this.id,
    required this.employeeId,
    required this.dayLabel,
    required this.timeLabel,
    required this.status,
  });

  final int id;
  final int employeeId;
  final String dayLabel;
  final String timeLabel;
  SwapStatus status;
}

class ShiftSlot {
  const ShiftSlot({required this.employeeId, required this.timeLabel});

  final int employeeId;
  final String timeLabel;
}

class WeekDay {
  WeekDay({
    required this.weekdayIndex,
    required this.dayNumber,
    required List<ShiftSlot> slots,
    required this.openCount,
  }) : slots = List.of(slots);

  final int weekdayIndex; // 0 = Mon .. 6 = Sun
  final int dayNumber;
  List<ShiftSlot> slots;
  int openCount;
}

class ChatMessage {
  ChatMessage({required this.from, required this.text, required this.fromMe});

  final String from;
  final String text;
  final bool fromMe;
}

class AppNotificationItem {
  AppNotificationItem({
    required this.id,
    required this.textEs,
    required this.textEn,
    required this.timeLabel,
    this.read = false,
  });

  final int id;
  final String textEs;
  final String textEn;
  final String timeLabel;
  bool read;

  String textFor(bool english) => english ? textEn : textEs;
}
