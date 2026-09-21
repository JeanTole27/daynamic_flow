/// CONEXIÓN PENDIENTE — no implementada a propósito.
///
/// Reemplaza `AppState.notifs` y las preferencias `AppState.prefs`. Una
/// implementación real necesita registrar el token del dispositivo
/// (Firebase Cloud Messaging / APNs), sincronizar preferencias con el
/// servidor, y recibir push en background para recordatorios de turno.
abstract class PushNotificationsService {
  Future<void> registerDeviceToken();

  Future<void> setPreference(String key, bool enabled);

  Stream<int> watchUnreadCount();
}
