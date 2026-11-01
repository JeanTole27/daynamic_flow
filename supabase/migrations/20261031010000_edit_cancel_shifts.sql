-- =====================================================================
-- Editar y cancelar turnos.
--
-- Solo el gerente, y solo turnos que aún no empiezan y no tienen fichajes:
-- lo que ya se trabajó no se reescribe. Si el turno cambia, se cancela
-- cualquier cambio de turno pendiente (ya no corresponde) y se avisa a
-- quien lo tenía y a quien lo recibe.
-- =====================================================================

-- "lun 7 sep 14:00" en la zona horaria de la organización.
create or replace function public.shift_label(p_starts_at timestamptz, p_org uuid)
returns text
language sql stable set search_path = ''
as $$
  select to_char(p_starts_at at time zone public.org_timezone(p_org), 'DD/MM HH24:MI')
$$;

-- Comprueba que el gerente puede tocar este turno y lo devuelve bloqueado.
create or replace function public.lock_editable_shift(p_shift_id uuid)
returns public.shifts
language plpgsql security definer set search_path = ''
as $$
declare
  v_shift public.shifts;
begin
  if not public.is_manager() then
    raise exception 'not_allowed' using errcode = 'P0001';
  end if;
  select * into v_shift from public.shifts
  where id = p_shift_id and org_id = public.current_org_id()
  for update;
  if not found then
    raise exception 'shift_not_found' using errcode = 'P0001';
  end if;
  if v_shift.starts_at <= now() then
    raise exception 'shift_already_started' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.time_entries where shift_id = v_shift.id) then
    raise exception 'shift_has_entries' using errcode = 'P0001';
  end if;
  return v_shift;
end;
$$;

-- Deja sin efecto los cambios de turno pendientes de este turno.
create or replace function public.void_shift_swaps(p_shift_id uuid)
returns void
language sql security definer set search_path = ''
as $$
  update public.shift_requests set status = 'rejected', resolved_by = auth.uid(), resolved_at = now()
  where status = 'pending' and id in (
    select request_id from public.swap_offers
    where shift_id = p_shift_id and status in ('open', 'claimed') and request_id is not null
  );
  update public.swap_offers set status = 'cancelled'
  where shift_id = p_shift_id and status in ('open', 'claimed');
$$;

create or replace function public.update_shift(
  p_shift_id uuid,
  p_site_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_employee_id uuid
)
returns public.shifts
language plpgsql security definer set search_path = ''
as $$
declare
  v_old public.shifts;
  v_new public.shifts;
  v_org uuid := public.current_org_id();
begin
  v_old := public.lock_editable_shift(p_shift_id);

  if p_starts_at <= now() then
    raise exception 'shift_in_past' using errcode = 'P0001';
  end if;
  if not exists (
    select 1 from public.sites where id = p_site_id and org_id = v_org and active
  ) then
    raise exception 'site_inactive' using errcode = 'P0001';
  end if;
  if p_employee_id is not null and not exists (
    select 1 from public.profiles
    where id = p_employee_id and org_id = v_org and status = 'active'
  ) then
    raise exception 'employee_not_active' using errcode = 'P0001';
  end if;

  -- Las restricciones de la tabla validan duración (máx. 16 h, fin > inicio)
  -- y que la persona no tenga otro turno que se cruce.
  update public.shifts set
    site_id = p_site_id,
    starts_at = p_starts_at,
    ends_at = p_ends_at,
    employee_id = p_employee_id
  where id = v_old.id
  returning * into v_new;

  if (v_new.starts_at, v_new.ends_at, v_new.site_id, v_new.employee_id)
     is distinct from (v_old.starts_at, v_old.ends_at, v_old.site_id, v_old.employee_id) then
    perform public.void_shift_swaps(v_old.id);
  end if;

  if v_old.employee_id is not null and v_old.employee_id is distinct from v_new.employee_id then
    insert into public.notifications (profile_id, text_es, text_en) values (
      v_old.employee_id,
      'Ya no tienes el turno del ' || public.shift_label(v_old.starts_at, v_org),
      'You no longer have the shift on ' || public.shift_label(v_old.starts_at, v_org)
    );
  end if;
  if v_new.employee_id is not null then
    if v_new.employee_id is distinct from v_old.employee_id then
      insert into public.notifications (profile_id, text_es, text_en) values (
        v_new.employee_id,
        'Te asignaron un turno el ' || public.shift_label(v_new.starts_at, v_org),
        'You were assigned a shift on ' || public.shift_label(v_new.starts_at, v_org)
      );
    elsif (v_new.starts_at, v_new.ends_at, v_new.site_id)
          is distinct from (v_old.starts_at, v_old.ends_at, v_old.site_id) then
      insert into public.notifications (profile_id, text_es, text_en) values (
        v_new.employee_id,
        'Tu turno cambió: ahora es el ' || public.shift_label(v_new.starts_at, v_org),
        'Your shift changed: it is now on ' || public.shift_label(v_new.starts_at, v_org)
      );
    end if;
  end if;

  return v_new;
end;
$$;

create or replace function public.cancel_shift(p_shift_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_shift public.shifts;
begin
  v_shift := public.lock_editable_shift(p_shift_id);

  if v_shift.employee_id is not null then
    insert into public.notifications (profile_id, text_es, text_en) values (
      v_shift.employee_id,
      'Se canceló tu turno del ' || public.shift_label(v_shift.starts_at, v_shift.org_id),
      'Your shift on ' || public.shift_label(v_shift.starts_at, v_shift.org_id) || ' was cancelled'
    );
  end if;

  -- Las solicitudes y ofertas de cambio de este turno se borran en cascada.
  delete from public.shifts where id = v_shift.id;
end;
$$;

revoke execute on function
  public.shift_label(timestamptz, uuid),
  public.lock_editable_shift(uuid),
  public.void_shift_swaps(uuid),
  public.update_shift(uuid, uuid, timestamptz, timestamptz, uuid),
  public.cancel_shift(uuid)
from public, anon;
grant execute on function
  public.update_shift(uuid, uuid, timestamptz, timestamptz, uuid),
  public.cancel_shift(uuid)
to authenticated;
