-- =====================================================================
-- Avisos de turnos en un solo lugar.
--
-- Antes solo update_shift() avisaba; un turno nuevo (crear o cubrir uno
-- sin asignar) no le llegaba al empleado. Ahora un trigger sobre `shifts`
-- avisa siempre que alguien recibe, pierde o ve cambiado un turno, venga
-- el cambio de donde venga (app, edición, cambio de turno aprobado).
-- cancel_shift() sigue avisando por su cuenta antes de borrar.
-- =====================================================================

create or replace function public.notify_shift_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_old_emp uuid := case when tg_op = 'UPDATE' then old.employee_id end;
begin
  if v_old_emp is not null and v_old_emp is distinct from new.employee_id then
    insert into public.notifications (profile_id, text_es, text_en) values (
      v_old_emp,
      'Ya no tienes el turno del ' || public.shift_label(old.starts_at, old.org_id),
      'You no longer have the shift on ' || public.shift_label(old.starts_at, old.org_id)
    );
  end if;

  if new.employee_id is null then
    return null;
  end if;

  if tg_op = 'INSERT' or new.employee_id is distinct from v_old_emp then
    insert into public.notifications (profile_id, text_es, text_en) values (
      new.employee_id,
      'Te asignaron un turno el ' || public.shift_label(new.starts_at, new.org_id),
      'You were assigned a shift on ' || public.shift_label(new.starts_at, new.org_id)
    );
  elsif (new.starts_at, new.ends_at, new.site_id)
        is distinct from (old.starts_at, old.ends_at, old.site_id) then
    insert into public.notifications (profile_id, text_es, text_en) values (
      new.employee_id,
      'Tu turno cambió: ahora es el ' || public.shift_label(new.starts_at, new.org_id),
      'Your shift changed: it is now on ' || public.shift_label(new.starts_at, new.org_id)
    );
  end if;
  return null;
end;
$$;

revoke execute on function public.notify_shift_change() from public, anon, authenticated;

create trigger shifts_notify_change
  after insert or update of employee_id, starts_at, ends_at, site_id
  on public.shifts
  for each row execute function public.notify_shift_change();

-- update_shift() sin sus avisos propios: ahora los manda el trigger.
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

  return v_new;
end;
$$;
