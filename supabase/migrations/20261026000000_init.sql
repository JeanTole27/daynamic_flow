-- =====================================================================
-- Turnos · esquema inicial
--
-- Principios de seguridad:
--  * RLS activado en TODAS las tablas. Sin política = sin acceso.
--  * Todo se limita a la organización del usuario (current_org_id()).
--  * Un perfil 'inactive' pierde el acceso (current_org_id() devuelve null).
--  * Las operaciones sensibles (fichaje, aprobar solicitudes, cambios de
--    turno) NO se pueden hacer con insert/update directo: solo con las
--    funciones RPC de abajo, que validan en el servidor.
--  * El fichaje valida la ubicación en el servidor contra el sitio del
--    turno: el cliente solo envía coordenadas, nunca decide si está dentro.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;
create extension if not exists btree_gist with schema extensions;

-- ---------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------

create type public.user_role as enum ('manager', 'employee');
create type public.employee_status as enum ('active', 'invited', 'inactive');
create type public.request_kind as enum ('off', 'swap', 'late');
create type public.request_status as enum ('pending', 'approved', 'rejected');
create type public.swap_status as enum ('open', 'claimed', 'approved', 'cancelled');

-- ---------------------------------------------------------------------
-- Tablas
-- ---------------------------------------------------------------------

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  -- Zona horaria del negocio: define qué "día" es un turno o un día libre.
  timezone text not null default 'America/Bogota',
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  org_id uuid not null references public.organizations (id),
  full_name text not null check (char_length(full_name) between 1 and 120),
  email text not null,
  role public.user_role not null default 'employee',
  position_es text not null default '' check (char_length(position_es) <= 60),
  position_en text not null default '' check (char_length(position_en) <= 60),
  hourly_rate numeric(12, 2) not null default 0 check (hourly_rate >= 0),
  status public.employee_status not null default 'invited',
  avatar_index smallint not null default 0 check (avatar_index between 0 and 15),
  created_at timestamptz not null default now()
);
create index profiles_org_idx on public.profiles (org_id);

-- Oficina / local / sitio donde se trabaja o se limpia.
create table public.sites (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id),
  name text not null check (char_length(name) between 1 and 120),
  address text check (char_length(address) <= 240),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  radius_m integer not null default 100 check (radius_m between 20 and 1000),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index sites_org_idx on public.sites (org_id);

-- employee_id null = turno sin cubrir.
create table public.shifts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id),
  site_id uuid not null references public.sites (id),
  employee_id uuid references public.profiles (id) on delete set null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_by uuid references public.profiles (id) default auth.uid(),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at),
  check (ends_at - starts_at <= interval '16 hours'),
  -- Una persona no puede tener dos turnos que se crucen.
  constraint shifts_no_overlap exclude using gist (
    employee_id with =,
    tstzrange(starts_at, ends_at) with &&
  ) where (employee_id is not null)
);
create index shifts_org_start_idx on public.shifts (org_id, starts_at);
create index shifts_employee_start_idx on public.shifts (employee_id, starts_at);

create table public.shift_requests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id),
  kind public.request_kind not null,
  employee_id uuid not null references public.profiles (id) on delete cascade,
  shift_id uuid references public.shifts (id) on delete cascade,
  request_date date not null,
  reason text check (char_length(reason) <= 500),
  status public.request_status not null default 'pending',
  resolved_by uuid references public.profiles (id),
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);
create index shift_requests_org_status_idx on public.shift_requests (org_id, status);

create table public.swap_offers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id),
  shift_id uuid not null references public.shifts (id) on delete cascade,
  offered_by uuid not null references public.profiles (id) on delete cascade,
  claimed_by uuid references public.profiles (id) on delete set null,
  request_id uuid references public.shift_requests (id) on delete set null,
  status public.swap_status not null default 'open',
  created_at timestamptz not null default now()
);
-- Un turno solo puede tener una oferta viva a la vez.
create unique index swap_offers_one_active_idx
  on public.swap_offers (shift_id) where status in ('open', 'claimed');

create table public.availability (
  employee_id uuid not null references public.profiles (id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6), -- 0 = lunes
  available boolean not null,
  primary key (employee_id, weekday)
);

create table public.time_entries (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id),
  employee_id uuid not null references public.profiles (id) on delete cascade,
  site_id uuid not null references public.sites (id),
  shift_id uuid references public.shifts (id) on delete set null,
  clock_in_at timestamptz not null default now(),
  clock_in_lat double precision not null,
  clock_in_lng double precision not null,
  clock_in_accuracy_m double precision not null,
  clock_in_distance_m double precision not null,
  clock_out_at timestamptz,
  clock_out_lat double precision,
  clock_out_lng double precision,
  clock_out_accuracy_m double precision,
  clock_out_distance_m double precision,
  clock_out_outside boolean,
  check (clock_out_at is null or clock_out_at > clock_in_at)
);
-- Como máximo un fichaje abierto por empleado.
create unique index time_entries_one_open_idx
  on public.time_entries (employee_id) where clock_out_at is null;
create index time_entries_org_in_idx on public.time_entries (org_id, clock_in_at);

-- Evidencia fotográfica del trabajo hecho durante un fichaje.
create table public.work_photos (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id),
  time_entry_id uuid not null references public.time_entries (id) on delete cascade,
  employee_id uuid not null references public.profiles (id) on delete cascade,
  storage_path text not null unique,
  latitude double precision,
  longitude double precision,
  note text check (char_length(note) <= 500),
  taken_at timestamptz not null default now()
);
create index work_photos_entry_idx on public.work_photos (time_entry_id);

create table public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id),
  is_general boolean not null default false,
  name text check (char_length(name) <= 120),
  created_at timestamptz not null default now()
);
create unique index chat_threads_one_general_idx
  on public.chat_threads (org_id) where is_general;

create table public.chat_members (
  thread_id uuid not null references public.chat_threads (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (thread_id, profile_id)
);

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index chat_messages_thread_idx on public.chat_messages (thread_id, created_at);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  text_es text not null,
  text_en text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index notifications_profile_idx on public.notifications (profile_id, created_at desc);

create table public.notification_prefs (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  shift_reminder boolean not null default true,
  new_messages boolean not null default true,
  forgot_clock_out boolean not null default false
);

-- ---------------------------------------------------------------------
-- Funciones auxiliares para RLS
-- ---------------------------------------------------------------------

create or replace function public.current_org_id()
returns uuid
language sql stable security definer set search_path = ''
as $$
  select org_id from public.profiles
  where id = auth.uid() and status <> 'inactive'
$$;

create or replace function public.is_manager()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'manager' and status = 'active'
  )
$$;

create or replace function public.org_timezone(p_org uuid)
returns text
language sql stable security definer set search_path = ''
as $$
  select coalesce((select timezone from public.organizations where id = p_org), 'UTC')
$$;

-- Distancia en metros (haversine). Suficiente para radios de decenas de
-- metros; no requiere PostGIS.
create or replace function public.distance_m(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
)
returns double precision
language sql immutable set search_path = ''
as $$
  select 2 * 6371000 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2)
    + cos(radians(lat1)) * cos(radians(lat2))
      * power(sin(radians(lng2 - lng1) / 2), 2)
  ))
$$;

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.sites enable row level security;
alter table public.shifts enable row level security;
alter table public.shift_requests enable row level security;
alter table public.swap_offers enable row level security;
alter table public.availability enable row level security;
alter table public.time_entries enable row level security;
alter table public.work_photos enable row level security;
alter table public.chat_threads enable row level security;
alter table public.chat_members enable row level security;
alter table public.chat_messages enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_prefs enable row level security;

-- Organizations
create policy "org: miembros leen" on public.organizations
  for select to authenticated
  using (id = (select public.current_org_id()));

-- Profiles: todos leen su equipo; solo el gerente edita, y solo ciertas
-- columnas (ver grants abajo). Nadie inserta desde el cliente: lo hace la
-- Edge Function de invitación con la service role.
create policy "profiles: equipo lee" on public.profiles
  for select to authenticated
  using (org_id = (select public.current_org_id()) or id = auth.uid());
create policy "profiles: gerente edita" on public.profiles
  for update to authenticated
  using (org_id = (select public.current_org_id()) and (select public.is_manager()))
  with check (org_id = (select public.current_org_id()));

-- Sites
create policy "sites: equipo lee" on public.sites
  for select to authenticated
  using (org_id = (select public.current_org_id()));
create policy "sites: gerente escribe" on public.sites
  for all to authenticated
  using (org_id = (select public.current_org_id()) and (select public.is_manager()))
  with check (org_id = (select public.current_org_id()) and (select public.is_manager()));

-- Shifts: el equipo ve el horario; solo el gerente crea/edita.
create policy "shifts: equipo lee" on public.shifts
  for select to authenticated
  using (org_id = (select public.current_org_id()));
create policy "shifts: gerente escribe" on public.shifts
  for all to authenticated
  using (org_id = (select public.current_org_id()) and (select public.is_manager()))
  with check (
    org_id = (select public.current_org_id())
    and (select public.is_manager())
    and exists (select 1 from public.sites s where s.id = site_id and s.org_id = shifts.org_id)
    and (employee_id is null or exists (
      select 1 from public.profiles p
      where p.id = employee_id and p.org_id = shifts.org_id and p.status = 'active'
    ))
  );

-- Shift requests: el empleado ve las suyas, el gerente las de su org.
-- El empleado crea solicitudes de día libre; resolver solo vía RPC.
create policy "requests: leer" on public.shift_requests
  for select to authenticated
  using (
    org_id = (select public.current_org_id())
    and (employee_id = auth.uid() or (select public.is_manager()))
  );
create policy "requests: empleado crea día libre" on public.shift_requests
  for insert to authenticated
  with check (
    org_id = (select public.current_org_id())
    and employee_id = auth.uid()
    and kind = 'off'
    and status = 'pending'
    and resolved_by is null
  );

-- Swap offers: visibles para el equipo; escritura solo vía RPC.
create policy "swaps: equipo lee" on public.swap_offers
  for select to authenticated
  using (org_id = (select public.current_org_id()));

-- Availability: cada uno la suya; el gerente lee la de su equipo.
create policy "availability: leer" on public.availability
  for select to authenticated
  using (
    employee_id = auth.uid()
    or ((select public.is_manager()) and exists (
      select 1 from public.profiles p
      where p.id = employee_id and p.org_id = (select public.current_org_id())
    ))
  );
create policy "availability: propia inserta" on public.availability
  for insert to authenticated
  with check (employee_id = auth.uid() and (select public.current_org_id()) is not null);
create policy "availability: propia edita" on public.availability
  for update to authenticated
  using (employee_id = auth.uid())
  with check (employee_id = auth.uid());

-- Time entries: lectura propia o del gerente. Escritura solo vía RPC.
create policy "time_entries: leer" on public.time_entries
  for select to authenticated
  using (
    org_id = (select public.current_org_id())
    and (employee_id = auth.uid() or (select public.is_manager()))
  );

-- Work photos: el empleado sube evidencia a SU fichaje abierto.
create policy "work_photos: leer" on public.work_photos
  for select to authenticated
  using (
    org_id = (select public.current_org_id())
    and (employee_id = auth.uid() or (select public.is_manager()))
  );
create policy "work_photos: empleado agrega a su fichaje abierto" on public.work_photos
  for insert to authenticated
  with check (
    employee_id = auth.uid()
    and org_id = (select public.current_org_id())
    and storage_path like (org_id::text || '/' || auth.uid()::text || '/%')
    and exists (
      select 1 from public.time_entries te
      where te.id = time_entry_id
        and te.employee_id = auth.uid()
        and te.clock_out_at is null
    )
  );

-- Chat
create or replace function public.can_see_thread(p_thread_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.chat_threads t
    where t.id = p_thread_id
      and t.org_id = public.current_org_id()
      and (
        t.is_general
        or exists (
          select 1 from public.chat_members m
          where m.thread_id = t.id and m.profile_id = auth.uid()
        )
      )
  )
$$;

create policy "threads: leer" on public.chat_threads
  for select to authenticated
  using (public.can_see_thread(id));
create policy "members: leer propios" on public.chat_members
  for select to authenticated
  using (profile_id = auth.uid() or public.can_see_thread(thread_id));
create policy "messages: leer" on public.chat_messages
  for select to authenticated
  using (public.can_see_thread(thread_id));
create policy "messages: enviar" on public.chat_messages
  for insert to authenticated
  with check (sender_id = auth.uid() and public.can_see_thread(thread_id));

-- Notifications
create policy "notifications: propias" on public.notifications
  for select to authenticated
  using (profile_id = auth.uid());
create policy "notifications: marcar leídas" on public.notifications
  for update to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

create policy "prefs: propias leer" on public.notification_prefs
  for select to authenticated using (profile_id = auth.uid());
create policy "prefs: propias insertar" on public.notification_prefs
  for insert to authenticated with check (profile_id = auth.uid());
create policy "prefs: propias editar" on public.notification_prefs
  for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- ---------------------------------------------------------------------
-- Privilegios por columna: aunque RLS deje pasar el update, el cliente
-- solo puede tocar estas columnas (p. ej. nadie cambia su org_id ni su
-- email, y un empleado no puede cambiar el read_at de otro).
-- ---------------------------------------------------------------------

revoke all on all tables in schema public from anon;
revoke update on public.profiles from authenticated;
grant update (full_name, position_es, position_en, hourly_rate, status, role, avatar_index)
  on public.profiles to authenticated;
revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;
revoke update on public.chat_messages from authenticated;
revoke update, delete on public.time_entries from authenticated;
revoke insert on public.time_entries from authenticated;

-- Un gerente no puede quitarse a sí mismo el rol ni desactivarse (dejaría
-- la organización sin administrador por accidente).
create or replace function public.guard_profile_update()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  -- (invited -> active sí se permite: es accept_invite()).
  if new.id = auth.uid()
     and (new.role <> old.role
          or (new.status <> old.status and old.status <> 'invited')) then
    raise exception 'cannot_change_own_role' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
create trigger profiles_guard_update
  before update on public.profiles
  for each row execute function public.guard_profile_update();

-- ---------------------------------------------------------------------
-- RPC: fichaje con validación de ubicación en el servidor
-- ---------------------------------------------------------------------

-- Precisión mínima aceptada del GPS, en metros. Una lectura con un margen
-- de error mayor que esto no prueba que la persona esté en el sitio.
create or replace function public.max_gps_accuracy_m()
returns double precision language sql immutable set search_path = ''
as $$ select 100::double precision $$;

create or replace function public.clock_in(
  p_lat double precision,
  p_lng double precision,
  p_accuracy_m double precision,
  p_is_mocked boolean default false
)
returns public.time_entries
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := public.current_org_id();
  v_shift public.shifts;
  v_site public.sites;
  v_distance double precision;
  v_entry public.time_entries;
begin
  if v_org is null then
    raise exception 'not_allowed' using errcode = 'P0001';
  end if;
  if p_is_mocked then
    raise exception 'mock_location' using errcode = 'P0001';
  end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'invalid_location' using errcode = 'P0001';
  end if;
  if p_accuracy_m is null or p_accuracy_m <= 0 or p_accuracy_m > public.max_gps_accuracy_m() then
    raise exception 'low_accuracy' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.time_entries where employee_id = auth.uid() and clock_out_at is null) then
    raise exception 'already_clocked_in' using errcode = 'P0001';
  end if;

  -- El servidor elige el turno: el que está en curso o empieza en <= 30 min.
  select * into v_shift from public.shifts
  where employee_id = auth.uid()
    and org_id = v_org
    and now() between starts_at - interval '30 minutes' and ends_at
  order by starts_at
  limit 1;
  if not found then
    raise exception 'no_active_shift' using errcode = 'P0001';
  end if;

  select * into v_site from public.sites where id = v_shift.site_id and active;
  if not found then
    raise exception 'site_inactive' using errcode = 'P0001';
  end if;

  v_distance := public.distance_m(p_lat, p_lng, v_site.latitude, v_site.longitude);
  if v_distance > v_site.radius_m then
    raise exception 'outside_site' using errcode = 'P0001',
      detail = round(v_distance)::text;
  end if;

  insert into public.time_entries (
    org_id, employee_id, site_id, shift_id,
    clock_in_lat, clock_in_lng, clock_in_accuracy_m, clock_in_distance_m
  ) values (
    v_org, auth.uid(), v_site.id, v_shift.id,
    p_lat, p_lng, p_accuracy_m, v_distance
  )
  returning * into v_entry;

  -- Llegada tarde (> 10 min): queda como solicitud para el gerente.
  if now() > v_shift.starts_at + interval '10 minutes' then
    insert into public.shift_requests (org_id, kind, employee_id, shift_id, request_date)
    values (v_org, 'late', auth.uid(), v_shift.id,
            (now() at time zone public.org_timezone(v_org))::date);
  end if;

  return v_entry;
end;
$$;

-- La salida siempre se permite (no queremos fichajes abiertos para siempre),
-- pero se registra la ubicación y si estaba fuera del sitio.
create or replace function public.clock_out(
  p_lat double precision,
  p_lng double precision,
  p_accuracy_m double precision,
  p_is_mocked boolean default false
)
returns public.time_entries
language plpgsql security definer set search_path = ''
as $$
declare
  v_entry public.time_entries;
  v_site public.sites;
  v_distance double precision;
begin
  if public.current_org_id() is null then
    raise exception 'not_allowed' using errcode = 'P0001';
  end if;
  if p_is_mocked then
    raise exception 'mock_location' using errcode = 'P0001';
  end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'invalid_location' using errcode = 'P0001';
  end if;

  select * into v_entry from public.time_entries
  where employee_id = auth.uid() and clock_out_at is null
  for update;
  if not found then
    raise exception 'not_clocked_in' using errcode = 'P0001';
  end if;

  select * into v_site from public.sites where id = v_entry.site_id;
  v_distance := public.distance_m(p_lat, p_lng, v_site.latitude, v_site.longitude);

  update public.time_entries set
    clock_out_at = now(),
    clock_out_lat = p_lat,
    clock_out_lng = p_lng,
    clock_out_accuracy_m = p_accuracy_m,
    clock_out_distance_m = v_distance,
    clock_out_outside = v_distance > v_site.radius_m
  where id = v_entry.id
  returning * into v_entry;

  return v_entry;
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: cambios de turno y solicitudes
-- ---------------------------------------------------------------------

create or replace function public.offer_shift(p_shift_id uuid)
returns public.swap_offers
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := public.current_org_id();
  v_shift public.shifts;
  v_request_id uuid;
  v_offer public.swap_offers;
begin
  select * into v_shift from public.shifts
  where id = p_shift_id and org_id = v_org and employee_id = auth.uid();
  if not found then
    raise exception 'not_your_shift' using errcode = 'P0001';
  end if;
  if v_shift.starts_at <= now() then
    raise exception 'shift_already_started' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.swap_offers
    where shift_id = p_shift_id and status in ('open', 'claimed')
  ) then
    raise exception 'already_offered' using errcode = 'P0001';
  end if;

  insert into public.shift_requests (org_id, kind, employee_id, shift_id, request_date)
  values (v_org, 'swap', auth.uid(), p_shift_id,
          (v_shift.starts_at at time zone public.org_timezone(v_org))::date)
  returning id into v_request_id;

  insert into public.swap_offers (org_id, shift_id, offered_by, request_id)
  values (v_org, p_shift_id, auth.uid(), v_request_id)
  returning * into v_offer;
  return v_offer;
end;
$$;

create or replace function public.claim_swap(p_swap_id uuid)
returns public.swap_offers
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := public.current_org_id();
  v_offer public.swap_offers;
  v_shift public.shifts;
begin
  select * into v_offer from public.swap_offers
  where id = p_swap_id and org_id = v_org
  for update;
  if not found or v_offer.status <> 'open' then
    raise exception 'swap_not_available' using errcode = 'P0001';
  end if;
  if v_offer.offered_by = auth.uid() then
    raise exception 'own_swap' using errcode = 'P0001';
  end if;

  select * into v_shift from public.shifts where id = v_offer.shift_id;
  if exists (
    select 1 from public.shifts s
    where s.employee_id = auth.uid()
      and s.starts_at < v_shift.ends_at
      and s.ends_at > v_shift.starts_at
  ) then
    raise exception 'overlapping_shift' using errcode = 'P0001';
  end if;

  update public.swap_offers
  set status = 'claimed', claimed_by = auth.uid()
  where id = p_swap_id
  returning * into v_offer;
  return v_offer;
end;
$$;

create or replace function public.resolve_request(p_request_id uuid, p_approve boolean)
returns public.shift_requests
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := public.current_org_id();
  v_request public.shift_requests;
  v_offer public.swap_offers;
begin
  if not public.is_manager() then
    raise exception 'not_allowed' using errcode = 'P0001';
  end if;

  select * into v_request from public.shift_requests
  where id = p_request_id and org_id = v_org
  for update;
  if not found then
    raise exception 'request_not_found' using errcode = 'P0001';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'request_already_resolved' using errcode = 'P0001';
  end if;

  update public.shift_requests set
    status = case when p_approve then 'approved'::public.request_status
                  else 'rejected'::public.request_status end,
    resolved_by = auth.uid(),
    resolved_at = now()
  where id = p_request_id
  returning * into v_request;

  if v_request.kind = 'swap' then
    select * into v_offer from public.swap_offers
    where request_id = v_request.id and status in ('open', 'claimed')
    for update;
    if found then
      if p_approve then
        -- Si alguien lo tomó, pasa a esa persona; si no, queda sin cubrir.
        update public.shifts set employee_id = v_offer.claimed_by
        where id = v_offer.shift_id;
        update public.swap_offers set status = 'approved' where id = v_offer.id;
      else
        update public.swap_offers set status = 'cancelled' where id = v_offer.id;
      end if;
    end if;
  elsif v_request.kind = 'off' and p_approve then
    -- Día libre aprobado: sus turnos de ese día quedan sin cubrir.
    update public.shifts set employee_id = null
    where employee_id = v_request.employee_id
      and (starts_at at time zone public.org_timezone(v_org))::date = v_request.request_date;
  end if;

  insert into public.notifications (profile_id, text_es, text_en)
  values (
    v_request.employee_id,
    case when p_approve then 'Tu solicitud fue aprobada' else 'Tu solicitud fue rechazada' end,
    case when p_approve then 'Your request was approved' else 'Your request was declined' end
  );

  return v_request;
end;
$$;

-- Copia los turnos de la semana anterior que todavía no existan.
create or replace function public.duplicate_previous_week(p_week_start timestamptz)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := public.current_org_id();
  v_count integer;
begin
  if not public.is_manager() then
    raise exception 'not_allowed' using errcode = 'P0001';
  end if;

  insert into public.shifts (org_id, site_id, employee_id, starts_at, ends_at, created_by)
  select s.org_id, s.site_id,
         case when p.status = 'active' then s.employee_id end,
         s.starts_at + interval '7 days', s.ends_at + interval '7 days', auth.uid()
  from public.shifts s
  left join public.profiles p on p.id = s.employee_id
  where s.org_id = v_org
    and s.starts_at >= p_week_start - interval '7 days'
    and s.starts_at < p_week_start
    and not exists (
      select 1 from public.shifts d
      where d.org_id = v_org
        and d.site_id = s.site_id
        and d.starts_at = s.starts_at + interval '7 days'
        and d.employee_id is not distinct from s.employee_id
    );
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- El invitado (ya autenticado por el enlace del correo) activa su perfil.
create or replace function public.accept_invite()
returns public.profiles
language plpgsql security definer set search_path = ''
as $$
declare
  v_profile public.profiles;
begin
  update public.profiles set status = 'active'
  where id = auth.uid() and status = 'invited'
  returning * into v_profile;
  if not found then
    raise exception 'no_pending_invite' using errcode = 'P0001';
  end if;
  return v_profile;
end;
$$;

-- Abre (o reutiliza) el chat directo con otra persona de la organización.
create or replace function public.open_direct_thread(p_other uuid)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := public.current_org_id();
  v_thread uuid;
begin
  if v_org is null or p_other = auth.uid() or not exists (
    select 1 from public.profiles
    where id = p_other and org_id = v_org and status <> 'inactive'
  ) then
    raise exception 'not_allowed' using errcode = 'P0001';
  end if;

  select t.id into v_thread
  from public.chat_threads t
  join public.chat_members a on a.thread_id = t.id and a.profile_id = auth.uid()
  join public.chat_members b on b.thread_id = t.id and b.profile_id = p_other
  where t.org_id = v_org and not t.is_general
  limit 1;

  if v_thread is null then
    insert into public.chat_threads (org_id) values (v_org) returning id into v_thread;
    insert into public.chat_members (thread_id, profile_id)
    values (v_thread, auth.uid()), (v_thread, p_other);
  end if;
  return v_thread;
end;
$$;

-- ---------------------------------------------------------------------
-- RPC de lectura (security invoker: respetan RLS)
-- ---------------------------------------------------------------------

-- Horas trabajadas por empleado en un periodo (fichajes cerrados + el
-- abierto hasta ahora). El empleado solo verá las suyas por RLS.
create or replace function public.period_hours(p_from timestamptz, p_to timestamptz)
returns table (employee_id uuid, hours double precision)
language sql stable security invoker set search_path = ''
as $$
  select te.employee_id,
         sum(extract(epoch from (least(coalesce(te.clock_out_at, now()), p_to)
                                 - greatest(te.clock_in_at, p_from))) / 3600.0)
  from public.time_entries te
  where te.clock_in_at < p_to
    and coalesce(te.clock_out_at, now()) > p_from
  group by te.employee_id
$$;

create or replace function public.chat_overview()
returns table (
  thread_id uuid,
  is_general boolean,
  name text,
  other_id uuid,
  last_body text,
  unread integer
)
language sql stable security invoker set search_path = ''
as $$
  select t.id,
         t.is_general,
         t.name,
         (select m.profile_id from public.chat_members m
          where m.thread_id = t.id and m.profile_id <> auth.uid() limit 1),
         (select cm.body from public.chat_messages cm
          where cm.thread_id = t.id order by cm.created_at desc limit 1),
         (select count(*)::integer from public.chat_messages cm
          where cm.thread_id = t.id
            and cm.sender_id <> auth.uid()
            and cm.created_at > coalesce(
              (select m.last_read_at from public.chat_members m
               where m.thread_id = t.id and m.profile_id = auth.uid()),
              '-infinity'::timestamptz))
  from public.chat_threads t
  order by t.is_general desc, t.created_at
$$;

create or replace function public.mark_thread_read(p_thread_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.can_see_thread(p_thread_id) then
    raise exception 'not_allowed' using errcode = 'P0001';
  end if;
  insert into public.chat_members (thread_id, profile_id, last_read_at)
  values (p_thread_id, auth.uid(), now())
  on conflict (thread_id, profile_id) do update set last_read_at = now();
end;
$$;

-- ---------------------------------------------------------------------
-- Permisos de ejecución: solo usuarios autenticados.
-- ---------------------------------------------------------------------

revoke execute on all functions in schema public from public, anon;
grant execute on function
  public.current_org_id(),
  public.is_manager(),
  public.can_see_thread(uuid),
  public.clock_in(double precision, double precision, double precision, boolean),
  public.clock_out(double precision, double precision, double precision, boolean),
  public.offer_shift(uuid),
  public.claim_swap(uuid),
  public.resolve_request(uuid, boolean),
  public.duplicate_previous_week(timestamptz),
  public.accept_invite(),
  public.open_direct_thread(uuid),
  public.period_hours(timestamptz, timestamptz),
  public.chat_overview(),
  public.mark_thread_read(uuid)
to authenticated;

-- ---------------------------------------------------------------------
-- Storage: evidencia fotográfica (bucket privado).
-- Ruta obligatoria: <org_id>/<user_id>/<archivo>.jpg
-- ---------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('work-evidence', 'work-evidence', false, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "evidence: empleado sube a su carpeta" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'work-evidence'
    and (storage.foldername(name))[1] = (select public.current_org_id())::text
    and (storage.foldername(name))[2] = auth.uid()::text
  );
create policy "evidence: leer propia o como gerente" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'work-evidence'
    and (storage.foldername(name))[1] = (select public.current_org_id())::text
    and ((storage.foldername(name))[2] = auth.uid()::text or (select public.is_manager()))
  );

-- ---------------------------------------------------------------------
-- Realtime: la app escucha cambios en estas tablas (RLS sigue aplicando).
-- ---------------------------------------------------------------------

alter publication supabase_realtime add table
  public.shifts,
  public.shift_requests,
  public.swap_offers,
  public.time_entries,
  public.chat_messages,
  public.notifications,
  public.profiles;
