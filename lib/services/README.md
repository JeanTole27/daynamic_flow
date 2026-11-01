# Servicios

`AppState` (`lib/state/app_state.dart`) recibe un `Backend` con estas
interfaces. Sin backend funciona en modo demo con datos en memoria.

| Archivo | Qué hace |
|---|---|
| `backend.dart` | Agrupa todas las conexiones y el stream de cambios en tiempo real |
| `auth_service.dart` | Login, aceptar invitación, sesión guardada |
| `team_repository.dart` | Equipo, sitios, invitaciones, activar/desactivar |
| `shifts_repository.dart` | Turnos, solicitudes, cambios de turno, disponibilidad |
| `time_clock_service.dart` | Fichaje (validado en el servidor) y fotos de evidencia |
| `chat_service.dart` | Hilos, mensajes, chat directo |
| `notifications_repository.dart` | Buzón de notificaciones y preferencias |
| `reports_service.dart` | Horas por empleado en un periodo |
| `device_services.dart` | GPS y cámara del dispositivo |
| `supabase/supabase_backend.dart` | Implementación con Supabase |
| `device/` | Implementaciones con `geolocator` e `image_picker` |

Toda la autorización vive en el servidor (RLS y funciones en
`supabase/migrations`). El código de la app asume que cualquier llamada puede
ser rechazada y traduce los códigos de error con `AppStrings.error`.

Configuración y despliegue: `supabase/README.md`.
