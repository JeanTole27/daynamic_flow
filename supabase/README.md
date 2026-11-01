# Supabase · configuración

La app funciona en **modo demo** (datos en memoria) si no recibe credenciales.
Con credenciales se conecta a Supabase y todo (equipo, turnos, fichaje,
cambios de turno, chat, notificaciones, reportes y fotos de evidencia) se lee
y escribe en la base de datos.

## 1. Crear el esquema

```bash
supabase link --project-ref <ref>
supabase db push
```

`migrations/20261026000000_init.sql` crea tablas, políticas RLS, funciones
del servidor, el bucket privado `work-evidence` y la publicación de Realtime.

## 2. Primera organización y gerente

Los perfiles normales se crean con la invitación, pero el primer gerente se
crea a mano (SQL editor, como `postgres`):

1. En **Authentication → Users**, crea el usuario del gerente (correo + contraseña).
2. Ejecuta, con el `id` de ese usuario:

```sql
insert into organizations (name, timezone) values ('Mi empresa', 'America/Bogota') returning id;

insert into profiles (id, org_id, full_name, email, role, status)
values ('<user-id>', '<org-id>', 'Nombre Gerente', 'gerente@empresa.com', 'manager', 'active');

-- Cada oficina / sitio donde se trabaja o se limpia:
insert into sites (org_id, name, address, latitude, longitude, radius_m)
values ('<org-id>', 'Oficina Centro', 'Calle 1 #2-3', 4.6351, -74.0656, 100);

insert into chat_threads (org_id, is_general, name) values ('<org-id>', true, 'General');
```

`radius_m` es el radio (20–1000 m) dentro del cual se acepta el fichaje.
Usa coordenadas medidas en la puerta del sitio.

## 3. Invitaciones (Edge Function)

```bash
supabase functions deploy invite-employee
supabase secrets set INVITE_REDIRECT_URL=<deep link de la app, p. ej. com.tuempresa.turnos://login-callback>
```

La función usa la `service_role` **solo en el servidor**. Para que el enlace
del correo abra la app hay que configurar el deep link en Android/iOS y
agregarlo en **Authentication → URL Configuration → Redirect URLs**
(ver la guía de deep links de `supabase_flutter`).

## 4. Correr la app

Copia `env.example.json` a `env.json` (está en `.gitignore`) y completa:

```bash
flutter run --dart-define-from-file=env.json
```

Solo va la clave **publishable/anon**. Nunca pongas la `service_role` en la app.

## 5. Ajustes recomendados en el panel

- **Authentication → Providers → Email**: desactiva "Allow new users to sign up"
  (solo se entra por invitación) y sube la longitud mínima de contraseña a 8+.
- **Authentication → Rate limits**: deja los límites por defecto o más estrictos.
- **Database → Backups**: activa PITR si el plan lo permite (los fichajes son
  registros de nómina).

## Cómo se valida que la persona está en el sitio

1. La app pide la ubicación **solo en primer plano** al marcar entrada/salida
   (paquete `geolocator`), siempre una lectura nueva.
2. Envía latitud, longitud, precisión y si Android la marcó como simulada.
3. `clock_in()` en el servidor: elige el turno activo de esa persona (o el que
   empieza en ≤ 30 min), calcula la distancia al sitio de ese turno y rechaza
   si está fuera del radio, si la precisión es peor que 100 m, si la ubicación
   es simulada o si ya tiene una entrada abierta. Si llega > 10 min tarde,
   crea una solicitud `late` para el gerente.
4. `clock_out()` siempre deja salir, pero guarda la distancia y marca
   `clock_out_outside` si estaba fuera.

Limitación conocida: un teléfono rooteado puede falsear el GPS sin que
Android lo marque como simulado. Las fotos de evidencia (con hora y
coordenadas) ayudan a auditar esos casos.

## Pendiente (no implementado)

- Notificaciones push (FCM/APNs): hoy solo existe el buzón dentro de la app.
- Exportar reportes CSV/PDF: la app muestra "Próximamente".
- Corregir un fichaje desde la app (función `correct_time_entry` para gerentes).
- Crear y editar sitios desde la app (hoy se hace en Supabase).
