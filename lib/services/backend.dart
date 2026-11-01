import 'auth_service.dart';
import 'chat_service.dart';
import 'device_services.dart';
import 'notifications_repository.dart';
import 'reports_service.dart';
import 'shifts_repository.dart';
import 'team_repository.dart';
import 'time_clock_service.dart';

/// Todas las conexiones reales que usa `AppState`. Con `backend == null` la
/// app funciona en modo demo con datos en memoria.
class Backend {
  const Backend({
    required this.auth,
    required this.team,
    required this.shifts,
    required this.clock,
    required this.chat,
    required this.notifications,
    required this.reports,
    required this.location,
    required this.changes,
  });

  final AuthService auth;
  final TeamRepository team;
  final ShiftsRepository shifts;
  final TimeClockService clock;
  final ChatService chat;
  final NotificationsRepository notifications;
  final ReportsService reports;
  final LocationService location;

  /// Nombre de la tabla que cambió (Realtime). La app recarga esa parte.
  final Stream<String> Function() changes;
}
