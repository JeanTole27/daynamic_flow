-- =====================================================================
-- Solicitudes que crea el empleado desde la app.
--
--  * request_day_off: pedir un día libre (con motivo opcional).
--  * notify_late: avisar antes de tiempo que llegará tarde a un turno.
--
-- Ambas quedan pendientes para el gerente (resolve_request ya las
-- resuelve) y avisan a los gerentes de la empresa. La llegada tarde que se
-- detecta al fichar (más de 10 min) sigue creándose sola en clock_in().
-- =====================================================================

-- Avisa a todos los gerentes activos de la organización.
create or replace function public.notify_managers(p_org uuid, p_es text, p_en text)
returns void
language sql security definer set search_path = ''
as $$
  insert into public.notifications (profile_id, text_es, text_en)
  select id, p_es, p_en from public.profiles
  where org_id = p_org and role = 'manager' and status = 'active'
$$;

create or replace function public.request_day_off(p_date date, p_reason text default null)
returns public.shift_requests
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := public.current_org_id();
  v_me public.profiles;
  v_today date;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_request public.shift_requests;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if v_org is null or v_me.status <> 'active' then
    raise exception 'not_allowed' using errcode = 'P0001';
  end if;
  v_today := (now() at time zone public.org_timezone(v_org))::date;
  if p_date is null or p_date < v_today or p_date > v_today + 365 then
    raise exception 'invalid_date' using errcode = 'P0001';
  end if;
  if char_length(coalesce(v_reason, '')) > 500 then
    raise exception 'reason_too_long' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.shift_requests
    where employee_id = auth.uid() and kind = 'off' and request_date = p_date
      and status in ('pending', 'approved')
  ) then
    raise exception 'already_requested' using errcode = 'P0001';
  end if;

  insert into public.shift_requests (org_id, kind, employee_id, request_date, reason)
  values (v_org, 'off', auth.uid(), p_date, v_reason)
  returning * into v_request;

  perform public.notify_managers(
    v_org,
    v_me.full_name || ' pidió libre el ' || to_char(p_date, 'DD/MM'),
    v_me.full_name || ' asked for ' || to_char(p_date, 'MM/DD') || ' off'
  );
  return v_request;
end;
$$;

create or replace function public.notify_late(p_shift_id uuid, p_reason text default null)
returns public.shift_requests
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := public.current_org_id();
  v_me public.profiles;
  v_shift public.shifts;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_request public.shift_requests;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if v_org is null or v_me.status <> 'active' then
    raise exception 'not_allowed' using errcode = 'P0001';
  end if;
  select * into v_shift from public.shifts
  where id = p_shift_id and org_id = v_org and employee_id = auth.uid();
  if not found then
    raise exception 'not_your_shift' using errcode = 'P0001';
  end if;
  -- Solo para un turno de las próximas 24 h o en curso.
  if now() >= v_shift.ends_at or v_shift.starts_at > now() + interval '24 hours' then
    raise exception 'late_not_allowed' using errcode = 'P0001';
  end if;
  if char_length(coalesce(v_reason, '')) > 500 then
    raise exception 'reason_too_long' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.shift_requests
    where shift_id = v_shift.id and employee_id = auth.uid() and kind = 'late'
      and reason is not null
  ) then
    raise exception 'already_requested' using errcode = 'P0001';
  end if;

  -- El motivo distingue el aviso previo del retraso detectado al fichar
  -- (que no lleva motivo); si no se da uno, se guarda un texto genérico.
  insert into public.shift_requests (org_id, kind, employee_id, shift_id, request_date, reason)
  values (
    v_org, 'late', auth.uid(), v_shift.id,
    (v_shift.starts_at at time zone public.org_timezone(v_org))::date,
    coalesce(v_reason, 'Llegaré tarde')
  )
  returning * into v_request;

  perform public.notify_managers(
    v_org,
    v_me.full_name || ' avisa que llegará tarde al turno del ' || public.shift_label(v_shift.starts_at, v_org),
    v_me.full_name || ' will be late for the shift on ' || public.shift_label(v_shift.starts_at, v_org)
  );
  return v_request;
end;
$$;

revoke execute on function
  public.notify_managers(uuid, text, text),
  public.request_day_off(date, text),
  public.notify_late(uuid, text)
from public, anon;
grant execute on function
  public.request_day_off(date, text),
  public.notify_late(uuid, text)
to authenticated;
