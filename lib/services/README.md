# Servicios (solo interfaces — sin conectar)

Esta carpeta **únicamente señala** dónde va cada integración real con
backend. Ninguna clase aquí hace una llamada de red: todas lanzan
`UnimplementedError` a propósito. Todo el estado y la lógica de la app
(`lib/state/app_state.dart`) funciona hoy con datos mock en memoria,
igual que el prototipo original.

Cuando se decida el backend (Firebase, REST propio, etc.), cada
interfaz de aquí se implementa y se inyecta en `AppState` reemplazando
el bloque de datos mock correspondiente — el resto de la UI no debería
necesitar cambios porque ya consume estas formas de datos.

| Archivo | Qué reemplaza |
|---|---|
| `auth_service.dart` | Login, aceptar invitación, sesión persistente |
| `team_repository.dart` | CRUD de empleados, invitaciones |
| `shifts_repository.dart` | Turnos, calendario semanal, solicitudes, cambios de turno |
| `time_clock_service.dart` | Fichaje con verificación de ubicación del lado del servidor |
| `chat_service.dart` | Mensajería en tiempo real |
| `push_notifications_service.dart` | Notificaciones push (FCM/APNs) y preferencias |
| `reports_service.dart` | Cálculo de horas/costos y export CSV/PDF por correo |
