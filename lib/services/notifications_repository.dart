import '../state/models.dart';

/// Notificaciones dentro de la app y preferencias.
///
/// PENDIENTE: las notificaciones push (FCM/APNs) necesitan un proyecto de
/// Firebase y un envío desde el servidor; aquí solo está el buzón interno.
abstract class NotificationsRepository {
  Future<List<AppNotificationItem>> fetchNotifications();

  Future<void> markRead(String id);

  Future<void> markAllRead();

  /// [shiftReminder, newMessages, forgotClockOut]
  Future<List<bool>> fetchPrefs();

  Future<void> savePrefs(List<bool> prefs);
}
